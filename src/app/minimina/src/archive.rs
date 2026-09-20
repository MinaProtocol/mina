//! Shared archive **contract**: what the two plan builders must agree on so an
//! archive-node daemon can reach its archive service regardless of backend — the
//! `mina-archive` command line, the archive-service unit name (which is the
//! service's DNS host under docker), and the default server port — plus the
//! archive database's provisioning *sequence*.
//!
//! Provisioning lives here rather than in [`crate::postgres`] because which SQL
//! an archive database needs, and in what order, is a fact about mina's archive,
//! not about postgres. Postgres only supplies the mechanism
//! ([`crate::postgres::PostgresDb`]); this module decides what to ask of it, so
//! both backends provision the same database from the same steps and can only
//! differ in how those steps are carried out.
//!
//! Archive is three units: **postgres** (the ephemeral DB), **archive-service**
//! (`mina-archive run …`), and **archive-node** (a mina daemon pointed at the
//! service with `-archive-address`).

use crate::postgres::{PgConfig, PostgresDb};
use crate::service::ServiceConfig;
use crate::utils::fetch_schema;
use log::info;
use std::io::{Error, Result};
use std::path::{Path, PathBuf};

/// Default archive-service server port when the topology doesn't specify one.
pub const DEFAULT_ARCHIVE_PORT: u16 = 3086;

/// Args to `mina-archive` for the archive-service (i.e. everything after the
/// `mina-archive` program itself). `pg_host` is where the service finds
/// postgres: `localhost` (native) or the postgres container's DNS name (docker).
pub fn archive_service_args(pg: &PgConfig, pg_host: &str, archive_port: u16) -> Vec<String> {
    vec![
        "run".to_string(),
        "--postgres-uri".to_string(),
        pg.uri(pg_host),
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

/// Provision the archive database: create it, then apply the node's schema
/// scripts in the order the topology lists them.
pub fn provision_db(
    db: &impl PostgresDb,
    archive_node: &ServiceConfig,
    network_path: &Path,
) -> Result<()> {
    let scripts = fetch_archive_schema(archive_node, network_path)?;
    provision_db_from(db, &scripts)
}

/// Download the node's schema scripts into the network dir, in declared order.
/// A node with no schema files yields no scripts — an empty archive database is
/// a valid (if useless) outcome, not an error.
fn fetch_archive_schema(archive_node: &ServiceConfig, network_path: &Path) -> Result<Vec<PathBuf>> {
    let Some(urls) = &archive_node.archive_schema_files else {
        return Ok(vec![]);
    };
    urls.iter()
        .map(|url| {
            fetch_schema(url, network_path.to_path_buf())
                .map_err(|e| Error::other(format!("failed to fetch archive schema '{url}': {e}")))
        })
        .collect()
}

/// The provisioning sequence itself, over scripts already on disk.
///
/// Order is the whole point — `create_schema.sql` depends on the types
/// `zkapp_tables.sql` declares — so it is fixed here, once, for both backends
/// rather than re-established by each. Kept separate from fetching so the
/// sequence can be tested without a network or a postgres.
fn provision_db_from(db: &impl PostgresDb, scripts: &[PathBuf]) -> Result<()> {
    let pg = PgConfig::default();
    db.create_database(pg.db)?;
    if scripts.is_empty() {
        info!(
            "No archive schema files declared; leaving '{}' empty",
            pg.db
        );
        return Ok(());
    }
    let scripts: Vec<&Path> = scripts.iter().map(PathBuf::as_path).collect();
    db.apply_sql(pg.db, &scripts)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::service::ServiceType;
    use std::cell::RefCell;

    /// A [`PostgresDb`] that records what it was asked to do instead of doing
    /// it — the provisioning *sequence* is the contract worth testing, and it
    /// holds regardless of whether a real postgres is around to talk to.
    #[derive(Default)]
    struct RecordingDb {
        calls: RefCell<Vec<String>>,
    }

    impl PostgresDb for RecordingDb {
        fn create_database(&self, db: &str) -> Result<()> {
            self.calls.borrow_mut().push(format!("createdb:{db}"));
            Ok(())
        }

        fn apply_sql(&self, db: &str, scripts: &[&Path]) -> Result<()> {
            for script in scripts {
                self.calls.borrow_mut().push(format!(
                    "apply:{db}:{}",
                    script.file_name().unwrap().to_str().unwrap()
                ));
            }
            Ok(())
        }
    }

    fn archive_node_with(schema_files: Option<Vec<String>>) -> ServiceConfig {
        ServiceConfig {
            service_type: ServiceType::ArchiveNode,
            service_name: "archive".to_string(),
            archive_schema_files: schema_files,
            ..Default::default()
        }
    }

    /// The database exists before any SQL runs, and the scripts are applied in
    /// the order the topology declared — `create_schema.sql` references types
    /// `zkapp_tables.sql` creates, so a reordering here is a broken archive.
    #[test]
    fn provisioning_creates_the_db_then_applies_schema_in_order() {
        let scripts = vec![
            PathBuf::from("/tmp/zkapp_tables.sql"),
            PathBuf::from("/tmp/create_schema.sql"),
        ];
        let db = RecordingDb::default();
        provision_db_from(&db, &scripts).unwrap();

        assert_eq!(
            db.calls.into_inner(),
            vec![
                "createdb:archive",
                "apply:archive:zkapp_tables.sql",
                "apply:archive:create_schema.sql",
            ]
        );
    }

    /// A node with no schema files still gets its (empty) database, rather than
    /// failing or silently skipping the database too.
    #[test]
    fn provisioning_without_schema_files_still_creates_the_db() {
        let db = RecordingDb::default();
        provision_db_from(&db, &[]).unwrap();
        assert_eq!(db.calls.into_inner(), vec!["createdb:archive"]);
    }

    /// No schema files means no fetches — the empty case is decided before any
    /// network I/O is attempted.
    #[test]
    fn no_schema_files_means_nothing_to_fetch() {
        let dir = tempdir::TempDir::new("archive-fetch-empty").unwrap();
        let scripts = fetch_archive_schema(&archive_node_with(None), dir.path()).unwrap();
        assert!(scripts.is_empty());
    }

    /// With no `archive_port` in the topology, the archive-service's
    /// `--server-port` and the daemon's `-archive-address` must land on the
    /// same (default) port.
    #[test]
    fn daemon_and_service_agree_on_unset_archive_port() {
        let node = archive_node_with(None);
        assert_eq!(node.archive_port, None);

        let port = node.resolved_archive_port();
        assert_eq!(port, DEFAULT_ARCHIVE_PORT);

        let svc_args = archive_service_args(&PgConfig::default(), "localhost", port);
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
