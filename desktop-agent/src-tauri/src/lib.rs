mod actions;
mod mdns;
mod protocol;
mod storage;
mod telemetry;
mod transport;

use crate::mdns::MdnsAdvertiser;
use crate::protocol::{Envelope, MessageType};
use crate::storage::{JsonStore, PairedDevice, RegisteredAction};
use crate::telemetry::TelemetryCollector;
use crate::transport::{AgentState, TransportTrait, WebSocketTransport};
use rand::Rng;
use serde::{Deserialize, Serialize};
use std::net::{IpAddr, Ipv4Addr};
use std::sync::Arc;
use tauri::menu::{MenuBuilder, MenuItemBuilder};
use tauri::tray::TrayIconBuilder;
use tauri::{AppHandle, Emitter, Manager, State, WindowEvent};
use tokio::sync::{broadcast, RwLock};
use tokio::time::{interval, Duration};
use uuid::Uuid;

#[derive(Serialize)]
struct PairingInfoDto {
    agent_name: String,
    os: String,
    ip: String,
    port: u16,
    pin: String,
    ws_url: String,
    qr_payload: String,
    mdns_service: String,
    telemetry_interval_ms: u64,
}

#[derive(Deserialize)]
struct UpsertActionInput {
    id: Option<String>,
    name: String,
    target: String,
    args: Vec<String>,
    category: String,
    command_type: Option<String>,
    color_token: Option<String>,
    confirm_required: Option<bool>,
}

fn generate_pin() -> String {
    let pin: u32 = rand::thread_rng().gen_range(100_000..=999_999);
    pin.to_string()
}

fn detect_local_ip() -> IpAddr {
    local_ip_address::local_ip().unwrap_or(IpAddr::V4(Ipv4Addr::LOCALHOST))
}

fn show_main_window_on_tab(app: &AppHandle, tab: &str) {
    if let Some(win) = app.get_webview_window("main") {
        let _ = win.show();
        let _ = win.unminimize();
        let _ = win.set_focus();
        let _ = win.emit("navigate-tab", tab);
    }
}

#[tauri::command]
async fn get_pairing_info(state: State<'_, Arc<AgentState>>) -> Result<PairingInfoDto, String> {
    let ip = detect_local_ip().to_string();
    let pin = state.pairing_pin.read().await.clone();
    let agent_name = state.data.read().await.agent_name.clone();
    let port = state.ws_port;
    let qr_payload = serde_json::json!({
        "ip": ip,
        "port": port,
        "pin": pin
    })
    .to_string();

    Ok(PairingInfoDto {
        agent_name,
        os: std::env::consts::OS.into(),
        ws_url: format!("ws://{}:{}/ws", ip, port),
        ip,
        port,
        pin,
        qr_payload,
        mdns_service: mdns::MDNS_SERVICE_TYPE.into(),
        telemetry_interval_ms: state.telemetry_interval_ms,
    })
}

#[tauri::command]
async fn regenerate_pin(state: State<'_, Arc<AgentState>>) -> Result<PairingInfoDto, String> {
    let new_pin = generate_pin();
    *state.pairing_pin.write().await = new_pin;
    get_pairing_info(state).await
}

#[tauri::command]
async fn list_actions(state: State<'_, Arc<AgentState>>) -> Result<Vec<RegisteredAction>, String> {
    Ok(state.data.read().await.actions.clone())
}

#[tauri::command]
async fn save_action(
    state: State<'_, Arc<AgentState>>,
    input: UpsertActionInput,
) -> Result<Vec<RegisteredAction>, String> {
    let action = RegisteredAction {
        id: input
            .id
            .filter(|s| !s.trim().is_empty())
            .unwrap_or_else(|| format!("act_{}", &Uuid::new_v4().simple().to_string()[..8])),
        name: input.name.trim().to_string(),
        target: input.target.trim().to_string(),
        args: input.args,
        category: input.category.trim().to_string(),
        command_type: input.command_type.unwrap_or_else(|| "app_launch".into()),
        color_token: Some(input.color_token.unwrap_or_else(|| "amber".into())),
        confirm_required: input.confirm_required.unwrap_or(false),
    };

    let actions_snapshot = {
        let mut data = state.data.write().await;
        if let Some(existing) = data.actions.iter_mut().find(|a| a.id == action.id) {
            *existing = action;
        } else {
            data.actions.push(action);
        }
        data.capabilities_revision += 1;
        state.store.save(&data)?;
        data.actions.clone()
    };

    state.broadcast_capabilities().await;
    Ok(actions_snapshot)
}

#[tauri::command]
async fn delete_action(
    state: State<'_, Arc<AgentState>>,
    action_id: String,
) -> Result<Vec<RegisteredAction>, String> {
    let actions_snapshot = {
        let mut data = state.data.write().await;
        data.actions.retain(|a| a.id != action_id);
        data.capabilities_revision += 1;
        state.store.save(&data)?;
        data.actions.clone()
    };

    state.broadcast_capabilities().await;
    Ok(actions_snapshot)
}

