//! Docker postgres: the official image, run as a container unit.
//!
//! The image provisions itself. `POSTGRES_DB` creates the database and the
//! entrypoint applies everything in `/docker-entrypoint-initdb.d` on first boot,
//! so [`InitdbStaging`] "provisions" by writing files where that will find them
//! — the work happens at `network start`, inside the container, not here.
//!
//! Ordering is preserved by number-prefixing the staged files, since the
//! entrypoint runs them alphabetically.

use crate::postgres::{PgConfig, PostgresDb, UNIT_NAME};
use log::info;
use std::io::{Error, Result};
use std::path::{Path, PathBuf};

/// Image for the ephemeral postgres container.
pub const IMAGE: &str = "postgres:16";

/// Container name / DNS host of the postgres unit for `network_id`. The plan
/// builder (alias) and anything reaching in from outside must agree, so both
/// derive it here rather than hand-formatting the string.
pub fn container_name(network_id: &str) -> String {
    format!("{UNIT_NAME}-{network_id}")
}

/// Env for the postgres image, derived from the shared [`PgConfig`] so the
/// container's credentials match the URI clients are handed.
pub fn container_env(pg: &PgConfig) -> Vec<(String, String)> {
    vec![
        ("POSTGRES_USER".to_string(), pg.user.to_string()),
        ("POSTGRES_PASSWORD".to_string(), pg.password.to_string()),
        ("POSTGRES_DB".to_string(), pg.db.to_string()),
    ]
}

/// Readiness command for the postgres unit, run inside the container.
///
/// Deliberately over TCP rather than the unix socket: the entrypoint applies
/// `initdb.d` against a socket-only server with `listen_addresses=''` and only
/// then restarts it listening on TCP. So a TCP `pg_isready` answers once the
/// schema is in place, and one gate covers both concerns; a socket probe would
/// pass while the schema was still being applied.
pub fn readiness_command(pg: &PgConfig) -> Vec<String> {
    vec![
        "pg_isready".to_string(),
        "-h".to_string(),
        "127.0.0.1".to_string(),
        "-p".to_string(),
        pg.port.to_string(),
        "-U".to_string(),
        pg.user.to_string(),
        "-d".to_string(),
        pg.db.to_string(),
    ]
}

/// Host directory staged into the container's `/docker-entrypoint-initdb.d`.
pub fn initdb_dir(network_path: &Path) -> PathBuf {
    network_path.join("postgres-initdb")
}

/// Stages SQL where the container's entrypoint will apply it on first boot.
pub struct InitdbStaging {
    dir: PathBuf,
    /// The database the plan builder configures via `POSTGRES_DB`.
    configured_db: &'static str,
}

impl InitdbStaging {
    pub fn new(network_path: &Path, pg: &PgConfig) -> Result<Self> {
        let dir = initdb_dir(network_path);
        std::fs::create_dir_all(&dir)?;
        Ok(InitdbStaging {
            dir,
            configured_db: pg.db,
        })
    }
}

impl PostgresDb for InitdbStaging {
    /// The image creates `POSTGRES_DB` itself, before it runs anything staged
    /// here, so there is no command to issue — but the two sides must be talking
    /// about the same database, or the schema would be applied to one and the
    /// archive-service would connect to the other. Checking that is the useful
    /// thing this can do.
    fn create_database(&self, db: &str) -> Result<()> {
        if db != self.configured_db {
            return Err(Error::other(format!(
                "archive wants database '{db}' but the postgres container is \
                 configured to create '{}'",
                self.configured_db
            )));
        }
        Ok(())
    }

