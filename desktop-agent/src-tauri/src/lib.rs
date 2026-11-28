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

#[derive(Serialize, Deserialize)]
struct DesktopBackupDto {
    schema: String,
    exported_at: String,
    actions: Vec<RegisteredAction>,
    layout_backup: Option<serde_json::Value>,
}

#[derive(Deserialize)]
struct DesktopBackupImportDto {
    #[serde(default)]
    schema: Option<String>,
    #[serde(default)]
    agent_name: Option<String>,
    #[serde(default)]
    actions: Option<Vec<RegisteredAction>>,
    #[serde(default)]
    paired_devices: Option<Vec<PairedDevice>>,
    #[serde(default)]
    layout_backup: Option<serde_json::Value>,
}

#[derive(Serialize)]
struct ImportBackupResult {
    actions: Vec<RegisteredAction>,
    actions_count: usize,
    devices_restored: usize,
    layout_restored: bool,
}

fn parse_desktop_backup(raw_json: &str) -> Result<DesktopBackupImportDto, String> {
    let trimmed = raw_json.trim_start_matches('\u{feff}').trim();
    if trimmed.is_empty() {
        return Err("Arquivo de backup vazio.".into());
    }

    let value: serde_json::Value =
        serde_json::from_str(trimmed).map_err(|e| format!("JSON inválido: {e}"))?;

    if !value.is_object() {
        return Err("Formato de backup inválido: o arquivo JSON deve conter um objeto na raiz.".into());
    }

    let parsed: DesktopBackupImportDto = serde_json::from_value(value)
        .map_err(|e| format!("Estrutura de backup inválida: {e}"))?;

    if let Some(ref schema) = parsed.schema {
        if schema != "lcars_desktop_backup_v1" {
            return Err(format!(
                "Versão de schema de backup não suportada: '{schema}'."
            ));
        }
    }

    if parsed.actions.is_none() && parsed.layout_backup.is_none() && parsed.paired_devices.is_none()
    {
        return Err(
            "Formato de backup não reconhecido: o arquivo deve conter 'actions', 'layout_backup' ou 'paired_devices'."
                .into(),
        );
    }

    Ok(parsed)
}

#[tauri::command]
async fn export_desktop_backup(state: State<'_, Arc<AgentState>>) -> Result<String, String> {
    let data = state.data.read().await;
    let backup = DesktopBackupDto {
        schema: "lcars_desktop_backup_v1".into(),
        exported_at: chrono::Utc::now().to_rfc3339(),
        actions: data.actions.clone(),
        layout_backup: data.layout_backup.clone(),
    };
    serde_json::to_string_pretty(&backup).map_err(|e| format!("Falha ao serializar backup: {e}"))
}

#[tauri::command]
async fn import_desktop_backup(
    state: State<'_, Arc<AgentState>>,
    raw_json: String,
) -> Result<ImportBackupResult, String> {
    let parsed = parse_desktop_backup(&raw_json)?;

    let (actions_snapshot, devices_restored, layout_restored) = {
        let mut data = state.data.write().await;
        if let Some(actions) = parsed.actions {
            data.actions = actions;
        }
        let mut restored_devices = 0usize;
        if let Some(devices) = parsed.paired_devices {
            restored_devices = devices.len();
            data.paired_devices = devices;
        }
        let mut restored_layout = false;
        if let Some(layout) = parsed.layout_backup {
            data.layout_backup = Some(layout);
            restored_layout = true;
        }
        if let Some(name) = parsed.agent_name.filter(|s| !s.trim().is_empty()) {
            data.agent_name = name;
        }
        data.capabilities_revision += 1;
        state.store.save(&data)?;
        (data.actions.clone(), restored_devices, restored_layout)
    };

    state.broadcast_capabilities().await;
    Ok(ImportBackupResult {
        actions_count: actions_snapshot.len(),
        actions: actions_snapshot,
        devices_restored,
        layout_restored,
    })
}

