//! Postgres as its own concern: the connection parameters both backends share,
//! and the [`PostgresDb`] seam that lets *callers* say what a database should
//! contain without knowing how this backend puts it there.
//!
//! Postgres is a database server, so this module knows about databases, users
//! and ports — and nothing about mina. Which SQL an archive node needs, and in
//! what order, is archive's business (see [`crate::archive::provision_db`]);
//! all postgres offers is "create this database" and "apply these files to it".
//!
//! The two backends implement that differently in *when*, not just how:
//! [`crate::native::postgres`] runs `createdb`/`psql` against a cluster it
//! starts for the occasion, while [`crate::docker::postgres`] stages the files
//! where the container's entrypoint applies them on first boot. Backend-internal
//! details (initdb, socket dirs, images, container env) stay in those modules.

use std::io::Result;
use std::path::Path;

/// Supervisor unit name for postgres. The docker backend suffixes it with the
/// network id like every other container; native uses it as-is.
pub const UNIT_NAME: &str = "postgres";

/// The local-only postgres configuration — one source of truth for the
/// connection parameters. Everything a consumer needs (the connection URI here,
/// the container env in [`crate::docker::postgres`], the server args in
/// [`crate::native::postgres`]) is *derived* from these fields, so a connection
/// string is never parsed back into parts.
pub struct PgConfig {
    pub user: &'static str,
    pub password: &'static str,
    pub db: &'static str,
    pub port: u16,
}

impl Default for PgConfig {
    /// The standard local-only settings. Override individual fields with struct
    /// update syntax, e.g. `PgConfig { port: allocated, ..Default::default() }`
    /// — which is how the native backend uses a per-network port.
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
    /// Connection URI for clients (e.g. the archive-service's `--postgres-uri`).
    /// `host` is wherever this postgres is reachable: `localhost` on native, the
    /// container's DNS name on docker.
    pub(crate) fn uri(&self, host: &str) -> String {
        format!(
            "postgres://{}:{}@{host}:{}/{}",
            self.user, self.password, self.port, self.db
        )
    }
}

/// A postgres a caller can provision: create a database, then put SQL in it.
///
/// Deliberately narrow. There is no `start`/`stop` here even though native
/// needs a running server and docker does not — a backend that needs a server
/// brings one up as part of constructing its impl and takes it down when the
/// impl is dropped, so the seam stays free of methods one side would have to
/// implement as nothing.
pub trait PostgresDb {
    /// Create `db`, or confirm the backend is configured to create it.
    fn create_database(&self, db: &str) -> Result<()>;

    /// Apply `scripts` to `db` in the order given.
    fn apply_sql(&self, db: &str, scripts: &[&Path]) -> Result<()>;
}
