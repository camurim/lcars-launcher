use crate::actions::default_actions;
use crate::protocol::ActionDescriptor;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::PathBuf;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisteredAction {
    pub id: String,
    pub name: String,
    pub category: String,
    pub command_type: String,
    /// Caminho do executável, script ou URL (http/https).
    pub target: String,
    #[serde(default)]
    pub args: Vec<String>,
    #[serde(default)]
    pub color_token: Option<String>,
    #[serde(default)]
    pub confirm_required: bool,
}

impl RegisteredAction {
    pub fn to_descriptor(&self) -> ActionDescriptor {
        ActionDescriptor {
            id: self.id.clone(),
            name: self.name.clone(),
            category: self.category.clone(),
            command_type: self.command_type.clone(),
            icon: None,
            color_token: self.color_token.clone(),
            confirm_required: self.confirm_required,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairedDevice {
    pub device_id: String,
    pub device_name: String,
    pub platform: String,
    pub token: String,
    pub paired_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersistedData {
    pub agent_id: String,
    pub agent_name: String,
    pub capabilities_revision: u64,
    pub actions: Vec<RegisteredAction>,
    pub paired_devices: Vec<PairedDevice>,
    pub layout_backup: Option<Value>,
}

impl Default for PersistedData {
    fn default() -> Self {
        let host = std::env::var("HOSTNAME")
            .or_else(|_| std::env::var("COMPUTERNAME"))
            .unwrap_or_else(|_| "USS-WORKSTATION-01".into());
        Self {
            agent_id: Uuid::new_v4().to_string(),
            agent_name: host,
            capabilities_revision: 1,
            actions: default_actions(),
            paired_devices: Vec::new(),
            layout_backup: None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct JsonStore {
    path: PathBuf,
}

impl JsonStore {
    pub fn default_path() -> PathBuf {
        let base = dirs::data_dir().unwrap_or_else(|| PathBuf::from("."));
        base.join("lcars-launcher").join("agent_state.json")
    }

    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn load_or_default(&self) -> PersistedData {
        if let Ok(content) = fs::read_to_string(&self.path) {
            if let Ok(parsed) = serde_json::from_str::<PersistedData>(&content) {
                return parsed;
            }
        }
        let data = PersistedData::default();
        let _ = self.save(&data);
        data
    }

    pub fn save(&self, data: &PersistedData) -> Result<(), String> {
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("Falha ao criar diretório: {e}"))?;
        }
        let json = serde_json::to_string_pretty(data)
            .map_err(|e| format!("Falha ao serializar estado: {e}"))?;
        fs::write(&self.path, json).map_err(|e| format!("Falha ao gravar arquivo: {e}"))
    }
}