fn tray_labels_for_system_locale() -> (&'static str, &'static str, &'static str) {
    let locale = std::env::var("LC_ALL")
        .or_else(|_| std::env::var("LANG"))
        .unwrap_or_default()
        .to_lowercase();
    if locale.starts_with("pt") {
        ("Configurar Ações", "Parear Dispositivo (QR Code)", "Sair")
    } else if locale.starts_with("es") {
        ("Configurar Acciones", "Emparejar Dispositivo (Código QR)", "Salir")
    } else {
        ("Configure Actions", "Pair Device (QR Code)", "Quit")
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
            // 1. System Tray (localizado em en / pt / es)
            let (lbl_actions, lbl_pairing, lbl_quit) = tray_labels_for_system_locale();
            let item_actions = MenuItemBuilder::with_id("tray_actions", lbl_actions)
                .build(app)?;
            let item_pairing =
                MenuItemBuilder::with_id("tray_pairing", lbl_pairing)
                    .build(app)?;
            let item_quit = MenuItemBuilder::with_id("tray_quit", lbl_quit).build(app)?;

            let tray_menu = MenuBuilder::new(app)
                .items(&[&item_actions, &item_pairing, &item_quit])
                .build()?;

            let mut tray_builder = TrayIconBuilder::new()
                .menu(&tray_menu)
                .tooltip("Sci-Fi Deck Agent")
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
            setup_adb_reverse,
            export_desktop_backup,
            import_desktop_backup
        ])
        .run(tauri::generate_context!())
        .expect("erro ao iniciar LCARS Desktop Agent");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_exported_backup_format() {
        let json = r#"{
            "schema": "lcars_desktop_backup_v1",
            "exported_at": "2026-11-28T00:00:00Z",
            "actions": [
                {
                    "id": "act_1",
                    "name": "Terminal",
                    "category": "apps",
                    "command_type": "app_launch",
                    "target": "x-terminal-emulator",
                    "args": [],
                    "color_token": "peach",
                    "confirm_required": false
                }
            ],
            "layout_backup": { "layout_version": 1 }
        }"#;

        let parsed = parse_desktop_backup(json).expect("should parse exported backup");
        assert_eq!(parsed.actions.unwrap().len(), 1);
        assert!(parsed.layout_backup.is_some());
    }

    #[test]
    fn parses_agent_state_json_format() {
        let json = r#"{
            "agent_id": "c9357700-ad21-414a-8285-e26958c1b082",
            "agent_name": "USS-WORKSTATION-01",
            "capabilities_revision": 5,
            "actions": [
                {
                    "id": "act_open_terminal",
                    "name": "TERMINAL",
                    "category": "apps",
                    "command_type": "app_launch",
                    "target": "x-terminal-emulator",
                    "args": [],
                    "color_token": "peach",
                    "confirm_required": false
                }
            ],
            "paired_devices": [
                {
                    "device_id": "38c3db92-2fd7-4d89-b20b-8060a7837e32",
                    "device_name": "LCARS Tablet Console",
                    "platform": "android",
                    "token": "lcars_tok_d5612df661d2468d89c4b1191a0160e4",
                    "paired_at": "2026-11-27T12:39:18.870521127+00:00"
                }
            ],
            "layout_backup": { "layout_version": 21, "pages": [] }
        }"#;

        let parsed = parse_desktop_backup(json).expect("should parse agent_state.json");
        assert_eq!(parsed.agent_name.as_deref(), Some("USS-WORKSTATION-01"));
        assert_eq!(parsed.actions.unwrap().len(), 1);
        assert_eq!(parsed.paired_devices.unwrap().len(), 1);
        assert!(parsed.layout_backup.is_some());
    }

    #[test]
    fn rejects_invalid_or_unrelated_json() {
        assert!(parse_desktop_backup("").is_err());
        assert!(parse_desktop_backup("{not json").is_err());
        assert!(parse_desktop_backup("{}").is_err());
        assert!(parse_desktop_backup(r#"{"schema":"unknown_v99","actions":[]}"#).is_err());
    }
}
