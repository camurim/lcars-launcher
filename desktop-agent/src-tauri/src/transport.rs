use crate::actions::execute_registered_action;
use crate::protocol::{
    CapabilitiesSyncPayload, Envelope, ExecuteActionPayload, HttpProxyRequestPayload,
    HttpProxyResponsePayload, MessageType, PairConfirmPayload, PairRequestPayload,
};
use crate::storage::{JsonStore, PairedDevice, PersistedData};
use crate::telemetry::TelemetryCollector;
use async_trait::async_trait;
use futures_util::{SinkExt, StreamExt};
use serde_json::Value;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::TcpListener;
use tokio::sync::{broadcast, RwLock};
use tokio_tungstenite::tungstenite::Message;
use uuid::Uuid;

pub struct AgentState {
    pub ws_port: u16,
    pub telemetry_interval_ms: u64,
    pub pairing_pin: RwLock<String>,
    pub data: RwLock<PersistedData>,
    pub store: JsonStore,
    pub broadcast_tx: broadcast::Sender<String>,
}

impl AgentState {
    pub async fn is_token_valid(&self, token: &str) -> bool {
        let data = self.data.read().await;
        data.paired_devices.iter().any(|d| d.token == token)
    }

    pub async fn build_capabilities_envelope(&self, token: Option<String>) -> Envelope {
        let (revision, actions) = {
            let data = self.data.read().await;
            (
                data.capabilities_revision,
                data.actions.iter().map(|a| a.to_descriptor()).collect(),
            )
        };
        let collector = TelemetryCollector::new(self.telemetry_interval_ms);
        let payload = CapabilitiesSyncPayload {
            revision,
            actions,
            sensors: collector.available_sensors(),
        };
        Envelope::new(
            MessageType::CapabilitiesSync,
            None,
            token,
            serde_json::to_value(payload).unwrap_or_default(),
        )
    }

    pub async fn broadcast_capabilities(&self) {
        let env = self.build_capabilities_envelope(None).await;
        if let Ok(json) = serde_json::to_string(&env) {
            let _ = self.broadcast_tx.send(json);
        }
    }
}

/// Resposta produzida pelo roteador de protocolo independente do transporte.
pub struct RouteOutcome {
    pub responses: Vec<Envelope>,
    pub authenticated_token: Option<String>,
}

