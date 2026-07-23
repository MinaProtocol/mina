//! Shared archive constants + command helpers, used by both the native and
//! docker plan builders so the archive topology (postgres + archive-service +
//! archive-node) is expressed identically across backends.
//!
//! Archive is three units:
//!   * **postgres** — ephemeral DB (native: an `initdb`'d cluster run as a
//!     process; docker: a `postgres` container with `POSTGRES_DB` + initdb.d
//!     schema). Created + schema-applied at `network create`.
//!   * **archive-service** — `mina-archive run --postgres-uri … --server-port N`.
//!   * **archive-node** — a normal mina daemon with `-archive-address`.

/// Docker image for the ephemeral postgres container.
pub const PG_IMAGE: &str = "postgres:16";
/// Default archive-service server port when the topology doesn't specify one.
pub const DEFAULT_ARCHIVE_PORT: u16 = 3086;

/// The (fixed, local-only) postgres configuration shared by both backends — one
/// source of truth. The shapes different consumers need — the connection URI and
/// the docker image's env vars — are *derived* views, so we never re-parse a
/// connection string back into parts for the pg CLI tools / image env.
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
    pub fn uri(&self, host: &str) -> String {
        format!(
            "postgres://{}:{}@{host}:{}/{}",
            self.user, self.password, self.port, self.db
        )
    }

    /// Env for the docker `postgres` image: `POSTGRES_DB` creates the database
    /// and, on first boot, the entrypoint applies `/docker-entrypoint-initdb.d`.
    pub fn container_env(&self) -> Vec<(String, String)> {
        vec![
            ("POSTGRES_USER".to_string(), self.user.to_string()),
            ("POSTGRES_PASSWORD".to_string(), self.password.to_string()),
            ("POSTGRES_DB".to_string(), self.db.to_string()),
        ]
    }
}

/// Args to `mina-archive` for the archive-service (i.e. everything after the
/// `mina-archive` program itself).
pub fn archive_service_args(pg_host: &str, archive_port: u16) -> Vec<String> {
    vec![
        "run".to_string(),
        "--postgres-uri".to_string(),
        PgConfig::default().uri(pg_host),
        "--server-port".to_string(),
        archive_port.to_string(),
    ]
}

/// Supervisor unit name for the postgres unit of a network.
pub fn postgres_unit_name() -> String {
    "postgres".to_string()
}

/// Supervisor unit name for the archive-service unit of archive node `name`.
pub fn archive_service_unit_name(archive_node_name: &str) -> String {
    format!("{archive_node_name}-archive-service")
}

/// Short unix-socket directory for the native postgres. Network dirs are often
/// deeper than the ~107-char unix-socket path limit, so the socket lives under
/// `/tmp` (per-network); all real connections use TCP on `127.0.0.1:PG.port`.
pub fn postgres_socket_dir(network_id: &str) -> std::path::PathBuf {
    std::path::PathBuf::from(format!("/tmp/mmn-{network_id}"))
}

/// Args for running the native postgres server on `pgdata` (TCP + a short unix
/// socket dir). Used by the supervisor to run postgres as a unit.
pub fn postgres_server_args(pgdata: &str, socket_dir: &str) -> Vec<String> {
    vec![
        "-D".to_string(),
        pgdata.to_string(),
        "-p".to_string(),
        PgConfig::default().port.to_string(),
        "-k".to_string(),
        socket_dir.to_string(),
        "-c".to_string(),
        "listen_addresses=127.0.0.1".to_string(),
    ]
}
