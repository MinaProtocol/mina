//! Native backend: units are local child processes owned by the supervisor.

use std::io;
use std::path::Path;

use log::warn;

use super::backend::Backend;
use super::plan::{BackendSpec, NativeBackendSpec, NativeNodeSpec};
use super::run_backend;
use crate::archive::PgConfig;
use crate::directory_manager::{CONFIG_DIRECTORY, NETWORK_KEYPAIRS};
use crate::genesis_ledger::REPLAYER_INPUT_JSON;

/// The native backend owns no network-level resources — setup and teardown
/// are trivial; everything lives in per-unit launch.
pub struct NativeBackend;

impl BackendSpec for NativeBackendSpec {
    fn run<'a>(
        &'a self,
        network_id: &'a str,
        socket_path: &'a std::path::Path,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = io::Result<()>> + Send + 'a>> {
        Box::pin(run_backend::<NativeBackend>(self, network_id, socket_path))
    }
}

impl Backend for NativeBackend {
    type Spec = NativeBackendSpec;
    type NodeSpec = NativeNodeSpec;
    /// The child's wait handle: exclusively owned, not cloneable — the reason
    /// the [`Backend`] trait keeps unit and kill handles separate.
    type Unit = tokio::process::Child;
    /// The child's pid.
    type Killer = u32;

    async fn setup(_spec: &NativeBackendSpec, _network_id: &str) -> io::Result<Self> {
        Ok(NativeBackend)
    }

    fn nodes(spec: &NativeBackendSpec) -> &[NativeNodeSpec] {
        &spec.nodes
    }

    async fn launch(
        &self,
        node: &NativeNodeSpec,
    ) -> io::Result<(tokio::process::Child, u32, Option<u32>)> {
        let child = spawn_native(node)?;
        let pid = child.id();
        Ok((child, pid.unwrap_or(0), pid))
    }

    async fn wait(child: &mut tokio::process::Child) -> Option<i32> {
        match child.wait().await {
            Ok(status) => status.code(),
            Err(e) => {
                warn!("supervisor: wait() failed: {e}");
                None
            }
        }
    }

    async fn terminate(pid: &u32) {
        use nix::sys::signal::{self, Signal};
        use nix::unistd::Pid;
        let _ = signal::kill(Pid::from_raw(*pid as i32), Signal::SIGTERM);
    }

    async fn force_kill(pid: &u32) {
        if process_alive(*pid) {
            use nix::sys::signal::{self, Signal};
            use nix::unistd::Pid;
            let _ = signal::kill(Pid::from_raw(*pid as i32), Signal::SIGKILL);
        }
    }

    async fn logs(&self, node: &NativeNodeSpec, tail: Option<u64>) -> io::Result<String> {
        // A not-yet-created log (node never started) is empty, not an error; any
        // other read failure (permissions, IO) is surfaced rather than hidden.
        let all = match std::fs::read_to_string(&node.log_file) {
            Ok(s) => s,
            Err(e) if e.kind() == io::ErrorKind::NotFound => String::new(),
            Err(e) => return Err(e),
        };
        Ok(tail_lines(&all, tail))
    }

    async fn import_accounts(
        &self,
        node: &NativeNodeSpec,
        network_path: &Path,
        files: &[String],
    ) -> io::Result<u64> {
        // Host-absolute paths: privkeys under the network dir, the daemon's own
        // config dir (`config-directory/<name>`), run via the node's mina binary.
        let config_dir = network_path.join(CONFIG_DIRECTORY).join(&node.name);
        let keypairs_dir = network_path.join(NETWORK_KEYPAIRS);
        let mut imported = 0;
        for file in files {
            let cmd = vec![
                node.binary.to_string_lossy().to_string(),
                "accounts".to_string(),
                "import".to_string(),
                "--privkey-path".to_string(),
                keypairs_dir.join(file).to_string_lossy().to_string(),
                "--config-directory".to_string(),
                config_dir.to_string_lossy().to_string(),
            ];
            host_exec(&cmd)
                .await
                .map_err(|e| io::Error::other(format!("import '{file}': {e}")))?;
            imported += 1;
        }
        Ok(imported)
    }

    async fn dump_archive_data(&self, _network_id: &str) -> io::Result<String> {
        let pg = PgConfig::default();
        let cmd = vec![
            "pg_dump".to_string(),
            "-h".to_string(),
            "127.0.0.1".to_string(),
            "-p".to_string(),
            pg.port.to_string(),
            "-U".to_string(),
            pg.user.to_string(),
            "--insert".to_string(),
            pg.db.to_string(),
        ];
        host_exec(&cmd)
            .await
            .map_err(|e| io::Error::other(format!("pg_dump: {e}")))
    }