/// Processa um frame JSON do protocolo LCARS sem depender de WebSocket ou Bluetooth.
pub async fn route_message(
    state: &Arc<AgentState>,
    current_token: Option<&str>,
    raw_json: &str,
) -> RouteOutcome {
    let Ok(env) = serde_json::from_str::<Envelope>(raw_json) else {
        return RouteOutcome {
            responses: vec![],
            authenticated_token: current_token.map(String::from),
        };
    };

    // Verifica se o cliente já está autenticado (sessão ou token no envelope)
    let mut authed_token: Option<String> = match current_token {
        Some(t) if state.is_token_valid(t).await => Some(t.to_string()),
        _ => None,
    };

    if authed_token.is_none() {
        if let Some(tok) = env.token.as_deref() {
            if state.is_token_valid(tok).await {
                authed_token = Some(tok.to_string());
            }
        }
    }

    match env.msg_type {
        MessageType::PairRequest => {
            let Ok(req) = serde_json::from_value::<PairRequestPayload>(env.payload) else {
                return RouteOutcome {
                    responses: vec![],
                    authenticated_token: authed_token,
                };
            };

            let expected_pin = state.pairing_pin.read().await.clone();
            let pin_matches = req.pin.as_deref() == Some(expected_pin.as_str());
            let (agent_id, agent_name) = {
                let d = state.data.read().await;
                (d.agent_id.clone(), d.agent_name.clone())
            };

            if pin_matches {
                let new_token = format!("lcars_tok_{}", Uuid::new_v4().simple());
                {
                    let mut data = state.data.write().await;
                    data.paired_devices.retain(|d| d.device_id != req.device_id);
                    data.paired_devices.push(PairedDevice {
                        device_id: req.device_id,
                        device_name: req.device_name,
                        platform: req.platform,
                        token: new_token.clone(),
                        paired_at: chrono::Utc::now().to_rfc3339(),
                    });
                    let _ = state.store.save(&data);
                }

                let confirm = PairConfirmPayload {
                    status: "approved".into(),
                    auth_token: Some(new_token.clone()),
                    agent_id,
                    agent_name,
                    os: std::env::consts::OS.into(),
                    telemetry_interval_ms: Some(state.telemetry_interval_ms),
                    error_code: None,
                    error_message: None,
                };

                let confirm_env = Envelope::new(
                    MessageType::PairConfirm,
                    env.req_id,
                    Some(new_token.clone()),
                    serde_json::to_value(confirm).unwrap_or_default(),
                );
                let caps_env = state.build_capabilities_envelope(Some(new_token.clone())).await;

                RouteOutcome {
                    responses: vec![confirm_env, caps_env],
                    authenticated_token: Some(new_token),
                }
            } else {
                let confirm = PairConfirmPayload {
                    status: "rejected".into(),
                    auth_token: None,
                    agent_id,
                    agent_name,
                    os: std::env::consts::OS.into(),
                    telemetry_interval_ms: None,
                    error_code: Some("ERR_INVALID_PIN".into()),
                    error_message: Some("PIN de 6 dígitos inválido".into()),
                };
                let confirm_env = Envelope::new(
                    MessageType::PairConfirm,
                    env.req_id,
                    None,
                    serde_json::to_value(confirm).unwrap_or_default(),
                );
                RouteOutcome {
                    responses: vec![confirm_env],
                    authenticated_token: authed_token,
                }
            }
        }

        MessageType::ExecuteAction => {
            let Some(tok) = authed_token.clone() else {
                let denied = crate::protocol::ActionResultPayload {
                    action_id: String::new(),
                    status: "denied".into(),
                    exit_code: None,
                    duration_ms: 0,
                    message: Some("ERR_UNAUTHORIZED: Token inválido ou revogado".into()),
                };
                return RouteOutcome {
                    responses: vec![Envelope::new(
                        MessageType::ActionResult,
                        env.req_id,
                        None,
                        serde_json::to_value(denied).unwrap_or_default(),
                    )],
                    authenticated_token: None,
                };
            };

            let Ok(exec) = serde_json::from_value::<ExecuteActionPayload>(env.payload) else {
                return RouteOutcome {
                    responses: vec![],
                    authenticated_token: Some(tok),
                };
            };

            let actions = state.data.read().await.actions.clone();
            let action_id = exec.action_id.clone();
            let result = tokio::task::spawn_blocking(move || {
                execute_registered_action(&actions, &action_id)
            })
            .await
            .unwrap_or_else(|_| crate::protocol::ActionResultPayload {
                action_id: exec.action_id,
                status: "error".into(),
                exit_code: None,
                duration_ms: 0,
                message: Some("Falha interna ao executar ação".into()),
            });
            let resp = Envelope::new(
                MessageType::ActionResult,
                env.req_id,
                Some(tok.clone()),
                serde_json::to_value(result).unwrap_or_default(),
            );
            RouteOutcome {
                responses: vec![resp],
                authenticated_token: Some(tok),
            }
        }

        MessageType::LayoutSync => {
            let Some(tok) = authed_token.clone() else {
                return RouteOutcome {
                    responses: vec![],
                    authenticated_token: None,
                };
            };

            let direction = env
                .payload
                .get("direction")
                .and_then(Value::as_str)
                .unwrap_or("push");

            if direction == "pull_request" {
                let backup = state.data.read().await.layout_backup.clone();
                if let Some(mut layout) = backup {
                    if let Some(obj) = layout.as_object_mut() {
                        obj.insert("direction".into(), Value::String("pull_response".into()));
                    }
                    let resp = Envelope::new(
                        MessageType::LayoutSync,
                        env.req_id,
                        Some(tok.clone()),
                        layout,
                    );
                    return RouteOutcome {
                        responses: vec![resp],
                        authenticated_token: Some(tok),
                    };
                }
            } else if direction == "push" {
                let mut data = state.data.write().await;
                data.layout_backup = Some(env.payload);
                let _ = state.store.save(&data);
            }

            RouteOutcome {
                responses: vec![],
                authenticated_token: Some(tok),
            }
        }

        MessageType::CapabilitiesSync => {
            // Permite que o cliente reconectado com token salvo autentique a sessão
            // e solicite imediatamente a lista atualizada de ações/sensores + telemetria.
            if let Some(tok) = authed_token.clone() {
                let caps_env = state.build_capabilities_envelope(Some(tok.clone())).await;
                return RouteOutcome {
                    responses: vec![caps_env],
                    authenticated_token: Some(tok),
                };
            }
            RouteOutcome {
                responses: vec![],
                authenticated_token: None,
            }
        }

        MessageType::HttpProxyRequest => {
            let Some(tok) = authed_token.clone() else {
                let denied = HttpProxyResponsePayload {
                    ok: false,
                    status_code: Some(401),
                    body: None,
                    error: Some("ERR_UNAUTHORIZED: Token inválido ou revogado".into()),
                };
                return RouteOutcome {
                    responses: vec![Envelope::new(
                        MessageType::HttpProxyResponse,
                        env.req_id,
                        None,
                        serde_json::to_value(denied).unwrap_or_default(),
                    )],
                    authenticated_token: None,
                };
            };

            let result = match serde_json::from_value::<HttpProxyRequestPayload>(env.payload) {
                Ok(req) => {
                    let url = req.url.trim().to_string();
                    tokio::task::spawn_blocking(move || execute_http_proxy(&url))
                        .await
                        .unwrap_or_else(|_| HttpProxyResponsePayload {
                            ok: false,
                            status_code: None,
                            body: None,
                            error: Some("Falha interna no proxy HTTP do PC".into()),
                        })
                }
                Err(e) => HttpProxyResponsePayload {
                    ok: false,
                    status_code: Some(400),
                    body: None,
                    error: Some(format!("Payload HTTP_PROXY_REQUEST inválido: {e}")),
                },
            };

            let resp = Envelope::new(
                MessageType::HttpProxyResponse,
                env.req_id,
                Some(tok.clone()),
                serde_json::to_value(result).unwrap_or_default(),
            );
            RouteOutcome {
                responses: vec![resp],
                authenticated_token: Some(tok),
            }
        }

        _ => RouteOutcome {
            responses: vec![],
            authenticated_token: authed_token,
        },
    }
}

