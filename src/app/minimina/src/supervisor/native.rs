//! Native backend: units are local child processes owned by the supervisor.

use std::io;

use log::warn;

use super::backend::{Backend, Killer, Unit};
use super::plan::NativeNodeSpec;

/// The native backend owns no network-level resources — setup and teardown
/// are trivial; everything lives in per-unit launch.
pub struct NativeBackend;

impl NativeBackend {
    pub fn setup() -> Self {
        NativeBackend
    }
}

/// A supervisor-owned child process.
pub struct NativeUnit(tokio::process::Child);

/// Kill handle for a native unit: its pid.
#[derive(Clone, Copy)]
pub struct NativeKiller {
    pid: u32,
}

impl Backend for NativeBackend {
    type NodeSpec = NativeNodeSpec;
    type Unit = NativeUnit;
    type Killer = NativeKiller;

    async fn launch(
        &self,
        node: &NativeNodeSpec,
    ) -> io::Result<(NativeUnit, NativeKiller, Option<u32>)> {
        let child = spawn_native(node)?;
        let pid = child.id();
        Ok((
            NativeUnit(child),
            NativeKiller {
                pid: pid.unwrap_or(0),
            },
            pid,
        ))
    }

    async fn teardown(&self) {}
}

impl Unit for NativeUnit {
    async fn wait(&mut self) -> Option<i32> {
        match self.0.wait().await {
            Ok(status) => status.code(),
            Err(e) => {
                warn!("supervisor: wait() failed: {e}");
                None
            }
        }
    }
}

impl Killer for NativeKiller {
    async fn terminate(&self) {
        use nix::sys::signal::{self, Signal};
        use nix::unistd::Pid;
        let _ = signal::kill(Pid::from_raw(self.pid as i32), Signal::SIGTERM);
    }

    async fn force_kill(&self) {
        if process_alive(self.pid) {
            use nix::sys::signal::{self, Signal};
            use nix::unistd::Pid;
            let _ = signal::kill(Pid::from_raw(self.pid as i32), Signal::SIGKILL);
        }
    }
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