    /// Copy the scripts in, number-prefixed: the entrypoint applies
    /// `initdb.d` in alphabetical order, so the prefix is what preserves the
    /// order the caller asked for.
    fn apply_sql(&self, db: &str, scripts: &[&Path]) -> Result<()> {
        for (i, script) in scripts.iter().enumerate() {
            let name = script.file_name().and_then(|n| n.to_str()).ok_or_else(|| {
                Error::other(format!("unusable schema path '{}'", script.display()))
            })?;
            let staged = self.dir.join(format!("{:02}_{name}", i + 1));
            std::fs::copy(script, &staged)?;
            info!(
                "Staged archive schema for '{db}': {}",
                staged.file_name().unwrap().to_str().unwrap()
            );
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write(dir: &Path, name: &str) -> PathBuf {
        let path = dir.join(name);
        std::fs::write(&path, "-- test\n").unwrap();
        path
    }

    /// The staged names must sort into the order the caller passed, since that
    /// sort *is* the apply order inside the container.
    #[test]
    fn staged_names_sort_into_the_requested_order() {
        let dir = tempdir::TempDir::new("pg-staging").unwrap();
        let first = write(dir.path(), "zkapp_tables.sql");
        let second = write(dir.path(), "create_schema.sql");

        let staging = InitdbStaging::new(dir.path(), &PgConfig::default()).unwrap();
        staging
            .apply_sql("archive", &[first.as_path(), second.as_path()])
            .unwrap();

        let mut staged: Vec<String> = std::fs::read_dir(initdb_dir(dir.path()))
            .unwrap()
            .map(|e| e.unwrap().file_name().to_str().unwrap().to_string())
            .collect();
        staged.sort();
        assert_eq!(staged, vec!["01_zkapp_tables.sql", "02_create_schema.sql"]);
    }

    /// The container creates the database from its env, so the staging impl has
    /// to agree with what the plan builder will configure.
    #[test]
    fn database_mismatch_is_rejected() {
        let dir = tempdir::TempDir::new("pg-staging-db").unwrap();
        let staging = InitdbStaging::new(dir.path(), &PgConfig::default()).unwrap();
        assert!(staging.create_database("archive").is_ok());
        let err = staging
            .create_database("somethingelse")
            .expect_err("must reject");
        assert!(err.to_string().contains("configured to create"), "{err}");
    }

    /// `POSTGRES_DB` is what creates the database the schema is applied to, so
    /// the env and the contract's database name must not drift apart.
    #[test]
    fn container_env_creates_the_contract_database() {
        let pg = PgConfig::default();
        let env = container_env(&pg);
        assert!(env.contains(&("POSTGRES_DB".to_string(), pg.db.to_string())));
        assert!(readiness_command(&pg).contains(&pg.db.to_string()));
    }

    /// The docker half, end to end: stage a schema, run the postgres unit under
    /// the supervisor, and confirm the schema is already applied by the time the
    /// readiness gate lets go — which is the whole claim the gate makes, since
    /// the archive-service launches on the strength of it.
    ///
    /// Requires a docker daemon; `#[ignore]`d because CI has none.
    /// Run manually: `cargo test docker::postgres -- --ignored --nocapture`.
    #[test]
    #[ignore]
    fn staged_schema_is_applied_before_readiness_passes() {
        use crate::supervisor::plan::{
            DockerBackendSpec, DockerNodeSpec, Readiness, SupervisorPlan,
        };
        use crate::supervisor::{rpc_call, run_blocking};

        let dir = tempdir::TempDir::new("pg-docker").unwrap();
        let network_id = "pgdocker-test";
        let container = container_name(network_id);
        let socket_path = dir.path().join("supervisor.sock");
        let pg = PgConfig::default();

        let schema = dir.path().join("probe.sql");
        std::fs::write(&schema, "CREATE TABLE probe (id int);\n").unwrap();
        let staging = InitdbStaging::new(dir.path(), &pg).unwrap();
        staging.create_database(pg.db).unwrap();
        staging.apply_sql(pg.db, &[schema.as_path()]).unwrap();

        let plan = SupervisorPlan {
            network_id: network_id.into(),
            socket_path: socket_path.clone(),
            spec: Box::new(DockerBackendSpec {
                network_name: format!("minimina-{network_id}"),
                nodes: vec![DockerNodeSpec::new(&container, IMAGE)
                    .env(container_env(&pg))
                    .mount_ro(
                        initdb_dir(dir.path()).to_str().unwrap(),
                        "/docker-entrypoint-initdb.d",
                    )
                    .wait_for(Readiness::Command(readiness_command(&pg)))],
            }),
        };

        let sup = std::thread::spawn(move || run_blocking(plan));

        // The socket is bound only after the launch loop — so after the gate.
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(120);
        while !socket_path.exists() && !sup.is_finished() && std::time::Instant::now() < deadline {
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
        if !socket_path.exists() {
            // The supervisor's own diagnosis is the useful message here, so
            // surface it rather than reporting a missing socket.
            let outcome = sup.join().unwrap();
            panic!("supervisor did not get past the readiness gate: {outcome:?}");
        }

        let out = std::process::Command::new("docker")
            .args([
                "exec",
                &container,
                "psql",
                "-U",
                pg.user,
                "-d",
                pg.db,
                "-tAc",
                "select count(*) from probe",
            ])
            .output()
            .unwrap();

        let _ = rpc_call(&socket_path, "stop", serde_json::Value::Null);
        sup.join().unwrap().unwrap();

        assert!(
            out.status.success(),
            "staged schema was not applied by the time postgres reported ready: {}",
            String::from_utf8_lossy(&out.stderr)
        );
        assert_eq!(String::from_utf8_lossy(&out.stdout).trim(), "0");
    }
}
