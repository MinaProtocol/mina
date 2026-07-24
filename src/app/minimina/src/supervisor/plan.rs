//! The supervisor's input contract: pure plan data, no runtime behavior.
//!
//! Plan builders (`native::manager`, `docker::manager`) produce these types;
//! the supervisor runtime consumes them. Both sides depend on this module and
//! neither on the other — the plan is the seam between "describe a network"
//! and "run a network".

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// A native daemon: a local process the supervisor spawns and owns.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct NativeNodeSpec {
    pub name: String,
    pub binary: PathBuf,
    pub args: Vec<String>,
    #[serde(default)]
    pub env: Vec<(String, String)>,
    pub log_file: PathBuf,
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
}

/// Which backend a network runs on and its per-node specs.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub enum BackendSpec {
    Native {
        nodes: Vec<NativeNodeSpec>,
    },
    Docker {
        /// Docker network to create + attach every container to.
        network_name: String,
        nodes: Vec<DockerNodeSpec>,
    },
}

/// Everything the supervisor needs to run a network. Held as the in-memory SSOT
/// for the process lifetime; never re-read from disk.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct SupervisorPlan {
    pub network_id: String,
    pub socket_path: PathBuf,
    pub spec: BackendSpec,
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

/// Uniform access to a node spec's name, whichever backend it belongs to.
pub trait NamedSpec {
    fn name(&self) -> &str;
}

impl NamedSpec for NativeNodeSpec {
    fn name(&self) -> &str {
        &self.name
    }
}

impl NamedSpec for DockerNodeSpec {
    fn name(&self) -> &str {
        &self.name
    }
}
