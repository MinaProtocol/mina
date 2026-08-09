//! Native archive provisioning (create-time): stand up the ephemeral postgres
//! cluster the supervisor later runs as a `postgres` unit. Kept beside the
//! native plan builder so all native backend specifics live under `native/`;
//! `main.rs` only decides *when* to call this, not *how* it works.

use crate::archive::PgConfig;
use crate::service::ServiceConfig;
use crate::utils::fetch_schema;
use log::{info, warn};
use std::io::{Error, Result};
use std::path::{Path, PathBuf};

/// Supervisor unit name for the native postgres process.
pub const POSTGRES_UNIT_NAME: &str = "postgres";

/// Data directory of the ephemeral postgres cluster. Shared between `provision`
/// (which `initdb`s it) and the native plan builder (which runs `postgres` on
/// it), so both agree on the location.
pub fn pgdata_dir(network_path: &Path) -> PathBuf {
    network_path.join("pgdata")
}

/// Short unix-socket directory for the native postgres. Network dirs are often
/// deeper than the ~107-char unix-socket path limit, so the socket lives under
/// `/tmp` (per-network); all real connections use TCP on `127.0.0.1:<port>`.
/// Shared between `provision` (which starts postgres briefly) and the native
/// plan builder (which runs it as a unit), so both agree on the socket path.
pub fn postgres_socket_dir(network_id: &str) -> PathBuf {
    PathBuf::from(format!("/tmp/mmn-{network_id}"))
}

/// Args for running the native postgres server on `pgdata` (TCP + a short unix
/// socket dir). Used by the native plan builder to run postgres as a unit.
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

/// Initialize an ephemeral postgres cluster for native archive: `initdb` a
/// datadir under the network path, briefly start it, `createdb` + apply the
/// archive schema, then stop it. At `network start` the supervisor runs
/// `postgres` on this ready datadir. Requires the postgres client/server
/// binaries on PATH (`initdb`/`pg_ctl`/`createdb`/`psql`) — no running system
/// postgres server needed.
pub fn provision(
    network_path: &Path,
    network_id: &str,
    archive_node: &ServiceConfig,
) -> Result<()> {
    let pg = PgConfig::default();
    let pgdata = pgdata_dir(network_path);
    let pgdata_str = pgdata.to_str().unwrap();
    let port = pg.port.to_string();
    // Short unix-socket dir (network dirs can exceed the ~107-char limit).
    let socket_dir = postgres_socket_dir(network_id);
    std::fs::create_dir_all(&socket_dir)?;
    let sockdir = socket_dir.to_str().unwrap();

    info!(
        "Initializing ephemeral postgres cluster at '{}'",
        pgdata.display()
    );
    // `--locale=C` so initdb doesn't depend on the ambient LANG/LC_* being valid.
    let initdb = std::process::Command::new("initdb")
        .args([
            "-D",
            pgdata_str,
            "-U",
            pg.user,
            "-A",
            "trust",
            "--locale=C",
            "-E",
            "UTF8",
        ])
        .output()
        .map_err(|e| {
            Error::other(format!(
                "failed to run 'initdb' (is postgres on PATH?): {e}"
            ))
        })?;
    if !initdb.status.success() {
        return Err(Error::other(format!(
            "initdb failed: {}",
            String::from_utf8_lossy(&initdb.stderr)
        )));
    }

    let start = std::process::Command::new("pg_ctl")
        .args([
            "-D",
            pgdata_str,
            "-o",
            &format!("-p {port} -k {sockdir} -c listen_addresses=127.0.0.1"),
            "-w",
            "start",
        ])
        .output()?;
    if !start.status.success() {
        return Err(Error::other(format!(
            "pg_ctl start failed: {}",
            String::from_utf8_lossy(&start.stderr)
        )));
    }

    // createdb + schema against the temp server; always stop it afterwards.
    let init = init_archive_db(network_path, archive_node, &port);
    let _ = std::process::Command::new("pg_ctl")
        .args(["-D", pgdata_str, "-w", "stop"])
        .output();
    init
}

/// Create the `archive` database and apply its schema against a running
/// postgres on `127.0.0.1:<port>`.
fn init_archive_db(network_path: &Path, archive_node: &ServiceConfig, port: &str) -> Result<()> {
    let pg = PgConfig::default();
    let createdb = std::process::Command::new("createdb")
        .args(["-h", "127.0.0.1", "-p", port, "-U", pg.user, pg.db])
        .output()?;
    if !createdb.status.success() {
        warn!(
            "createdb may have failed (database might already exist): {}",
            String::from_utf8_lossy(&createdb.stderr)
        );
    }

    if let Some(scripts) = &archive_node.archive_schema_files {
        for script in scripts {
            let file_path = fetch_schema(script, network_path.to_path_buf()).unwrap();
            info!("Applying archive schema: {}", file_path.display());
            let psql = std::process::Command::new("psql")
                .args([
                    "-h",
                    "127.0.0.1",
                    "-p",
                    port,
                    "-U",
                    pg.user,
                    "-d",
                    pg.db,
                    "-v",
                    "ON_ERROR_STOP=1",
                    "-f",
                ])
                .arg(&file_path)
                .output()?;
            if !psql.status.success() {
                warn!(
                    "psql schema application may have failed: {}",
                    String::from_utf8_lossy(&psql.stderr)
                );
            }
        }
    }
    Ok(())
}
