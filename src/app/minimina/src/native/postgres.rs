//! Native postgres: an ephemeral cluster under the network dir, run by the
//! supervisor as a `postgres` unit.
//!
//! The cluster is `initdb`'d at `network create` and provisioned there and then,
//! so `network start` only has to run `postgres` on a datadir that is already
//! correct. Provisioning needs a *running* server, which is what
//! [`ProvisionSession`] is: constructing it starts a server, dropping it stops
//! one, and in between it is a [`PostgresDb`] the archive contract can drive.
//! Nothing outside this module has to know a server was ever started.
//!
//! Requires the postgres binaries on PATH (`initdb`, `pg_ctl`, `createdb`,
//! `psql`) — but no running system postgres, and no fixed 5432: the port is
//! allocated per network so a developer's own postgres and a second minimina
//! network are both fine.

use crate::postgres::{PgConfig, PostgresDb};
use log::{info, warn};
use serde::{Deserialize, Serialize};
use std::io::{Error, Result};
use std::path::{Path, PathBuf};
use std::process::Command;

/// Data directory of the ephemeral cluster. Shared between provisioning (which
/// `initdb`s it) and the plan builder (which runs `postgres` on it).
pub fn pgdata_dir(network_path: &Path) -> PathBuf {
    network_path.join("pgdata")
}

/// Short unix-socket directory. Network dirs are often deeper than the ~107-char
/// unix-socket path limit, so the socket lives under `/tmp` (per-network); all
/// real connections use TCP on `127.0.0.1:<port>`.
pub fn socket_dir(network_id: &str) -> PathBuf {
    PathBuf::from(format!("/tmp/mmn-{network_id}"))
}

/// Remove the socket directory. It lives outside the network dir, so deleting a
/// network would otherwise leave it behind.
pub fn remove_socket_dir(network_id: &str) {
    let dir = socket_dir(network_id);
    if dir.exists() {
        if let Err(e) = std::fs::remove_dir_all(&dir) {
            warn!(
                "Failed to remove postgres socket dir '{}': {e}",
                dir.display()
            );
        }
    }
}

/// Args for running the cluster as a supervisor unit: TCP on loopback plus the
/// short socket dir.
pub fn server_args(pgdata: &Path, socket_dir: &Path, port: u16) -> Vec<String> {
    vec![
        "-D".to_string(),
        pgdata.display().to_string(),
        "-p".to_string(),
        port.to_string(),
        "-k".to_string(),
        socket_dir.display().to_string(),
        "-c".to_string(),
        "listen_addresses=127.0.0.1".to_string(),
    ]
}

// ---------------------------------------------------------------------------
// Port: chosen at create, remembered for start
// ---------------------------------------------------------------------------

/// What `network create` decided and `network start` has to honor. Persisted
/// because the two run as separate processes: re-picking a free port at start
/// would point the server and the archive-service at different places.
#[derive(Deserialize, Serialize)]
struct PgRuntime {
    port: u16,
}

fn runtime_file(network_path: &Path) -> PathBuf {
    network_path.join("postgres.json")
}

/// Claim a free loopback port for this network's cluster.
///
/// Bind-then-release, so the port is only known-free as of now; `network start`
/// re-checks availability along with every other port and fails loudly if
/// something took it in between.
fn allocate_port() -> Result<u16> {
    let listener = std::net::TcpListener::bind("127.0.0.1:0")?;
    Ok(listener.local_addr()?.port())
}

fn write_port(network_path: &Path, port: u16) -> Result<()> {
    let json = serde_json::to_string(&PgRuntime { port })?;
    std::fs::write(runtime_file(network_path), json)
}

/// The port this network's cluster was provisioned on.
pub fn read_port(network_path: &Path) -> Result<u16> {
    let path = runtime_file(network_path);
    let json = std::fs::read_to_string(&path).map_err(|e| {
        Error::other(format!(
            "cannot read postgres port from '{}': {e} \
             (was this network created with an archive node?)",
            path.display()
        ))
    })?;
    let runtime: PgRuntime = serde_json::from_str(&json)?;
    Ok(runtime.port)
}

