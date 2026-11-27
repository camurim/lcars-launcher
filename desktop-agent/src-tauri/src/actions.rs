use crate::protocol::ActionResultPayload;
use crate::storage::RegisteredAction;
use std::process::{Command, Stdio};
use std::time::Instant;

pub fn default_actions() -> Vec<RegisteredAction> {
    #[cfg(target_os = "windows")]
    let terminal_target = "wt".to_string();
    #[cfg(not(target_os = "windows"))]
    let terminal_target = "x-terminal-emulator".to_string();

    vec![
        RegisteredAction {
            id: "act_open_vscode".into(),
            name: "VS CODE".into(),
            category: "apps".into(),
            command_type: "app_launch".into(),
            target: "code".into(),
            args: vec![],
            color_token: Some("amber".into()),
            confirm_required: false,
        },
        RegisteredAction {
            id: "act_open_terminal".into(),
            name: "TERMINAL".into(),
            category: "apps".into(),
            command_type: "app_launch".into(),
            target: terminal_target,
            args: vec![],
            color_token: Some("peach".into()),
            confirm_required: false,
        },
        RegisteredAction {
            id: "act_open_docs".into(),
            name: "LCARS DOCS".into(),
            category: "web".into(),
            command_type: "app_launch".into(),
            target: "https://tauri.app".into(),
            args: vec![],
            color_token: Some("cyan".into()),
            confirm_required: false,
        },
        RegisteredAction {
            id: "act_sys_uptime".into(),
            name: "UPTIME".into(),
            category: "system".into(),
            command_type: "shell".into(),
            #[cfg(target_os = "windows")]
            target: "powershell".into(),
            #[cfg(not(target_os = "windows"))]
            target: "uptime".into(),
            #[cfg(target_os = "windows")]
            args: vec![
                "-NoProfile".into(),
                "-Command".into(),
                "(Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime | ForEach-Object { \"up $($_.Days)d $($_.Hours)h $($_.Minutes)m\" }".into(),
            ],
            #[cfg(not(target_os = "windows"))]
            args: vec!["-p".into()],
            color_token: Some("cyan".into()),
            confirm_required: false,
        },
    ]
}

fn is_url(target: &str) -> bool {
    target.starts_with("http://") || target.starts_with("https://")
}

/// Executa o aplicativo, script ou URL de forma desacoplada do processo pai
/// para Windows (`cmd /C start`) e Linux (`setsid` / `xdg-open` com variáveis de sessão gráfica).
pub fn spawn_detached(target: &str, args: &[String]) -> Result<u32, String> {
    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        const DETACHED_PROCESS: u32 = 0x0000_0008;

        let mut cmd = Command::new("cmd");
        cmd.arg("/C").arg("start").arg("").arg(target);
        for a in args {
            cmd.arg(a);
        }
        cmd.stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .creation_flags(CREATE_NO_WINDOW | DETACHED_PROCESS);

        let child = cmd
            .spawn()
            .map_err(|e| format!("Falha ao iniciar '{}' no Windows: {e}", target))?;
        return Ok(child.id());
    }

    #[cfg(not(target_os = "windows"))]
    {
        let mut cmd = if is_url(target) {
            let mut c = Command::new("setsid");
            c.arg("-f").arg("xdg-open").arg(target);
            c
        } else {
            let mut c = Command::new("setsid");
            c.arg("-f").arg(target);
            for a in args {
                c.arg(a);
            }
            c
        };

        // Propaga explicitamente variáveis de sessão gráfica Linux se presentes
        for var in [
            "DISPLAY",
            "WAYLAND_DISPLAY",
            "XDG_RUNTIME_DIR",
            "DBUS_SESSION_BUS_ADDRESS",
            "XAUTHORITY",
        ] {
            if let Ok(val) = std::env::var(var) {
                cmd.env(var, val);
            }
        }

        cmd.stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null());

        let child = cmd
            .spawn()
            .map_err(|e| format!("Falha ao iniciar '{}' via setsid: {e}", target))?;
        Ok(child.id())
    }
}

