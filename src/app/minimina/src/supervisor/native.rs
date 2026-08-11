//! Native backend: units are local child processes owned by the supervisor.

use std::io;

use log::warn;

use super::backend::Backend;
use super::plan::{BackendSpec, NativeBackendSpec, NativeNodeSpec, Readiness};
use super::run_backend;

/// The native backend owns no network-level resources — setup and teardown
/// are trivial; everything lives in per-unit launch.
pub struct NativeBackend;

/// A child's kill handle: its pid plus the signal a graceful stop should send.
///
/// The signal travels with the handle rather than being looked up from the spec
/// because [`Backend::terminate`] only ever sees the killer — by teardown time
/// the specs are behind the plan's `dyn BackendSpec` and the state map holds
/// killers alone.
#[derive(Clone)]
pub struct NativeKiller {
    pid: u32,
    stop_signal: nix::sys::signal::Signal,
}

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
    /// The child's pid plus its graceful-stop signal.
    type Killer = NativeKiller;

    async fn setup(_spec: &NativeBackendSpec, _network_id: &str) -> io::Result<Self> {
        Ok(NativeBackend)
    }

    fn nodes(spec: &NativeBackendSpec) -> &[NativeNodeSpec] {
        &spec.nodes
    }

    async fn launch(
        &self,
        node: &NativeNodeSpec,
    ) -> io::Result<(tokio::process::Child, NativeKiller, Option<u32>)> {
        let child = spawn_native(node)?;
        let pid = child.id();
        let killer = NativeKiller {
            pid: pid.unwrap_or(0),
            stop_signal: stop_signal_of(node)?,
        };
        Ok((child, killer, pid))
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

    /// Probe on the host: a TCP connect, or a command whose exit status decides.
    async fn probe(&self, _node: &NativeNodeSpec, readiness: &Readiness) -> bool {
        match readiness {
            Readiness::TcpPort(port) => tokio::net::TcpStream::connect(("127.0.0.1", *port))
                .await
                .is_ok(),
            Readiness::Command(cmd) => {
                let Some((program, args)) = cmd.split_first() else {
                    return false;
                };
                tokio::process::Command::new(program)
                    .args(args)
                    .stdout(std::process::Stdio::null())
                    .stderr(std::process::Stdio::null())
                    .status()
                    .await
                    .map(|s| s.success())
                    .unwrap_or(false)
            }
        }
    }

    async fn terminate(killer: &NativeKiller) {
        use nix::sys::signal;
        use nix::unistd::Pid;
        let _ = signal::kill(Pid::from_raw(killer.pid as i32), killer.stop_signal);
    }

    async fn force_kill(killer: &NativeKiller) {
        if process_alive(killer.pid) {
            use nix::sys::signal::{self, Signal};
            use nix::unistd::Pid;
            let _ = signal::kill(Pid::from_raw(killer.pid as i32), Signal::SIGKILL);
        }
    }

    async fn teardown(&self) {}
}

/// The unit's graceful-stop signal, defaulting to SIGTERM. Rejecting an unknown
/// number here (at launch) beats silently falling back to SIGTERM later, which
/// is exactly the wrong signal for the units that bother to ask for another one.
fn stop_signal_of(node: &NativeNodeSpec) -> io::Result<nix::sys::signal::Signal> {
    use nix::sys::signal::Signal;
    match node.stop_signal {
        None => Ok(Signal::SIGTERM),
        Some(raw) => Signal::try_from(raw).map_err(|_| {
            io::Error::other(format!(
                "unit '{}' declares an unknown stop signal {raw}",
                node.name
            ))
        }),
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

#[cfg(test)]
mod tests {
    use super::*;
    use nix::sys::signal::Signal;

    fn spec_with_signal(stop_signal: Option<i32>) -> NativeNodeSpec {
        NativeNodeSpec {
            stop_signal,
            ..NativeNodeSpec::new("unit", "/bin/true", "/dev/null".into())
        }
    }

    #[test]
    fn stop_signal_defaults_to_sigterm_and_honors_overrides() {
        assert_eq!(
            stop_signal_of(&spec_with_signal(None)).unwrap(),
            Signal::SIGTERM
        );
        assert_eq!(
            stop_signal_of(&spec_with_signal(Some(Signal::SIGINT as i32))).unwrap(),
            Signal::SIGINT
        );
    }

    /// A bad signal number is rejected at launch rather than silently becoming
    /// SIGTERM — which is the one signal the units that ask for another cannot
    /// tolerate.
    #[test]
    fn unknown_stop_signal_is_rejected() {
        let err = stop_signal_of(&spec_with_signal(Some(9999))).expect_err("must reject");
        assert!(err.to_string().contains("unknown stop signal"));
    }
}
