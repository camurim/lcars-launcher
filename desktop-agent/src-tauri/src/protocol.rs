use serde::{Deserialize, Serialize};
use serde_json::Value;

pub const PROTOCOL_VERSION: &str = "1.0";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum MessageType {
    PairRequest,
    PairConfirm,
    CapabilitiesSync,
    Telemetry,
    ExecuteAction,
    ActionResult,
    LayoutSync,
    HttpProxyRequest,
    HttpProxyResponse,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Envelope {
    pub version: String,
    #[serde(rename = "type")]
    pub msg_type: MessageType,
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub req_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub token: Option<String>,
    pub payload: Value,
}

impl Envelope {
    pub fn new(
        msg_type: MessageType,
        req_id: Option<String>,
        token: Option<String>,
        payload: Value,
    ) -> Self {
        Self {
            version: PROTOCOL_VERSION.to_string(),
            msg_type,
            timestamp: chrono::Utc::now().to_rfc3339(),
            req_id,
            token,
            payload,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairRequestPayload {
    pub method: String,
    pub pin: Option<String>,
    pub qr_nonce: Option<String>,
    pub device_id: String,
    pub device_name: String,
    pub platform: String,
    pub app_version: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairConfirmPayload {
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub auth_token: Option<String>,
    pub agent_id: String,
    pub agent_name: String,
    pub os: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub telemetry_interval_ms: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_code: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActionDescriptor {
    pub id: String,
    pub name: String,
    pub category: String,
    pub command_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub color_token: Option<String>,
    pub confirm_required: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SensorDescriptor {
    pub id: String,
    pub label: String,
    pub kind: String,
    pub unit: String,
    pub available: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CapabilitiesSyncPayload {
    pub revision: u64,
    pub actions: Vec<ActionDescriptor>,
    pub sensors: Vec<SensorDescriptor>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CpuTelemetry {
    pub usage_percent: f32,
    pub per_core_percent: Vec<f32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub frequency_mhz: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryTelemetry {
    pub total_bytes: u64,
    pub free_bytes: u64,
    pub used_bytes: u64,
    pub usage_percent: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TempReading {
    pub label: String,
    pub celsius: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemperatureTelemetry {
    pub cpu_celsius: Option<f32>,
    pub gpu_celsius: Option<f32>,
    pub sensors: Vec<TempReading>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkTelemetry {
    pub interface: String,
    pub rx_bytes_per_sec: u64,
    pub tx_bytes_per_sec: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskTelemetry {
    pub name: String,
    pub mount_point: String,
    pub total_bytes: u64,
    pub available_bytes: u64,
    pub used_bytes: u64,
    pub usage_percent: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TelemetryPayload {
    pub interval_ms: u64,
    pub cpu: CpuTelemetry,
    pub memory: MemoryTelemetry,
    pub temperature: Option<TemperatureTelemetry>,
    pub network: NetworkTelemetry,
    pub disks: Vec<DiskTelemetry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecuteActionPayload {
    pub action_id: String,
    #[serde(default)]
    pub args: Option<Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActionResultPayload {
    pub action_id: String,
    pub status: String,
    pub exit_code: Option<i32>,
    pub duration_ms: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HttpProxyRequestPayload {
    pub url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HttpProxyResponsePayload {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status_code: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub body: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}
