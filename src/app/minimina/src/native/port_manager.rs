use crate::service::ServiceConfig;
use std::io;
use std::net::TcpListener;

pub fn check_ports_available(ports: &[u16]) -> io::Result<()> {
    for &port in ports {
        TcpListener::bind(format!("127.0.0.1:{}", port)).map_err(|_| {
            io::Error::new(
                io::ErrorKind::AddrInUse,
                format!("Port {} is already in use", port),
            )
        })?;
    }
    Ok(())
}

/// The ports the daemons themselves will bind. Archive's own ports (postgres
/// and the archive-service) are added by the plan builder, which is where the
/// per-network postgres port is known.
pub fn collect_all_ports(services: &[ServiceConfig]) -> Vec<u16> {
    let mut ports = Vec::new();
    for service in services {
        if let Some(client_port) = service.client_port {
            ports.push(client_port);
            ports.push(client_port + 1);
            ports.push(client_port + 2);
            ports.push(client_port + 3);
            ports.push(client_port + 4);
        }
    }
    ports
}