const MAX_HTTP_PROXY_BODY_BYTES: usize = 2 * 1024 * 1024;

fn execute_http_proxy(url: &str) -> HttpProxyResponsePayload {
    let lower = url.to_ascii_lowercase();
    if !(lower.starts_with("http://") || lower.starts_with("https://")) {
        return HttpProxyResponsePayload {
            ok: false,
            status_code: Some(400),
            body: None,
            error: Some("URL inválida (use http:// ou https://)".into()),
        };
    }

    let output = std::process::Command::new("curl")
        .args([
            "-sS",
            "-L",
            "--connect-timeout",
            "8",
            "--max-time",
            "12",
            "-H",
            "Accept: application/json",
            "-A",
            "SciFiDeckAgent/1.0",
            "-w",
            "\n%{http_code}",
            "--",
            url,
        ])
        .output();

    let output = match output {
        Ok(o) => o,
        Err(e) => {
            return HttpProxyResponsePayload {
                ok: false,
                status_code: None,
                body: None,
                error: Some(format!("Não foi possível executar 'curl' no PC: {e}")),
            };
        }
    };

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        return HttpProxyResponsePayload {
            ok: false,
            status_code: None,
            body: None,
            error: Some(if stderr.is_empty() {
                format!("Falha ao consultar URL pelo PC (código {:?})", output.status.code())
            } else {
                stderr
            }),
        };
    }

    if output.stdout.len() > MAX_HTTP_PROXY_BODY_BYTES {
        return HttpProxyResponsePayload {
            ok: false,
            status_code: Some(413),
            body: None,
            error: Some("Resposta HTTP excedeu o limite máximo (2 MB).".into()),
        };
    }

    let raw = String::from_utf8_lossy(&output.stdout);
    let (body_str, code_str) = match raw.rsplit_once('\n') {
        Some((b, c)) => (b, c.trim()),
        None => ("", raw.trim()),
    };

    let status_code = code_str.parse::<u16>().ok();
    match status_code {
        Some(code) if (200..300).contains(&code) => HttpProxyResponsePayload {
            ok: true,
            status_code: Some(code),
            body: Some(body_str.to_string()),
            error: None,
        },
        Some(code) => HttpProxyResponsePayload {
            ok: false,
            status_code: Some(code),
            body: None,
            error: Some(format!("HTTP {code}")),
        },
        None => HttpProxyResponsePayload {
            ok: false,
            status_code: None,
            body: None,
            error: Some("Resposta HTTP inválida recebida pelo proxy do PC.".into()),
        },
    }
}

/// Camada de abstração de transporte preparada para WebSocket (Wi-Fi/USB)
/// e futuros módulos Bluetooth RFCOMM / BLE GATT sem alterar `route_message`.
#[async_trait]
pub trait TransportTrait: Send + Sync {
    fn name(&self) -> &'static str;
    async fn start(&self, state: Arc<AgentState>) -> Result<(), String>;
}