#[tauri::command]
async fn list_devices(state: State<'_, Arc<AgentState>>) -> Result<Vec<PairedDevice>, String> {
    Ok(state.data.read().await.paired_devices.clone())
}

#[tauri::command]
async fn revoke_device(
    state: State<'_, Arc<AgentState>>,
    device_id: String,
) -> Result<Vec<PairedDevice>, String> {
    let devices = {
        let mut data = state.data.write().await;
        data.paired_devices.retain(|d| d.device_id != device_id);
        state.store.save(&data)?;
        data.paired_devices.clone()
    };
    Ok(devices)
}

#[tauri::command]
async fn setup_adb_reverse(state: State<'_, Arc<AgentState>>) -> Result<String, String> {
    let port_spec = format!("tcp:{}", state.ws_port);
    let output = std::process::Command::new("adb")
        .args(["reverse", &port_spec, &port_spec])
        .output()
        .map_err(|e| format!("Não foi possível executar 'adb': {e}"))?;

    if output.status.success() {
        Ok(format!(
            "Túnel USB ativo (adb reverse {} {})",
            port_spec, port_spec
        ))
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        Err(if stderr.is_empty() {
            "Falha ao configurar adb reverse. Verifique se o tablet está conectado com Depuração USB ativa.".into()
        } else {
            stderr
        })
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let store = JsonStore::new(JsonStore::default_path());
    let persisted = store.load_or_default();
    let (broadcast_tx, _) = broadcast::channel::<String>(64);

    let state = Arc::new(AgentState {
        ws_port: 8765,
        telemetry_interval_ms: 750,
        pairing_pin: RwLock::new(generate_pin()),
        data: RwLock::new(persisted),
        store,
        broadcast_tx,
    });

    let ws_state = state.clone();
    let telemetry_state = state.clone();
    let mdns_state = state.clone();

    tauri::Builder::default()
        .manage(state)
        .on_window_event(|window, event| {
            // Mantém o daemon rodando na bandeja ao fechar a janela de configuração
            if let WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .setup(move |app| {
            // 1. System Tray
            let item_actions = MenuItemBuilder::with_id("tray_actions", "Configurar Ações")
                .build(app)?;
            let item_pairing =
                MenuItemBuilder::with_id("tray_pairing", "Parear Dispositivo (QR Code)")
                    .build(app)?;
            let item_quit = MenuItemBuilder::with_id("tray_quit", "Sair").build(app)?;

            let tray_menu = MenuBuilder::new(app)
                .items(&[&item_actions, &item_pairing, &item_quit])
                .build()?;

            let mut tray_builder = TrayIconBuilder::new()
                .menu(&tray_menu)
                .tooltip("LCARS Desktop Agent")
                .on_menu_event(|app, event| match event.id().as_ref() {
                    "tray_actions" => show_main_window_on_tab(app, "actions"),
                    "tray_pairing" => show_main_window_on_tab(app, "pairing"),
                    "tray_quit" => app.exit(0),
                    _ => {}
                });

            if let Some(icon) = app.default_window_icon().cloned() {
                tray_builder = tray_builder.icon(icon);
            }
            tray_builder.build(app)?;

            // 2. Loop de Telemetria (sysinfo) em broadcast
            tauri::async_runtime::spawn(async move {
                let interval_ms = telemetry_state.telemetry_interval_ms;
                let mut collector = TelemetryCollector::new(interval_ms);
                let mut ticker = interval(Duration::from_millis(interval_ms));
                loop {
                    ticker.tick().await;
                    let sample = collector.sample();
                    if let Ok(val) = serde_json::to_value(sample) {
                        let env = Envelope::new(MessageType::Telemetry, None, None, val);
                        if let Ok(json) = serde_json::to_string(&env) {
                            let _ = telemetry_state.broadcast_tx.send(json);
                        }
                    }
                }
            });

            // 3. Transporte WebSocket (compatível com Wi-Fi e adb reverse USB)
            tauri::async_runtime::spawn(async move {
                let transport = WebSocketTransport::new(format!("0.0.0.0:{}", ws_state.ws_port));
                if let Err(err) = transport.start(ws_state).await {
                    eprintln!("[LCARS Agent] Erro no transporte {}: {}", transport.name(), err);
                }
            });

            // 4. Anúncio mDNS (_lcars-agent._tcp.local.)
            tauri::async_runtime::spawn(async move {
                let (agent_id, agent_name) = {
                    let d = mdns_state.data.read().await;
                    (d.agent_id.clone(), d.agent_name.clone())
                };
                let ip = detect_local_ip();
                match MdnsAdvertiser::start(&agent_id, &agent_name, mdns_state.ws_port, ip) {
                    Ok(_advertiser) => {
                        // Mantém o daemon mDNS vivo durante toda a execução
                        std::future::pending::<()>().await;
                    }
                    Err(err) => {
                        eprintln!("[LCARS Agent] Aviso mDNS: {err}");
                    }
                }
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_pairing_info,
            regenerate_pin,
            list_actions,
            save_action,
            delete_action,
            list_devices,
            revoke_device,
            setup_adb_reverse
        ])
        .run(tauri::generate_context!())
        .expect("erro ao iniciar LCARS Desktop Agent");
}