/// Executa um comando e captura sua saída (`stdout`/`stderr`) para exibir em painéis de texto.
pub fn run_capture_output(target: &str, args: &[String]) -> Result<(i32, String), String> {
    let mut cmd = Command::new(target);
    cmd.args(args).stdin(Stdio::null());

    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        cmd.creation_flags(CREATE_NO_WINDOW);
    }

    let output = cmd
        .output()
        .map_err(|e| format!("Falha ao executar '{}': {e}", target))?;

    let code = output.status.code().unwrap_or(-1);
    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();

    let text = if !stdout.is_empty() {
        stdout
    } else if !stderr.is_empty() {
        stderr
    } else {
        "(sem saída)".to_string()
    };

    let truncated: String = text.chars().take(512).collect();
    Ok((code, truncated))
}

/// Helper para tentar múltiplos comandos Linux em ordem de fallback (PipeWire -> PulseAudio -> ALSA / playerctl).
#[cfg(not(target_os = "windows"))]
fn try_commands_linux(candidates: &[(&str, &[&str])]) -> Result<(), String> {
    let mut last_err = String::new();
    for (prog, args) in candidates {
        match Command::new(prog)
            .args(*args)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .output()
        {
            Ok(out) if out.status.success() => return Ok(()),
            Ok(out) => {
                let err = String::from_utf8_lossy(&out.stderr).trim().to_string();
                last_err = format!("{prog}: {err}");
            }
            Err(e) => {
                last_err = format!("{prog}: {e}");
            }
        }
    }
    Err(format!(
        "Nenhum utilitário suportado respondeu ({last_err})"
    ))
}

#[cfg(target_os = "windows")]
fn send_windows_virtual_key(vk_hex: &str) -> Result<(), String> {
    use std::os::windows::process::CommandExt;
    const CREATE_NO_WINDOW: u32 = 0x0800_0000;
    let ps = format!(
        "Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class K {{ [DllImport(\"user32.dll\")] public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo); }}'; [K]::keybd_event({vk_hex}, 0, 0, 0); [K]::keybd_event({vk_hex}, 0, 2, 0);"
    );
    let out = Command::new("powershell")
        .args(["-NoProfile", "-Command", &ps])
        .creation_flags(CREATE_NO_WINDOW)
        .output()
        .map_err(|e| format!("Falha ao enviar tecla multimídia: {e}"))?;
    if out.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&out.stderr).trim().to_string())
    }
}