pub struct WebSocketTransport {
    pub bind_addr: String,
}

impl WebSocketTransport {
    pub fn new(bind_addr: impl Into<String>) -> Self {
        Self {
            bind_addr: bind_addr.into(),
        }
    }

    pub async fn serve_listener(listener: TcpListener, state: Arc<AgentState>) {
        while let Ok((stream, _peer)) = listener.accept().await {
            let state = state.clone();
            let mut broadcast_rx = state.broadcast_tx.subscribe();

            tokio::spawn(async move {
                let Ok(ws_stream) = tokio_tungstenite::accept_async(stream).await else {
                    return;
                };
                let (mut ws_write, mut ws_read) = ws_stream.split();
                let mut session_token: Option<String> = None;

                loop {
                    tokio::select! {
                        recv_res = broadcast_rx.recv(), if session_token.is_some() => {
                            match recv_res {
                                Ok(broadcast_json) => {
                                    // Garante que o token não foi revogado enquanto a sessão estava aberta
                                    if let Some(ref tok) = session_token {
                                        if !state.is_token_valid(tok).await {
                                            let _ = ws_write.close().await;
                                            break;
                                        }
                                    }
                                    if ws_write.send(Message::Text(broadcast_json.into())).await.is_err() {
                                        break;
                                    }
                                }
                                Err(broadcast::error::RecvError::Lagged(_)) => {
                                    // Descarta amostras antigas e segue enviando a telemetria mais recente
                                    continue;
                                }
                                Err(broadcast::error::RecvError::Closed) => break,
                            }
                        }
                        msg_opt = ws_read.next() => {
                            let Some(Ok(msg)) = msg_opt else { break; };
                            let Message::Text(text) = msg else { continue; };
                            let outcome = route_message(&state, session_token.as_deref(), &text).await;
                            session_token = outcome.authenticated_token;

                            for resp in outcome.responses {
                                if let Ok(json) = serde_json::to_string(&resp) {
                                    if ws_write.send(Message::Text(json.into())).await.is_err() {
                                        return;
                                    }
                                }
                            }
                        }
                    }
                }
            });
        }
    }

    pub async fn bind(&self) -> Result<(TcpListener, SocketAddr), String> {
        let listener = TcpListener::bind(&self.bind_addr)
            .await
            .map_err(|e| format!("Falha ao abrir WebSocket em {}: {e}", self.bind_addr))?;
        let addr = listener
            .local_addr()
            .map_err(|e| format!("Falha ao ler endereço local: {e}"))?;
        Ok((listener, addr))
    }
}