    async fn run_replayer(
        &self,
        svc: &NativeNodeSpec,
        network_path: &Path,
        _network_id: &str,
    ) -> io::Result<String> {
        // `mina-replayer` sits beside the archive-service's binary.
        let bin = svc
            .binary
            .parent()
            .map(|p| p.join("mina-replayer"))
            .unwrap_or_else(|| std::path::PathBuf::from("mina-replayer"));
        let cmd = vec![
            bin.to_string_lossy().to_string(),
            "--continue-on-error".to_string(),
            "--input-file".to_string(),
            network_path
                .join(REPLAYER_INPUT_JSON)
                .to_string_lossy()
                .to_string(),
            "--archive-uri".to_string(),
            PgConfig::default().uri("127.0.0.1"),
            "--output-file".to_string(),
            "/dev/null".to_string(),
        ];
        host_exec(&cmd)
            .await
            .map_err(|e| io::Error::other(format!("replayer: {e}")))
    }

    async fn teardown(&self) {}
}

/// Run a command on the host and return its combined stdout+stderr. A nonzero
/// exit is an error (with the captured output) — never returned as if it were
/// valid output.
async fn host_exec(cmd: &[String]) -> io::Result<String> {
    let (bin, args) = cmd
        .split_first()
        .ok_or_else(|| io::Error::other("empty exec command"))?;
    let output = tokio::process::Command::new(bin)
        .args(args)
        .output()
        .await?;
    let mut s = String::from_utf8_lossy(&output.stdout).to_string();
    s.push_str(&String::from_utf8_lossy(&output.stderr));
    if !output.status.success() {
        return Err(io::Error::other(format!(
            "'{bin}' failed ({}): {}",
            output.status,
            s.trim()
        )));
    }
    Ok(s)
}

/// Keep only the last `tail` lines of `s` (all of it when `tail` is `None`).
fn tail_lines(s: &str, tail: Option<u64>) -> String {
    match tail {
        Some(n) => {
            let lines: Vec<&str> = s.lines().collect();
            let start = lines.len().saturating_sub(n as usize);
            lines[start..].join("\n")
        }
        None => s.to_string(),
    }
}

/// Spawn a native daemon as an owned child. Sets `PR_SET_PDEATHSIG(SIGKILL)` so
/// the child dies if the supervisor dies (best-effort backstop; teardown does an
/// explicit kill).
fn spawn_native(node: &NativeNodeSpec) -> io::Result<tokio::process::Child> {
    use std::os::unix::process::CommandExt;

    // Each launch starts a fresh log (this truncates any prior run's), so a
    // restart via `node_start` does not preserve the stopped unit's log and
    // `node_logs` serves the current incarnation only.
    let log = std::fs::File::create(&node.log_file)?;
    let log_err = log.try_clone()?;

    let mut cmd = std::process::Command::new(&node.binary);
    cmd.args(&node.args);
    for (k, v) in &node.env {
        cmd.env(k, v);
    }
    cmd.stdout(std::process::Stdio::from(log));
    cmd.stderr(std::process::Stdio::from(log_err));

    // SAFETY: `pre_exec` runs in the child after fork, before exec. `prctl` is
    // async-signal-safe. pdeathsig is per-thread ⇒ best-effort backstop on a
    // multi-thread runtime; explicit teardown is the real guarantee.
    unsafe {
        cmd.pre_exec(|| {
            let r = nix::libc::prctl(
                nix::libc::PR_SET_PDEATHSIG,
                nix::libc::SIGKILL as nix::libc::c_ulong,
            );
            if r != 0 {
                return Err(io::Error::last_os_error());
            }
            Ok(())
        });
    }

    let mut tokio_cmd = tokio::process::Command::from(cmd);
    tokio_cmd.kill_on_drop(true);
    tokio_cmd.spawn()
}

pub(crate) fn process_alive(pid: u32) -> bool {
    use nix::sys::signal;
    use nix::unistd::Pid;
    signal::kill(Pid::from_raw(pid as i32), None).is_ok()
}

#[cfg(test)]
mod tests {
    use super::host_exec;

    /// A nonzero exit must surface as an error, not be returned as valid output —
    /// otherwise a failed `mina accounts import` / `pg_dump` would look like a
    /// success (the corrupt-dump hazard).
    #[test]
    fn host_exec_maps_exit_status() {
        let rt = tokio::runtime::Runtime::new().unwrap();
        assert!(
            rt.block_on(host_exec(&["/bin/false".to_string()])).is_err(),
            "nonzero exit should be an error"
        );
        assert!(
            rt.block_on(host_exec(&["/bin/true".to_string()])).is_ok(),
            "zero exit should be ok"
        );
    }
}