/// The postgres config for this network — the shared defaults on its own port.
pub fn pg_config(network_path: &Path) -> Result<PgConfig> {
    Ok(PgConfig {
        port: read_port(network_path)?,
        ..Default::default()
    })
}

// ---------------------------------------------------------------------------
// Provisioning session
// ---------------------------------------------------------------------------

/// A freshly initialized cluster with a server running on it, for the duration
/// of provisioning.
///
/// The server is an implementation detail of "provision a database", so its
/// lifetime is tied to this value rather than to a pair of calls the contract
/// would have to make in the right order — and `Drop` means an error partway
/// through provisioning cannot leave a stray postgres running on the developer's
/// machine.
pub struct ProvisionSession {
    pgdata: PathBuf,
    pg: PgConfig,
}

impl ProvisionSession {
    /// `initdb` a cluster under `network_path`, remember its port, and start a
    /// server on it.
    pub fn begin(network_path: &Path, network_id: &str) -> Result<Self> {
        let pgdata = pgdata_dir(network_path);
        let port = allocate_port()?;
        let pg = PgConfig {
            port,
            ..Default::default()
        };
        let sock = socket_dir(network_id);
        std::fs::create_dir_all(&sock)?;

        info!(
            "Initializing ephemeral postgres cluster at '{}' on port {port}",
            pgdata.display()
        );
        // `--locale=C` so initdb doesn't depend on the ambient LANG/LC_* being
        // valid; `-A trust` because the cluster only ever listens on loopback.
        run_pg(
            "initdb",
            &[
                "-D",
                &pgdata.display().to_string(),
                "-U",
                pg.user,
                "-A",
                "trust",
                "--locale=C",
                "-E",
                "UTF8",
            ],
        )?;

        // Written after initdb succeeds: the file's presence means "there is a
        // cluster, and this is its port".
        write_port(network_path, port)?;

        // `-l` is not just for the log: without it the postmaster inherits our
        // stdout, and since it outlives `pg_ctl`, waiting for that pipe to close
        // never returns. Redirecting the server to a file is what makes starting
        // it safe from a non-interactive process.
        let server_log = network_path.join("postgres-provision.log");
        run_pg(
            "pg_ctl",
            &[
                "-D",
                &pgdata.display().to_string(),
                "-l",
                &server_log.display().to_string(),
                "-o",
                &format!(
                    "-p {port} -k {} -c listen_addresses=127.0.0.1",
                    sock.display()
                ),
                "-w",
                "start",
            ],
        )?;

        Ok(ProvisionSession { pgdata, pg })
    }

    /// Client args every `psql`/`createdb` invocation shares.
    fn conn_args(&self) -> Vec<String> {
        vec![
            "-h".to_string(),
            "127.0.0.1".to_string(),
            "-p".to_string(),
            self.pg.port.to_string(),
            "-U".to_string(),
            self.pg.user.to_string(),
        ]
    }
}

impl Drop for ProvisionSession {
    fn drop(&mut self) {
        // Best-effort: we are often unwinding from a provisioning failure, and
        // there is nowhere to report a second one.
        let _ = Command::new("pg_ctl")
            .args(["-D", &self.pgdata.display().to_string(), "-w", "stop"])
            .output();
    }
}

impl PostgresDb for ProvisionSession {
    fn create_database(&self, db: &str) -> Result<()> {
        let mut args = self.conn_args();
        args.push(db.to_string());
        run_pg(
            "createdb",
            &args.iter().map(String::as_str).collect::<Vec<_>>(),
        )
    }

    fn apply_sql(&self, db: &str, scripts: &[&Path]) -> Result<()> {
        for script in scripts {
            info!("Applying archive schema: {}", script.display());
            let mut args = self.conn_args();
            args.extend([
                "-d".to_string(),
                db.to_string(),
                "-v".to_string(),
                "ON_ERROR_STOP=1".to_string(),
                "-f".to_string(),
                script.display().to_string(),
            ]);
            run_pg("psql", &args.iter().map(String::as_str).collect::<Vec<_>>())?;
        }
        Ok(())
    }
}

