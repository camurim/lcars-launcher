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
