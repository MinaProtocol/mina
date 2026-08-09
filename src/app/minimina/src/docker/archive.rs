//! Docker archive provisioning (create-time): stage the archive schema SQLs
//! into the network dir so the postgres container's `/docker-entrypoint-initdb.d`
//! applies them on first boot. Kept beside the docker plan builder so all docker
//! backend specifics live under `docker/`; `main.rs` only decides *when* to call
//! this, not *how* it works.

use crate::archive::PgConfig;
use crate::service::ServiceConfig;
use crate::utils::fetch_schema;
use std::io::Result;
use std::path::Path;

/// Docker image for the ephemeral postgres container.
pub const PG_IMAGE: &str = "postgres:16";

/// Env for the docker `postgres` image: `POSTGRES_DB` creates the database and,
/// on first boot, the entrypoint applies `/docker-entrypoint-initdb.d`. Derived
/// from the shared [`PgConfig`] so the container's credentials match the URI the
/// archive-service is given.
pub fn postgres_container_env(pg: &PgConfig) -> Vec<(String, String)> {
    vec![
        ("POSTGRES_USER".to_string(), pg.user.to_string()),
        ("POSTGRES_PASSWORD".to_string(), pg.password.to_string()),
        ("POSTGRES_DB".to_string(), pg.db.to_string()),
    ]
}

/// Stage the schema SQLs where the postgres container's
/// `/docker-entrypoint-initdb.d` picks them up — auto-applied on first boot,
/// after `POSTGRES_DB` creates the `archive` database. Number-prefixed to
/// preserve apply order (initdb.d runs its scripts alphabetically).
pub fn stage_schema(network_path: &Path, archive_node: &ServiceConfig) -> Result<()> {
    let initdb_dir = network_path.join("postgres-initdb");
    std::fs::create_dir_all(&initdb_dir)?;
    if let Some(scripts) = &archive_node.archive_schema_files {
        for (i, script) in scripts.iter().enumerate() {
            let fetched = fetch_schema(script, network_path.to_path_buf()).unwrap();
            let fname = fetched.file_name().unwrap().to_str().unwrap();
            std::fs::copy(&fetched, initdb_dir.join(format!("{:02}_{fname}", i + 1)))?;
        }
    }
    Ok(())
}