/// Run a postgres binary and fail on a non-zero exit.
///
/// Every step here is load-bearing: a database that half-exists produces an
/// archive node that starts, accepts blocks, and drops them. Better to fail at
/// `network create`, where the message is still about the schema.
fn run_pg(program: &str, args: &[&str]) -> Result<()> {
    let out = Command::new(program).args(args).output().map_err(|e| {
        Error::other(format!(
            "failed to run '{program}' (are the postgres binaries on PATH?): {e}"
        ))
    })?;
    if !out.status.success() {
        return Err(Error::other(format!(
            "{program} failed: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        )));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn port_survives_the_round_trip_to_disk() {
        let dir = tempdir::TempDir::new("pg-port").unwrap();
        write_port(dir.path(), 54321).unwrap();
        assert_eq!(read_port(dir.path()).unwrap(), 54321);
        assert_eq!(pg_config(dir.path()).unwrap().port, 54321);
    }

    /// Starting a network whose create never provisioned postgres should say so,
    /// not surface a bare "No such file".
    #[test]
    fn missing_port_file_explains_itself() {
        let dir = tempdir::TempDir::new("pg-port-missing").unwrap();
        let err = read_port(dir.path()).expect_err("must fail");
        assert!(err.to_string().contains("archive node"), "{err}");
    }

    #[test]
    fn allocated_ports_are_free() {
        let port = allocate_port().unwrap();
        // Nothing holds it, so binding it again must work.
        std::net::TcpListener::bind(("127.0.0.1", port)).unwrap();
    }

    #[test]
    fn server_args_carry_port_and_socket_dir() {
        let args = server_args(Path::new("/net/pgdata"), Path::new("/tmp/mmn-x"), 5555);
        assert_eq!(
            args,
            vec![
                "-D",
                "/net/pgdata",
                "-p",
                "5555",
                "-k",
                "/tmp/mmn-x",
                "-c",
                "listen_addresses=127.0.0.1",
            ]
        );
    }

    /// End-to-end against real postgres binaries: initdb a cluster, create the
    /// db, apply a schema file, and confirm the table landed. `#[ignore]`d
    /// because CI has no postgres.
    /// Run manually: `cargo test native::postgres -- --ignored --nocapture`.
    #[test]
    #[ignore]
    fn provision_session_against_real_postgres() {
        let dir = tempdir::TempDir::new("pg-real").unwrap();
        let network_id = "pgtest-net";
        let schema = dir.path().join("schema.sql");
        std::fs::write(&schema, "CREATE TABLE probe (id int);\n").unwrap();

        let port = {
            let session = ProvisionSession::begin(dir.path(), network_id).unwrap();
            session.create_database("archive").unwrap();
            session.apply_sql("archive", &[schema.as_path()]).unwrap();

            // Visible while the session is alive.
            let out = Command::new("psql")
                .args([
                    "-h",
                    "127.0.0.1",
                    "-p",
                    &session.pg.port.to_string(),
                    "-U",
                    "postgres",
                    "-d",
                    "archive",
                    "-tAc",
                    "select count(*) from probe",
                ])
                .output()
                .unwrap();
            assert!(
                out.status.success(),
                "{}",
                String::from_utf8_lossy(&out.stderr)
            );
            assert_eq!(String::from_utf8_lossy(&out.stdout).trim(), "0");
            session.pg.port
        };

        // Dropping the session stopped the server.
        assert!(
            std::net::TcpStream::connect(("127.0.0.1", port)).is_err(),
            "server should be stopped once the session is dropped"
        );
        remove_socket_dir(network_id);
    }

    /// Applying a broken script must fail rather than warn: `ON_ERROR_STOP=1`
    /// plus a checked exit status.
    #[test]
    #[ignore]
    fn bad_schema_is_an_error_not_a_warning() {
        let dir = tempdir::TempDir::new("pg-real-bad").unwrap();
        let schema = dir.path().join("bad.sql");
        std::fs::write(&schema, "this is not sql;\n").unwrap();

        let session = ProvisionSession::begin(dir.path(), "pgtest-bad").unwrap();
        session.create_database("archive").unwrap();
        let err = session
            .apply_sql("archive", &[schema.as_path()])
            .expect_err("bad SQL must fail provisioning");
        assert!(err.to_string().contains("psql failed"), "{err}");
        remove_socket_dir("pgtest-bad");
    }
}
