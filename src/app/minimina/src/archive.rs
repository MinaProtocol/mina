//! Shared archive **contract**: the cross-backend constants and command helpers
//! both plan builders must agree on so an archive-node daemon can reach its
//! archive service regardless of backend — the postgres connection params, the
//! `mina-archive` service command line, the archive-service unit name (which is
//! the service's DNS host under docker), and the default server port.
//!
//! Backend-*internal* postgres details do NOT belong here: the native socket
//! dir / server args / unit name live in [`crate::native::archive`]; the docker
//! image + container env in [`crate::docker::archive`]. Only what the two
//! backends must keep in lockstep is shared.
//!
//! Archive is three units: **postgres** (ephemeral DB), **archive-service**
//! (`mina-archive run …`), and **archive-node** (a mina daemon with
//! `-archive-address`).

/// Default archive-service server port when the topology doesn't specify one.
pub const DEFAULT_ARCHIVE_PORT: u16 = 3086;

/// The (fixed, local-only) postgres configuration shared by both backends — one
/// source of truth for the connection params. The shapes different consumers
/// need (the connection URI here; the docker image env in [`crate::docker::archive`])
/// are *derived* from these fields, so we never re-parse a connection string
/// back into parts.
pub struct PgConfig {
    pub user: &'static str,
    pub password: &'static str,
    pub db: &'static str,
    pub port: u16,
}

impl Default for PgConfig {
    /// The standard local-only settings. Override individual fields with struct
    /// update syntax, e.g. `PgConfig { port: free, ..Default::default() }`.
    fn default() -> Self {
        PgConfig {
            user: "postgres",
            password: "postgres",
            db: "archive",
            port: 5432,
        }
    }
}

impl PgConfig {
    /// Connection URI for the archive-service's `--postgres-uri`.
    fn uri(&self, host: &str) -> String {
        format!(
            "postgres://{}:{}@{host}:{}/{}",
            self.user, self.password, self.port, self.db
        )
    }
}

/// Args to `mina-archive` for the archive-service (i.e. everything after the
/// `mina-archive` program itself). `pg_host` is where the service finds
/// postgres: `localhost` (native) or the postgres container's DNS name (docker).
pub fn archive_service_args(pg_host: &str, archive_port: u16) -> Vec<String> {
    vec![
        "run".to_string(),
        "--postgres-uri".to_string(),
        PgConfig::default().uri(pg_host),
        "--server-port".to_string(),
        archive_port.to_string(),
    ]
}

/// Supervisor unit name for the archive-service unit of archive node `name`.
/// Under docker this doubles as the container name and DNS alias the
/// archive-node daemon dials, so both backends must derive it identically.
pub fn archive_service_unit_name(archive_node_name: &str) -> String {
    format!("{archive_node_name}-archive-service")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::service::{ServiceConfig, ServiceType};

    /// With no `archive_port` in the topology, the archive-service's
    /// `--server-port` and the daemon's `-archive-address` must land on the
    /// same (default) port.
    #[test]
    fn daemon_and_service_agree_on_unset_archive_port() {
        let node = ServiceConfig {
            service_type: ServiceType::ArchiveNode,
            service_name: "archive".to_string(),
            ..Default::default()
        };
        assert_eq!(node.archive_port, None);

        let port = node.resolved_archive_port();
        assert_eq!(port, DEFAULT_ARCHIVE_PORT);

        let svc_args = archive_service_args("localhost", port);
        let server_port = svc_args
            .iter()
            .position(|a| a == "--server-port")
            .map(|i| svc_args[i + 1].clone())
            .expect("--server-port missing from archive-service args");
        assert_eq!(server_port, port.to_string());

        let daemon_cmd = node.generate_archive_command("svc-host".to_string());
        assert!(
            daemon_cmd.contains(&format!("-archive-address svc-host:{port}")),
            "daemon command must dial the archive-service port: {daemon_cmd}"
        );
    }
}
