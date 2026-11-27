use crate::protocol::{
    CpuTelemetry, DiskTelemetry, MemoryTelemetry, NetworkTelemetry, SensorDescriptor,
    TelemetryPayload, TempReading, TemperatureTelemetry,
};
use sysinfo::{Components, Disks, Networks, System};

pub struct TelemetryCollector {
    sys: System,
    networks: Networks,
    components: Components,
    disks: Disks,
    interval_ms: u64,
}

impl TelemetryCollector {
    pub fn new(interval_ms: u64) -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();
        let networks = Networks::new_with_refreshed_list();
        let components = Components::new_with_refreshed_list();
        let disks = Disks::new_with_refreshed_list();
        Self {
            sys,
            networks,
            components,
            disks,
            interval_ms,
        }
    }

    pub fn available_sensors(&self) -> Vec<SensorDescriptor> {
        let has_temp = !self.components.list().is_empty();
        vec![
            SensorDescriptor {
                id: "cpu_total".into(),
                label: "CPU LOAD".into(),
                kind: "cpu".into(),
                unit: "%".into(),
                available: true,
            },
            SensorDescriptor {
                id: "ram_usage".into(),
                label: "MEMORY".into(),
                kind: "memory".into(),
                unit: "GB".into(),
                available: true,
            },
            SensorDescriptor {
                id: "cpu_temp".into(),
                label: "CORE TEMP".into(),
                kind: "temperature".into(),
                unit: "C".into(),
                available: has_temp,
            },
            SensorDescriptor {
                id: "net_primary".into(),
                label: "SUBSPACE LINK".into(),
                kind: "network".into(),
                unit: "KB/s".into(),
                available: true,
            },
            SensorDescriptor {
                id: "disks_primary".into(),
                label: "STORAGE".into(),
                kind: "disk".into(),
                unit: "GB".into(),
                available: !self.disks.list().is_empty(),
            },
        ]
    }

    pub fn sample(&mut self) -> TelemetryPayload {
        self.sys.refresh_cpu_all();
        self.sys.refresh_memory();
        self.networks.refresh(true);
        self.components.refresh(true);
        self.disks.refresh(true);

        let per_core: Vec<f32> = self.sys.cpus().iter().map(|c| c.cpu_usage()).collect();
        let usage_percent = self.sys.global_cpu_usage();
        let frequency_mhz = self.sys.cpus().first().map(|c| c.frequency());

        let total_bytes = self.sys.total_memory();
        let free_bytes = self.sys.available_memory();
        let used_bytes = total_bytes.saturating_sub(free_bytes);
        let mem_pct = if total_bytes > 0 {
            (used_bytes as f32 / total_bytes as f32) * 100.0
        } else {
            0.0
        };

        let temp_readings: Vec<TempReading> = self
            .components
            .list()
            .iter()
            .filter_map(|c| {
                c.temperature().map(|t| TempReading {
                    label: c.label().to_string(),
                    celsius: t,
                })
            })
            .collect();

        let temperature = if temp_readings.is_empty() {
            None
        } else {
            let cpu_celsius = temp_readings
                .iter()
                .find(|r| {
                    let l = r.label.to_lowercase();
                    l.contains("package")
                        || l.contains("tctl")
                        || l.contains("tdie")
                        || l.contains("k10temp")
                        || l.contains("coretemp")
                        || l.contains("cpu")
                })
                .or_else(|| temp_readings.first())
                .map(|r| r.celsius);
            Some(TemperatureTelemetry {
                cpu_celsius,
                gpu_celsius: None,
                sensors: temp_readings,
            })
        };

        let (iface, rx, tx) = self
            .networks
            .iter()
            .max_by_key(|(_, data)| data.received() + data.transmitted())
            .map(|(name, data)| {
                let scale = 1000.0 / (self.interval_ms.max(1) as f64);
                (
                    name.clone(),
                    (data.received() as f64 * scale) as u64,
                    (data.transmitted() as f64 * scale) as u64,
                )
            })
            .unwrap_or_else(|| ("lo".into(), 0, 0));

        let disks: Vec<DiskTelemetry> = self
            .disks
            .list()
            .iter()
            .filter(|d| d.total_space() > 0)
            .map(|d| {
                let total = d.total_space();
                let avail = d.available_space();
                let used = total.saturating_sub(avail);
                let pct = (used as f32 / total as f32) * 100.0;
                DiskTelemetry {
                    name: d.name().to_string_lossy().to_string(),
                    mount_point: d.mount_point().to_string_lossy().to_string(),
                    total_bytes: total,
                    available_bytes: avail,
                    used_bytes: used,
                    usage_percent: pct,
                }
            })
            .collect();

        TelemetryPayload {
            interval_ms: self.interval_ms,
            cpu: CpuTelemetry {
                usage_percent,
                per_core_percent: per_core,
                frequency_mhz,
            },
            memory: MemoryTelemetry {
                total_bytes,
                free_bytes,
                used_bytes,
                usage_percent: mem_pct,
            },
            temperature,
            network: NetworkTelemetry {
                interface: iface,
                rx_bytes_per_sec: rx,
                tx_bytes_per_sec: tx,
            },
            disks,
        }
    }
}