/// Executa controles nativos de áudio, mídia e sistema (Linux e Windows).
pub fn execute_system_control(control: &str) -> Result<String, String> {
    #[cfg(target_os = "windows")]
    {
        match control {
            "volume_up" => {
                send_windows_virtual_key("0xAF")?;
                Ok("Volume do PC aumentado".into())
            }
            "volume_down" => {
                send_windows_virtual_key("0xAE")?;
                Ok("Volume do PC diminuído".into())
            }
            "volume_mute" => {
                send_windows_virtual_key("0xAD")?;
                Ok("Mudo do PC alternado".into())
            }
            "play_pause" => {
                send_windows_virtual_key("0xB3")?;
                Ok("Play / Pause enviado".into())
            }
            "next_track" => {
                send_windows_virtual_key("0xB0")?;
                Ok("Próxima faixa".into())
            }
            "prev_track" => {
                send_windows_virtual_key("0xB1")?;
                Ok("Faixa anterior".into())
            }
            "lock_screen" => {
                Command::new("rundll32.exe")
                    .args(["user32.dll,LockWorkStation"])
                    .spawn()
                    .map_err(|e| format!("Falha ao bloquear tela: {e}"))?;
                Ok("Estação bloqueada".into())
            }
            "suspend" => {
                Command::new("rundll32.exe")
                    .args(["powrprof.dll,SetSuspendState", "0,1,0"])
                    .spawn()
                    .map_err(|e| format!("Falha ao suspender: {e}"))?;
                Ok("Suspendendo PC".into())
            }
            _ => Err(format!("Controle '{control}' não suportado no Windows")),
        }
    }

    #[cfg(not(target_os = "windows"))]
    {
        match control {
            "volume_up" => {
                try_commands_linux(&[
                    ("wpctl", &["set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "5%+"]),
                    ("pactl", &["set-sink-volume", "@DEFAULT_SINK@", "+5%"]),
                    ("amixer", &["-D", "pulse", "sset", "Master", "5%+"]),
                ])?;
                Ok("Volume do PC +5%".into())
            }
            "volume_down" => {
                try_commands_linux(&[
                    ("wpctl", &["set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]),
                    ("pactl", &["set-sink-volume", "@DEFAULT_SINK@", "-5%"]),
                    ("amixer", &["-D", "pulse", "sset", "Master", "5%-"]),
                ])?;
                Ok("Volume do PC -5%".into())
            }
            "volume_mute" => {
                try_commands_linux(&[
                    ("wpctl", &["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]),
                    ("pactl", &["set-sink-mute", "@DEFAULT_SINK@", "toggle"]),
                    ("amixer", &["-D", "pulse", "sset", "Master", "toggle"]),
                ])?;
                Ok("Mudo do PC alternado".into())
            }
            "mic_mute" => {
                try_commands_linux(&[
                    ("wpctl", &["set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]),
                    ("pactl", &["set-source-mute", "@DEFAULT_SOURCE@", "toggle"]),
                ])?;
                Ok("Microfone alternado (mudo/ativo)".into())
            }
            "play_pause" => {
                try_commands_linux(&[
                    ("playerctl", &["play-pause"]),
                    ("xdotool", &["key", "XF86AudioPlay"]),
                ])?;
                Ok("Play / Pause enviado".into())
            }
            "next_track" => {
                try_commands_linux(&[
                    ("playerctl", &["next"]),
                    ("xdotool", &["key", "XF86AudioNext"]),
                ])?;
                Ok("Próxima faixa".into())
            }
            "prev_track" => {
                try_commands_linux(&[
                    ("playerctl", &["previous"]),
                    ("xdotool", &["key", "XF86AudioPrev"]),
                ])?;
                Ok("Faixa anterior".into())
            }
            "lock_screen" => {
                try_commands_linux(&[
                    ("loginctl", &["lock-session"]),
                    ("xdg-screensaver", &["lock"]),
                ])?;
                Ok("Estação bloqueada".into())
            }
            "suspend" => {
                try_commands_linux(&[("systemctl", &["suspend"])])?;
                Ok("Suspendendo PC".into())
            }
            _ => Err(format!("Controle '{control}' desconhecido")),
        }
    }
}

pub fn execute_registered_action(
    actions: &[RegisteredAction],
    action_id: &str,
) -> ActionResultPayload {
    let start = Instant::now();
    let Some(action) = actions.iter().find(|a| a.id == action_id) else {
        return ActionResultPayload {
            action_id: action_id.to_string(),
            status: "not_found".into(),
            exit_code: None,
            duration_ms: start.elapsed().as_millis() as u64,
            message: Some(format!("Ação '{}' não encontrada", action_id)),
        };
    };

    if action.command_type == "media_key" || action.command_type == "system_power" {
        return match execute_system_control(&action.target) {
            Ok(msg) => ActionResultPayload {
                action_id: action_id.to_string(),
                status: "ok".into(),
                exit_code: Some(0),
                duration_ms: start.elapsed().as_millis() as u64,
                message: Some(msg),
            },
            Err(err) => ActionResultPayload {
                action_id: action_id.to_string(),
                status: "error".into(),
                exit_code: None,
                duration_ms: start.elapsed().as_millis() as u64,
                message: Some(err),
            },
        };
    }

    if action.command_type == "shell" {
        return match run_capture_output(&action.target, &action.args) {
            Ok((code, text)) => ActionResultPayload {
                action_id: action_id.to_string(),
                status: if code == 0 { "ok".into() } else { "error".into() },
                exit_code: Some(code),
                duration_ms: start.elapsed().as_millis() as u64,
                message: Some(text),
            },
            Err(err) => ActionResultPayload {
                action_id: action_id.to_string(),
                status: "error".into(),
                exit_code: None,
                duration_ms: start.elapsed().as_millis() as u64,
                message: Some(err),
            },
        };
    }

    match spawn_detached(&action.target, &action.args) {
        Ok(pid) => ActionResultPayload {
            action_id: action_id.to_string(),
            status: "ok".into(),
            exit_code: Some(0),
            duration_ms: start.elapsed().as_millis() as u64,
            message: Some(format!("Iniciado '{}' (PID {})", action.target, pid)),
        },
        Err(err) => ActionResultPayload {
            action_id: action_id.to_string(),
            status: "error".into(),
            exit_code: None,
            duration_ms: start.elapsed().as_millis() as u64,
            message: Some(err),
        },
    }
}