#[async_trait]
impl TransportTrait for WebSocketTransport {
    fn name(&self) -> &'static str {
        "websocket"
    }

    async fn start(&self, state: Arc<AgentState>) -> Result<(), String> {
        let (listener, _addr) = self.bind().await?;
        Self::serve_listener(listener, state).await;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::protocol::{Envelope, MessageType};
    use crate::storage::JsonStore;
    use tokio::time::{timeout, Duration};

    #[tokio::test]
    async fn test_websocket_pair_capabilities_execute_and_layout_sync() {
        let tmp_path = std::env::temp_dir().join(format!(
            "lcars_agent_test_{}.json",
            Uuid::new_v4().simple()
        ));
        let store = JsonStore::new(tmp_path.clone());
        let (tx, _) = broadcast::channel::<String>(32);

        let state = Arc::new(AgentState {
            ws_port: 0,
            telemetry_interval_ms: 500,
            pairing_pin: RwLock::new("654321".into()),
            data: RwLock::new(PersistedData::default()),
            store,
            broadcast_tx: tx,
        });

        let transport = WebSocketTransport::new("127.0.0.1:0");
        let (listener, addr) = transport.bind().await.expect("bind ok");
        let server_state = state.clone();
        let server_handle = tokio::spawn(async move {
            WebSocketTransport::serve_listener(listener, server_state).await;
        });

        let ws_url = format!("ws://{}/ws", addr);
        let (mut ws, _) = tokio_tungstenite::connect_async(&ws_url)
            .await
            .expect("connect ws");

        // 1. Pareamento com PIN incorreto deve ser rejeitado
        let bad_pair = Envelope::new(
            MessageType::PairRequest,
            Some(Uuid::new_v4().to_string()),
            None,
            serde_json::json!({
                "method": "pin",
                "pin": "000000",
                "device_id": Uuid::new_v4().to_string(),
                "device_name": "Test Tablet",
                "platform": "android"
            }),
        );
        ws.send(Message::Text(serde_json::to_string(&bad_pair).unwrap().into()))
            .await
            .unwrap();
        let resp_msg = timeout(Duration::from_secs(2), ws.next())
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        let resp_env: Envelope = serde_json::from_str(resp_msg.to_text().unwrap()).unwrap();
        assert_eq!(resp_env.msg_type, MessageType::PairConfirm);
        assert_eq!(resp_env.payload["status"], "rejected");

        // 2. Pareamento com PIN correto deve aprovar e retornar token + CAPABILITIES_SYNC
        let good_pair = Envelope::new(
            MessageType::PairRequest,
            Some(Uuid::new_v4().to_string()),
            None,
            serde_json::json!({
                "method": "pin",
                "pin": "654321",
                "device_id": Uuid::new_v4().to_string(),
                "device_name": "Galaxy Tab LCARS",
                "platform": "android"
            }),
        );
        ws.send(Message::Text(serde_json::to_string(&good_pair).unwrap().into()))
            .await
            .unwrap();

        let confirm_msg = timeout(Duration::from_secs(2), ws.next())
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        let confirm_env: Envelope = serde_json::from_str(confirm_msg.to_text().unwrap()).unwrap();
        assert_eq!(confirm_env.msg_type, MessageType::PairConfirm);
        assert_eq!(confirm_env.payload["status"], "approved");
        let auth_token = confirm_env.payload["auth_token"].as_str().unwrap().to_string();

        let caps_msg = timeout(Duration::from_secs(2), ws.next())
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        let caps_env: Envelope = serde_json::from_str(caps_msg.to_text().unwrap()).unwrap();
        assert_eq!(caps_env.msg_type, MessageType::CapabilitiesSync);
        assert!(!caps_env.payload["actions"].as_array().unwrap().is_empty());

        // 3. EXECUTE_ACTION com action_id inexistente retorna ACTION_RESULT not_found
        let req_id = Uuid::new_v4().to_string();
        let exec_env = Envelope::new(
            MessageType::ExecuteAction,
            Some(req_id.clone()),
            Some(auth_token.clone()),
            serde_json::json!({ "action_id": "act_inexistente" }),
        );
        ws.send(Message::Text(serde_json::to_string(&exec_env).unwrap().into()))
            .await
            .unwrap();

        let res_msg = timeout(Duration::from_secs(2), ws.next())
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        let res_env: Envelope = serde_json::from_str(res_msg.to_text().unwrap()).unwrap();
        assert_eq!(res_env.msg_type, MessageType::ActionResult);
        assert_eq!(res_env.req_id.as_deref(), Some(req_id.as_str()));
        assert_eq!(res_env.payload["status"], "not_found");

        // 4. LAYOUT_SYNC push + pull_request retorna backup persistido
        let layout_push = Envelope::new(
            MessageType::LayoutSync,
            Some(Uuid::new_v4().to_string()),
            Some(auth_token.clone()),
            serde_json::json!({
                "direction": "push",
                "layout_version": 1,
                "updated_at": chrono::Utc::now().to_rfc3339(),
                "profile_name": "Ponte Teste",
                "grid": { "columns": 6, "rows": 4, "orientation": "landscape" },
                "pages": [{ "id": "p1", "title": "OPS", "accent_color": "amber", "blocks": [] }]
            }),
        );
        ws.send(Message::Text(serde_json::to_string(&layout_push).unwrap().into()))
            .await
            .unwrap();

        let layout_pull = Envelope::new(
            MessageType::LayoutSync,
            Some(Uuid::new_v4().to_string()),
            Some(auth_token),
            serde_json::json!({ "direction": "pull_request" }),
        );
        ws.send(Message::Text(serde_json::to_string(&layout_pull).unwrap().into()))
            .await
            .unwrap();

        let pull_msg = timeout(Duration::from_secs(2), ws.next())
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        let pull_env: Envelope = serde_json::from_str(pull_msg.to_text().unwrap()).unwrap();
        assert_eq!(pull_env.msg_type, MessageType::LayoutSync);
        assert_eq!(pull_env.payload["direction"], "pull_response");
        assert_eq!(pull_env.payload["profile_name"], "Ponte Teste");

        server_handle.abort();
        let _ = std::fs::remove_file(tmp_path);
    }

    #[test]
    fn http_proxy_rejects_non_http_schemes() {
        let res = execute_http_proxy("file:///etc/passwd");
        assert!(!res.ok);
        assert_eq!(res.status_code, Some(400));
        assert!(res.error.is_some());
    }
}
