use mdns_sd::{ServiceDaemon, ServiceInfo};
use std::collections::HashMap;
use std::net::IpAddr;

pub const MDNS_SERVICE_TYPE: &str = "_scifideck-agent._tcp.local.";

pub struct MdnsAdvertiser {
    _daemon: ServiceDaemon,
}

impl MdnsAdvertiser {
    pub fn start(
        agent_id: &str,
        agent_name: &str,
        port: u16,
        local_ip: IpAddr,
    ) -> Result<Self, String> {
        let daemon = ServiceDaemon::new()
            .map_err(|e| format!("Falha ao iniciar daemon mDNS: {e}"))?;

        let host_label = agent_name
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() || c == '-' { c } else { '-' })
            .collect::<String>();
        let host_name = format!("{}.local.", host_label);
        let instance_name = format!("SciFiDeck-{}", host_label);

        let mut properties = HashMap::new();
        properties.insert("version".to_string(), "1.0".to_string());
        properties.insert("agent_id".to_string(), agent_id.to_string());
        properties.insert("agent_name".to_string(), agent_name.to_string());

        let service_info = ServiceInfo::new(
            MDNS_SERVICE_TYPE,
            &instance_name,
            &host_name,
            local_ip,
            port,
            properties,
        )
        .map_err(|e| format!("Falha ao criar ServiceInfo mDNS: {e}"))?;

        daemon
            .register(service_info)
            .map_err(|e| format!("Falha ao registrar serviço mDNS: {e}"))?;

        Ok(Self { _daemon: daemon })
    }
}
