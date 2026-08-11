//! The supervisor's input contract: pure plan data, no runtime behavior.
//!
//! Plan builders (`native::manager`, `docker::manager`) produce these types;
//! the supervisor runtime consumes them. Both sides depend on this module and
//! neither on the other — the plan is the seam between "describe a network"
//! and "run a network".

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// How the supervisor decides a unit is up before launching the next one.
///
/// A unit with no readiness is launched fire-and-forget (the historical
/// behavior); one that declares readiness blocks the launch loop until it
/// answers. Backends interpret the variants (see `Backend::probe`), but the
/// timeout and liveness policy is backend-independent.
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Readiness {
    /// Ready when a TCP connect to `127.0.0.1:<port>` succeeds. Under docker
    /// this reaches the unit only if the port is published.
    TcpPort(u16),
    /// Ready when the command exits 0 — run on the host (native) or inside the
    /// unit via `docker exec` (docker).
    Command(Vec<String>),
}

impl std::fmt::Display for Readiness {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Readiness::TcpPort(port) => write!(f, "tcp connect 127.0.0.1:{port}"),
            Readiness::Command(cmd) => write!(f, "`{}`", cmd.join(" ")),
        }
    }
}

/// A native daemon: a local process the supervisor spawns and owns.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct NativeNodeSpec {
    pub name: String,
    pub binary: PathBuf,
    pub args: Vec<String>,
    #[serde(default)]
    pub env: Vec<(String, String)>,
    pub log_file: PathBuf,
    /// Gate the rest of the launch loop on this unit coming up.
    #[serde(default)]
    pub wait_for: Option<Readiness>,
    /// Signal for a graceful stop; `None` means SIGTERM. Postgres needs SIGINT
    /// (its *fast* shutdown) because SIGTERM makes it wait for every client to
    /// disconnect first.
    #[serde(default)]
    pub stop_signal: Option<i32>,
}

impl NativeNodeSpec {
    /// A minimal process spec: everything else defaults to empty and is filled
    /// fluently, so call sites state only what is non-default.
    pub fn new(name: impl Into<String>, binary: impl Into<PathBuf>, log_file: PathBuf) -> Self {
        NativeNodeSpec {
            name: name.into(),
            binary: binary.into(),
            args: vec![],
            env: vec![],
            log_file,
            wait_for: None,
            stop_signal: None,
        }
    }

    pub fn args(mut self, args: Vec<String>) -> Self {
        self.args = args;
        self
    }

    pub fn env(mut self, env: Vec<(String, String)>) -> Self {
        self.env = env;
        self
    }

    /// Non-default by nature: only units something else depends on declare
    /// readiness, and only units that mishandle SIGTERM declare a signal — so
    /// these setters stay unused until such a unit exists.
    #[allow(dead_code)]
    pub fn wait_for(mut self, readiness: Readiness) -> Self {
        self.wait_for = Some(readiness);
        self
    }

    #[allow(dead_code)]
    pub fn stop_signal(mut self, signal: i32) -> Self {
        self.stop_signal = Some(signal);
        self
    }
}

/// A host↔container bind mount.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Mount {
    pub host: String,
    pub container: String,
    #[serde(default)]
    pub read_only: bool,
}

/// A docker daemon: a container the supervisor creates, starts, and owns.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct DockerNodeSpec {
    pub name: String,
    pub image: String,
    #[serde(default)]
    pub entrypoint: Option<Vec<String>>,
    #[serde(default)]
    pub cmd: Vec<String>,
    #[serde(default)]
    pub env: Vec<(String, String)>,
    /// (host_port, container_port) pairs to publish.
    #[serde(default)]
    pub ports: Vec<(u16, u16)>,
    #[serde(default)]
    pub mounts: Vec<Mount>,
    /// Network aliases (service-name DNS) — replaces compose service names.
    #[serde(default)]
    pub aliases: Vec<String>,
    /// Gate the rest of the launch loop on this unit coming up.
    #[serde(default)]
    pub wait_for: Option<Readiness>,
}

