use crate::service::{ServiceConfig, ServiceType};
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
        if let Some(archive_port) = service.archive_port {
            ports.push(archive_port);
        }
        if service.service_type == ServiceType::ArchiveNode {
            ports.push(5432);
        }
    }
    ports
}
