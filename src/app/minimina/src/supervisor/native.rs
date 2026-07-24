//! Native backend: units are local child processes owned by the supervisor.

use std::io;

use log::warn;

use super::backend::Backend;
use super::plan::{BackendSpec, NativeBackendSpec, NativeNodeSpec};
use super::run_backend;

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

    async fn teardown(&self) {}
}

/// Spawn a native daemon as an owned child. Sets `PR_SET_PDEATHSIG(SIGKILL)` so
/// the child dies if the supervisor dies (best-effort backstop; teardown does an
/// explicit kill).
fn spawn_native(node: &NativeNodeSpec) -> io::Result<tokio::process::Child> {
    use std::os::unix::process::CommandExt;

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