impl DockerNodeSpec {
    /// A minimal container spec: everything else defaults to empty and is
    /// filled fluently. The name doubles as the container's DNS alias on the
    /// docker network — that identity is what lets peers dial it by unit name.
    pub fn new(name: impl Into<String>, image: impl Into<String>) -> Self {
        let name = name.into();
        DockerNodeSpec {
            aliases: vec![name.clone()],
            name,
            image: image.into(),
            entrypoint: None,
            cmd: vec![],
            env: vec![],
            ports: vec![],
            mounts: vec![],
            wait_for: None,
        }
    }

    /// See [`NativeNodeSpec::wait_for`] on why this can sit unused.
    #[allow(dead_code)]
    pub fn wait_for(mut self, readiness: Readiness) -> Self {
        self.wait_for = Some(readiness);
        self
    }

    pub fn entrypoint(mut self, entrypoint: Vec<String>) -> Self {
        self.entrypoint = Some(entrypoint);
        self
    }

    pub fn cmd(mut self, cmd: Vec<String>) -> Self {
        self.cmd = cmd;
        self
    }

    pub fn env(mut self, env: Vec<(String, String)>) -> Self {
        self.env = env;
        self
    }

    pub fn ports(mut self, ports: Vec<(u16, u16)>) -> Self {
        self.ports = ports;
        self
    }

    pub fn mount_rw(mut self, host: impl Into<String>, container: impl Into<String>) -> Self {
        self.mounts.push(Mount {
            host: host.into(),
            container: container.into(),
            read_only: false,
        });
        self
    }

    pub fn mount_ro(mut self, host: impl Into<String>, container: impl Into<String>) -> Self {
        self.mounts.push(Mount {
            host: host.into(),
            container: container.into(),
            read_only: true,
        });
        self
    }
}

/// The native backend's share of the plan.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct NativeBackendSpec {
    pub nodes: Vec<NativeNodeSpec>,
}

/// The docker backend's share of the plan.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct DockerBackendSpec {
    /// Docker network to create + attach every container to.
    pub network_name: String,
    pub nodes: Vec<DockerNodeSpec>,
}

/// A backend's share of the plan: spec data that knows how to run itself.
///
/// The plan stores `Box<dyn BackendSpec>`, so the builder's choice of spec
/// *is* the backend choice — there is no enum to re-match downstream. Each
/// impl (runtime side) ties its spec type to its backend type and hands off
/// to the monomorphic runtime, so the signature here is the only dynamic
/// call in the supervisor.
pub trait BackendSpec: Send + Sync {
    fn run<'a>(
        &'a self,
        network_id: &'a str,
        socket_path: &'a std::path::Path,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = std::io::Result<()>> + Send + 'a>>;
}

/// Everything the supervisor needs to run a network. Held as the in-memory SSOT
/// for the process lifetime; never re-read from disk.
pub struct SupervisorPlan {
    pub network_id: String,
    pub socket_path: PathBuf,
    pub spec: Box<dyn BackendSpec>,
}

impl SupervisorPlan {
    /// Where a network's supervisor serves its RPC socket. Part of the
    /// contract: plan builders bake it into the plan and the CLI dials it.
    pub fn socket_path_in(network_path: &std::path::Path) -> PathBuf {
        network_path.join("supervisor.sock")
    }
}

/// Per-node status. `Exited` carries the reaped code so migrate-exit
/// clean-vs-crash is distinguishable downstream.
#[derive(Clone, Debug, Serialize)]
#[serde(tag = "state", rename_all = "snake_case")]
pub enum NodeStatus {
    Running { pid: Option<u32> },
    Exited { code: Option<i32> },
    Failed { error: String },
}

/// Uniform access to the backend-independent parts of a node spec — its name
/// and its readiness gate — whichever backend it belongs to. Lets the launch
/// loop stay generic while the probe itself is the backend's business.
pub trait NamedSpec {
    fn name(&self) -> &str;
    fn readiness(&self) -> Option<&Readiness>;
}

impl NamedSpec for NativeNodeSpec {
    fn name(&self) -> &str {
        &self.name
    }

    fn readiness(&self) -> Option<&Readiness> {
        self.wait_for.as_ref()
    }
}

impl NamedSpec for DockerNodeSpec {
    fn name(&self) -> &str {
        &self.name
    }

    fn readiness(&self) -> Option<&Readiness> {
        self.wait_for.as_ref()
    }
}
