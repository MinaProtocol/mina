//! Foreground, tokio-managed network supervisor.
//!
//! `network start` builds a tokio runtime and calls [`run_blocking`]. The
//! supervisor owns the network's **units** — native child processes *or* docker
//! containers — reaping their real exit codes, and serves a hand-rolled
//! **JSON-RPC 2.0** API over a Unix domain socket so a separate short-lived CLI
//! invocation (`status`/`stop`) can drive it while it runs in the foreground.
//!
//! A "unit" is backend-agnostic: [`RunningUnit::Native`] wraps a
//! `tokio::process::Child`; [`RunningUnit::Docker`] wraps a bollard container.
//! Both expose the same spawn / wait-reap / kill shape, which is what lets the
//! same supervisor own either backend (replacing `docker compose`).
//!
//! Scope today: no detachment (foreground); `status`/`stop` only; native path
//! wired into the CLI, docker path exercised by an `#[ignore]`d integration test
//! pending the `main.rs` docker plan builder (ticket `docker-bollard-supervisor`).
//!
//! Concurrency: one `Arc<Mutex<SupervisorState>>` (`std::sync::Mutex`, never held
//! across `.await` — copy out, drop the guard, then await). Transport:
//! newline-delimited JSON, interoperable with Go's `json.Encoder`/`json.Decoder`.

use log::{error, info, warn};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixListener;
use tokio::sync::Notify;

use bollard::container::{
    Config, CreateContainerOptions, LogsOptions, NetworkingConfig, RemoveContainerOptions,
    StopContainerOptions, WaitContainerOptions,
};
use crate::archive;
use bollard::exec::{CreateExecOptions, StartExecResults};
use bollard::image::CreateImageOptions;
use bollard::network::CreateNetworkOptions;
use bollard::secret::{EndpointSettings, HostConfig, PortBinding};
use bollard::Docker;
use futures_util::StreamExt;

// ---------------------------------------------------------------------------
// Plan (subset of the materialized plan the supervisor needs)
// ---------------------------------------------------------------------------

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
    /// Supervisor unit identity — the **bare** service name, matching the native
    /// backend so `status`/node-RPC identity is uniform across backends.
    pub name: String,
    /// Docker container name + primary DNS alias — suffixed with the network id
    /// for host-uniqueness. Internal to the docker backend; the commands' peer /
    /// archive-address hostnames resolve to this via docker DNS.
    pub container_name: String,
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

// ---------------------------------------------------------------------------
// Live state
// ---------------------------------------------------------------------------

/// Per-node status. `Exited` carries the reaped code so migrate-exit
/// clean-vs-crash is distinguishable downstream.
#[derive(Clone, Debug, Serialize)]
#[serde(tag = "state", rename_all = "snake_case")]
pub enum NodeStatus {
    Running { pid: Option<u32> },
    Exited { code: Option<i32> },
    Failed { error: String },
}

/// Per-node launch spec, retained so a stopped unit can be relaunched by name
/// (`node_start`).
enum NodeLaunch {
    Native(NativeNodeSpec),
    Docker(DockerNodeSpec),
}

/// Immutable per-run context: set up once, then only read. Shared (`Arc`) with
/// every RPC handler so node ops can reach the backend + per-node specs without
/// touching the mutable state lock.
struct SupervisorCtx {
    /// The backend (docker handle / network) used to (re)launch + exec units.
    execution: Execution,
    network_id: String,
    /// Host network directory — config dirs, keypairs, and archive data live here.
    network_path: PathBuf,
    /// Per-node launch spec, for `node_start` restart.
    launches: HashMap<String, NodeLaunch>,
}

/// Mutable live state, behind a `std::sync::Mutex` never held across `.await`.
struct SupervisorState {
    nodes: HashMap<String, NodeStatus>,
    /// Kill handles for live units, for teardown.
    killers: HashMap<String, Killer>,
    shutdown: bool,
}

impl SupervisorState {
    fn new() -> Self {
        SupervisorState {
            nodes: HashMap::new(),
            killers: HashMap::new(),
            shutdown: false,
        }
    }

    /// Snapshot for the `status` RPC (ordered by node name for stable output).
    fn snapshot(&self) -> serde_json::Value {
        let mut names: Vec<&String> = self.nodes.keys().collect();
        names.sort();
        let nodes: Vec<serde_json::Value> = names
            .into_iter()
            .map(|n| serde_json::json!({ "name": n, "status": self.nodes[n] }))
            .collect();
        serde_json::json!({ "nodes": nodes })
    }
}

// ---------------------------------------------------------------------------
// Units: the backend-agnostic runnable
// ---------------------------------------------------------------------------

/// A running unit the supervisor awaits for exit. Owned by its waiter task.
enum RunningUnit {
    Native(tokio::process::Child),
    Docker { docker: Docker, name: String },
}

impl RunningUnit {
    /// Await the unit's exit and return its exit code (`None` if unknown).
    async fn wait(&mut self) -> Option<i32> {
        match self {
            RunningUnit::Native(child) => match child.wait().await {
                Ok(status) => status.code(),
                Err(e) => {
                    warn!("supervisor: wait() failed: {e}");
                    None
                }
            },
            RunningUnit::Docker { docker, name } => {
                let mut stream =
                    docker.wait_container(name, None::<WaitContainerOptions<String>>);
                match stream.next().await {
                    Some(Ok(r)) => Some(r.status_code as i32),
                    Some(Err(e)) => {
                        warn!("supervisor: wait_container '{name}' failed: {e}");
                        None
                    }
                    None => None,
                }
            }
        }
    }
}

/// A cheap, cloneable handle to terminate a unit during teardown.
#[derive(Clone)]
enum Killer {
    Native { pid: u32 },
    Docker { docker: Docker, name: String },
}

impl Killer {
    /// Graceful stop (SIGTERM / `docker stop`).
    async fn terminate(&self) {
        match self {
            Killer::Native { pid } => {
                use nix::sys::signal::{self, Signal};
                use nix::unistd::Pid;
                let _ = signal::kill(Pid::from_raw(*pid as i32), Signal::SIGTERM);
            }
            Killer::Docker { docker, name } => {
                let _ = docker
                    .stop_container(name, Some(StopContainerOptions { t: 2 }))
                    .await;
            }
        }
    }

    /// Forceful removal (SIGKILL survivors / `docker rm -f`).
    async fn force_kill(&self) {
        match self {
            Killer::Native { pid } => {
                if process_alive(*pid) {
                    use nix::sys::signal::{self, Signal};
                    use nix::unistd::Pid;
                    let _ = signal::kill(Pid::from_raw(*pid as i32), Signal::SIGKILL);
                }
            }
            Killer::Docker { docker, name } => {
                let _ = docker
                    .remove_container(
                        name,
                        Some(RemoveContainerOptions {
                            force: true,
                            ..Default::default()
                        }),
                    )
                    .await;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Launching
// ---------------------------------------------------------------------------

/// Spawn a native daemon as an owned child. Sets `PR_SET_PDEATHSIG(SIGKILL)` so
/// the child dies if the supervisor dies (best-effort backstop; teardown does an
/// explicit kill).
fn spawn_native(node: &NativeNodeSpec) -> std::io::Result<tokio::process::Child> {
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
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }

    let mut tokio_cmd = tokio::process::Command::from(cmd);
    tokio_cmd.kill_on_drop(true);
    tokio_cmd.spawn()
}

/// Connect to the docker daemon and create the network (labelled for grouping).
async fn docker_connect_and_network(
    network_name: &str,
    network_id: &str,
) -> std::io::Result<Docker> {
    let docker = Docker::connect_with_local_defaults()
        .map_err(|e| std::io::Error::other(format!("docker connect failed: {e}")))?;
    let mut labels = HashMap::new();
    labels.insert("minimina.network".to_string(), network_id.to_string());
    // Best-effort: ignore "already exists" so re-runs don't hard-fail.
    if let Err(e) = docker
        .create_network(CreateNetworkOptions {
            name: network_name.to_string(),
            labels,
            ..Default::default()
        })
        .await
    {
        warn!("supervisor: create_network '{network_name}' (continuing): {e}");
    }
    Ok(docker)
}

/// Pull the image, create + start the container, return its running unit, kill
/// handle, and host-side pid.
async fn spawn_container(
    docker: &Docker,
    network_name: &str,
    network_id: &str,
    node: &DockerNodeSpec,
) -> std::io::Result<(RunningUnit, Killer, Option<u32>)> {
    // Pull (cached if already present).
    let mut pull = docker.create_image(
        Some(CreateImageOptions {
            from_image: node.image.clone(),
            ..Default::default()
        }),
        None,
        None,
    );
    while let Some(item) = pull.next().await {
        item.map_err(|e| std::io::Error::other(format!("pull '{}' failed: {e}", node.image)))?;
    }

    // Port bindings + exposed ports.
    let mut port_bindings = HashMap::new();
    let mut exposed = HashMap::new();
    for (host, container) in &node.ports {
        let key = format!("{container}/tcp");
        port_bindings.insert(
            key.clone(),
            Some(vec![PortBinding {
                host_ip: Some("0.0.0.0".to_string()),
                host_port: Some(host.to_string()),
            }]),
        );
        exposed.insert(key, HashMap::new());
    }

    let binds: Vec<String> = node
        .mounts
        .iter()
        .map(|m| {
            if m.read_only {
                format!("{}:{}:ro", m.host, m.container)
            } else {
                format!("{}:{}", m.host, m.container)
            }
        })
        .collect();

    let mut endpoints = HashMap::new();
    endpoints.insert(
        network_name.to_string(),
        EndpointSettings {
            aliases: Some(node.aliases.clone()),
            ..Default::default()
        },
    );

    let mut labels = HashMap::new();
    labels.insert("minimina.network".to_string(), network_id.to_string());

    let host_config = HostConfig {
        binds: if binds.is_empty() { None } else { Some(binds) },
        port_bindings: if port_bindings.is_empty() {
            None
        } else {
            Some(port_bindings)
        },
        ..Default::default()
    };

    let cname = &node.container_name;
    docker
        .create_container(
            Some(CreateContainerOptions {
                name: cname.clone(),
                platform: None,
            }),
            Config {
                image: Some(node.image.clone()),
                entrypoint: node.entrypoint.clone(),
                cmd: if node.cmd.is_empty() {
                    None
                } else {
                    Some(node.cmd.clone())
                },
                env: Some(node.env.iter().map(|(k, v)| format!("{k}={v}")).collect()),
                exposed_ports: if exposed.is_empty() {
                    None
                } else {
                    Some(exposed)
                },
                labels: Some(labels),
                host_config: Some(host_config),
                networking_config: Some(NetworkingConfig {
                    endpoints_config: endpoints,
                }),
                ..Default::default()
            },
        )
        .await
        .map_err(|e| std::io::Error::other(format!("create_container '{cname}' failed: {e}")))?;

    docker
        .start_container(cname, None::<bollard::container::StartContainerOptions<String>>)
        .await
        .map_err(|e| std::io::Error::other(format!("start_container '{cname}' failed: {e}")))?;

    let pid = docker
        .inspect_container(cname, None)
        .await
        .ok()
        .and_then(|i| i.state)
        .and_then(|s| s.pid)
        .map(|p| p as u32);

    Ok((
        RunningUnit::Docker {
            docker: docker.clone(),
            name: cname.clone(),
        },
        Killer::Docker {
            docker: docker.clone(),
            name: cname.clone(),
        },
        pid,
    ))
}

// ---------------------------------------------------------------------------
// Execution: the backend, owning any network-level resources
// ---------------------------------------------------------------------------

/// The backend a network runs on. It owns network-*level* resources (docker: the
/// docker network + DNS) and knows how to launch its own units. Its unit
/// representation (`RunningUnit`/`Killer`) is an internal detail — native and
/// docker units are NOT mix-and-match across executions, so the backend is a
/// single axis, not a `Unit`×`Execution` matrix.
enum Execution {
    Native,
    Docker { docker: Docker, network_name: String },
}

impl Execution {
    /// Acquire network-level resources (docker: connect + create the network).
    async fn setup(spec: &BackendSpec, network_id: &str) -> std::io::Result<Execution> {
        match spec {
            BackendSpec::Native { .. } => Ok(Execution::Native),
            BackendSpec::Docker { network_name, .. } => {
                let docker = docker_connect_and_network(network_name, network_id).await?;
                Ok(Execution::Docker {
                    docker,
                    network_name: network_name.clone(),
                })
            }
        }
    }

    /// Launch a native daemon as an owned child.
    fn launch_native(
        &self,
        node: &NativeNodeSpec,
    ) -> std::io::Result<(RunningUnit, Killer, Option<u32>)> {
        let child = spawn_native(node)?;
        let pid = child.id();
        Ok((
            RunningUnit::Native(child),
            Killer::Native {
                pid: pid.unwrap_or(0),
            },
            pid,
        ))
    }

    /// Launch a docker daemon as an owned container on this execution's network.
    async fn launch_docker(
        &self,
        node: &DockerNodeSpec,
        network_id: &str,
    ) -> std::io::Result<(RunningUnit, Killer, Option<u32>)> {
        match self {
            Execution::Docker {
                docker,
                network_name,
            } => spawn_container(docker, network_name, network_id, node).await,
            Execution::Native => Err(std::io::Error::other(
                "launch_docker called on a native execution",
            )),
        }
    }

    /// Release network-level resources (docker: remove the network). Units are
    /// torn down separately (see `stop_units`).
    async fn teardown(&self) {
        if let Execution::Docker {
            docker,
            network_name,
        } = self
        {
            if let Err(e) = docker.remove_network(network_name).await {
                warn!("supervisor: remove_network '{network_name}': {e}");
            }
        }
    }

    /// Stream a container's logs (docker only). `tail` limits to the last N lines.
    async fn container_logs(
        &self,
        container: &str,
        tail: Option<u64>,
    ) -> std::io::Result<String> {
        match self {
            Execution::Docker { docker, .. } => {
                let opts = LogsOptions::<String> {
                    stdout: true,
                    stderr: true,
                    tail: tail.map(|t| t.to_string()).unwrap_or_else(|| "all".to_string()),
                    ..Default::default()
                };
                let mut stream = docker.logs(container, Some(opts));
                let mut out = String::new();
                while let Some(item) = stream.next().await {
                    match item {
                        Ok(chunk) => out.push_str(&String::from_utf8_lossy(&chunk.into_bytes())),
                        Err(e) => return Err(std::io::Error::other(e)),
                    }
                }
                Ok(out)
            }
            Execution::Native => Err(std::io::Error::other(
                "container_logs called on native execution",
            )),
        }
    }

    /// Run a command "inside" a unit and return its combined stdout+stderr.
    /// Docker: `exec` into `container`. Native: run the command on the host
    /// (a native unit has no container, so the caller passes a full host command
    /// and `container` is ignored).
    async fn exec(&self, container: &str, cmd: &[String]) -> std::io::Result<String> {
        match self {
            Execution::Docker { docker, .. } => {
                let exec = docker
                    .create_exec(
                        container,
                        CreateExecOptions {
                            cmd: Some(cmd.iter().map(|s| s.as_str()).collect()),
                            attach_stdout: Some(true),
                            attach_stderr: Some(true),
                            ..Default::default()
                        },
                    )
                    .await
                    .map_err(|e| std::io::Error::other(format!("create_exec '{container}': {e}")))?;
                let mut out = String::new();
                if let StartExecResults::Attached { mut output, .. } = docker
                    .start_exec(&exec.id, None)
                    .await
                    .map_err(|e| std::io::Error::other(format!("start_exec '{container}': {e}")))?
                {
                    while let Some(item) = output.next().await {
                        if let Ok(chunk) = item {
                            out.push_str(&String::from_utf8_lossy(&chunk.into_bytes()));
                        }
                    }
                }
                Ok(out)
            }
            Execution::Native => {
                let (bin, args) = cmd
                    .split_first()
                    .ok_or_else(|| std::io::Error::other("empty exec command"))?;
                let output = tokio::process::Command::new(bin).args(args).output().await?;
                let mut s = String::from_utf8_lossy(&output.stdout).to_string();
                s.push_str(&String::from_utf8_lossy(&output.stderr));
                Ok(s)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// JSON-RPC 2.0 envelope (hand-rolled)
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct RpcRequest {
    #[allow(dead_code)]
    jsonrpc: Option<String>,
    #[serde(default)]
    id: serde_json::Value,
    method: String,
    #[serde(default)]
    params: serde_json::Value,
}

#[derive(Serialize)]
struct RpcResponse {
    jsonrpc: &'static str,
    id: serde_json::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<RpcError>,
}

#[derive(Serialize)]
struct RpcError {
    code: i64,
    message: String,
}

impl RpcResponse {
    fn ok(id: serde_json::Value, result: serde_json::Value) -> Self {
        RpcResponse {
            jsonrpc: "2.0",
            id,
            result: Some(result),
            error: None,
        }
    }
    fn err(id: serde_json::Value, code: i64, message: String) -> Self {
        RpcResponse {
            jsonrpc: "2.0",
            id,
            result: None,
            error: Some(RpcError { code, message }),
        }
    }
}

const METHOD_NOT_FOUND: i64 = -32601;

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Build a tokio runtime and run the supervisor to completion (blocking).
/// Returns when the network is torn down (via `stop` RPC or SIGINT).
pub fn run_blocking(plan: SupervisorPlan) -> std::io::Result<()> {
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;
    rt.block_on(run(plan))
}

async fn run(plan: SupervisorPlan) -> std::io::Result<()> {
    // Acquire the backend + any network-level resources.
    let execution = Execution::setup(&plan.spec, &plan.network_id).await?;

    // Retain each node's launch spec (for `node_start`) and remember the launch
    // order (the one match here is on the spec *data* — native and docker node
    // specs differ — not a leaky abstraction).
    let mut launches: HashMap<String, NodeLaunch> = HashMap::new();
    let ordered: Vec<String> = match &plan.spec {
        BackendSpec::Native { nodes } => nodes
            .iter()
            .map(|n| {
                launches.insert(n.name.clone(), NodeLaunch::Native(n.clone()));
                n.name.clone()
            })
            .collect(),
        BackendSpec::Docker { nodes, .. } => nodes
            .iter()
            .map(|n| {
                launches.insert(n.name.clone(), NodeLaunch::Docker(n.clone()));
                n.name.clone()
            })
            .collect(),
    };

    let ctx = Arc::new(SupervisorCtx {
        execution,
        network_id: plan.network_id.clone(),
        // Network dir is the socket's parent (`<net>/supervisor.sock`).
        network_path: plan
            .socket_path
            .parent()
            .map(|p| p.to_path_buf())
            .unwrap_or_default(),
        launches,
    });
    let state = Arc::new(Mutex::new(SupervisorState::new()));
    let shutdown = Arc::new(Notify::new());

    // Launch every unit in order (each with a waiter task that reaps its exit).
    for name in &ordered {
        if let Some(launch) = ctx.launches.get(name) {
            launch_and_register(&ctx, &state, name, launch).await;
        }
    }

    // Bind the RPC socket (unlink any stale socket first).
    let _ = std::fs::remove_file(&plan.socket_path);
    let listener = UnixListener::bind(&plan.socket_path)?;
    info!("supervisor: serving RPC on '{}'", plan.socket_path.display());

    let accept_ctx = ctx.clone();
    let accept_state = state.clone();
    let accept_shutdown = shutdown.clone();
    let accept_task = tokio::spawn(async move {
        loop {
            match listener.accept().await {
                Ok((stream, _addr)) => {
                    tokio::spawn(handle_connection(
                        stream,
                        accept_ctx.clone(),
                        accept_state.clone(),
                        accept_shutdown.clone(),
                    ));
                }
                Err(e) => {
                    warn!("supervisor: accept error: {e}");
                    break;
                }
            }
        }
    });

    tokio::select! {
        _ = shutdown.notified() => info!("supervisor: stop requested"),
        r = tokio::signal::ctrl_c() => match r {
            Ok(()) => info!("supervisor: SIGINT received"),
            Err(e) => warn!("supervisor: signal error: {e}"),
        },
    }

    accept_task.abort();
    stop_units(&state).await;
    ctx.execution.teardown().await;
    let _ = std::fs::remove_file(&plan.socket_path);
    info!("supervisor: network '{}' stopped", plan.network_id);
    Ok(())
}

/// Record a launched unit in state and spawn its waiter task.
fn register_unit(
    state: &Arc<Mutex<SupervisorState>>,
    name: &str,
    pid: Option<u32>,
    mut unit: RunningUnit,
    killer: Killer,
) {
    info!("supervisor: started '{name}' (pid {pid:?})");
    {
        let mut st = state.lock().unwrap();
        st.nodes.insert(name.to_string(), NodeStatus::Running { pid });
        st.killers.insert(name.to_string(), killer);
    }
    let st = state.clone();
    let name = name.to_string();
    tokio::spawn(async move {
        let code = unit.wait().await;
        info!("supervisor: '{name}' exited (code {code:?})");
        let mut guard = st.lock().unwrap();
        guard.nodes.insert(name.clone(), NodeStatus::Exited { code });
        guard.killers.remove(&name);
    });
}

fn fail_unit(state: &Arc<Mutex<SupervisorState>>, name: &str, error: String) {
    error!("supervisor: failed to start '{name}': {error}");
    state
        .lock()
        .unwrap()
        .nodes
        .insert(name.to_string(), NodeStatus::Failed { error });
}

/// Handle one client connection: newline-delimited JSON-RPC request/response.
async fn handle_connection(
    stream: tokio::net::UnixStream,
    ctx: Arc<SupervisorCtx>,
    state: Arc<Mutex<SupervisorState>>,
    shutdown: Arc<Notify>,
) {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();
    loop {
        let line = match lines.next_line().await {
            Ok(Some(l)) => l,
            Ok(None) => break,
            Err(e) => {
                warn!("supervisor: read error: {e}");
                break;
            }
        };
        if line.trim().is_empty() {
            continue;
        }

        let response = match serde_json::from_str::<RpcRequest>(&line) {
            Ok(req) => dispatch(req, &ctx, &state, &shutdown).await,
            Err(e) => RpcResponse::err(
                serde_json::Value::Null,
                -32700,
                format!("invalid request: {e}"),
            ),
        };

        let mut buf = match serde_json::to_vec(&response) {
            Ok(b) => b,
            Err(e) => {
                error!("supervisor: failed to serialize response: {e}");
                break;
            }
        };
        buf.push(b'\n');
        if let Err(e) = writer.write_all(&buf).await {
            warn!("supervisor: write error: {e}");
            break;
        }
    }
}

const INVALID_PARAMS: i64 = -32602;
const NODE_ERROR: i64 = -32000;

/// Extract a required string `name` param.
fn param_name(params: &serde_json::Value) -> Result<String, RpcError> {
    params
        .get("name")
        .and_then(|v| v.as_str())
        .map(str::to_string)
        .ok_or_else(|| RpcError {
            code: INVALID_PARAMS,
            message: "missing 'name' string param".to_string(),
        })
}

/// Dispatch a single request. State-mutating helpers keep the `std::sync::Mutex`
/// for only the moment they touch it, never across an `.await`.
async fn dispatch(
    req: RpcRequest,
    ctx: &Arc<SupervisorCtx>,
    state: &Arc<Mutex<SupervisorState>>,
    shutdown: &Arc<Notify>,
) -> RpcResponse {
    let id = req.id.clone();
    let result: Result<serde_json::Value, RpcError> = match req.method.as_str() {
        "status" => Ok(state.lock().unwrap().snapshot()),
        "stop" => {
            state.lock().unwrap().shutdown = true;
            shutdown.notify_one();
            Ok(serde_json::json!({ "stopping": true }))
        }
        "node_start" => match param_name(&req.params) {
            Ok(name) => {
                let fresh = req
                    .params
                    .get("fresh_state")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);
                node_start(ctx, state, &name, fresh).await
            }
            Err(e) => Err(e),
        },
        "node_stop" => match param_name(&req.params) {
            Ok(name) => node_stop(state, &name).await,
            Err(e) => Err(e),
        },
        "node_logs" => match param_name(&req.params) {
            Ok(name) => {
                let tail = req.params.get("tail").and_then(|v| v.as_u64());
                node_logs(ctx, &name, tail).await
            }
            Err(e) => Err(e),
        },
        "node_dump_precomputed" => match param_name(&req.params) {
            Ok(name) => node_dump_precomputed(ctx, &name),
            Err(e) => Err(e),
        },
        "node_import_accounts" => match param_name(&req.params) {
            Ok(name) => node_import_accounts(ctx, &name).await,
            Err(e) => Err(e),
        },
        "dump_archive_data" => dump_archive_data(ctx).await,
        "run_replayer" => match param_name(&req.params) {
            Ok(name) => run_replayer(ctx, &name).await,
            Err(e) => Err(e),
        },
        other => Err(RpcError {
            code: METHOD_NOT_FOUND,
            message: format!("unknown method '{other}'"),
        }),
    };
    match result {
        Ok(v) => RpcResponse::ok(id, v),
        Err(e) => RpcResponse::err(id, e.code, e.message),
    }
}

/// Host config directory for a unit (`<net>/config-directory/<name>`) — same path
/// on both backends (docker bind-mounts it into the container at
/// `/config-directory`).
fn config_dir(ctx: &SupervisorCtx, name: &str) -> PathBuf {
    ctx.network_path.join("config-directory").join(name)
}

/// (Re)start a single node from its retained launch spec. With `fresh_state`, the
/// unit's config directory is wiped first (a clean restart).
async fn node_start(
    ctx: &Arc<SupervisorCtx>,
    state: &Arc<Mutex<SupervisorState>>,
    name: &str,
    fresh_state: bool,
) -> Result<serde_json::Value, RpcError> {
    let already = matches!(
        state.lock().unwrap().nodes.get(name),
        Some(NodeStatus::Running { .. })
    );
    if already {
        return Err(RpcError {
            code: NODE_ERROR,
            message: format!("node '{name}' is already running"),
        });
    }
    match ctx.launches.get(name) {
        Some(launch) => {
            if fresh_state {
                let dir = config_dir(ctx, name);
                let _ = std::fs::remove_dir_all(&dir);
                if let Err(e) = std::fs::create_dir_all(&dir) {
                    return Err(RpcError {
                        code: NODE_ERROR,
                        message: format!("failed to reset config dir '{}': {e}", dir.display()),
                    });
                }
            }
            launch_and_register(ctx, state, name, launch).await;
            Ok(serde_json::json!({ "started": name }))
        }
        None => Err(RpcError {
            code: NODE_ERROR,
            message: format!("unknown node '{name}'"),
        }),
    }
}

/// Dump a node's precomputed-blocks log (`<config-dir>/precomputed_blocks.log`),
/// which is on the host for both backends (docker bind-mounts the config dir).
fn node_dump_precomputed(
    ctx: &Arc<SupervisorCtx>,
    name: &str,
) -> Result<serde_json::Value, RpcError> {
    let path = config_dir(ctx, name).join("precomputed_blocks.log");
    match std::fs::read_to_string(&path) {
        Ok(blocks) => Ok(serde_json::json!({ "precomputed_blocks": blocks })),
        Err(e) => Err(RpcError {
            code: NODE_ERROR,
            message: format!("cannot read '{}': {e}", path.display()),
        }),
    }
}

/// Stop a single node (graceful → force). Its waiter task records the exit.
async fn node_stop(
    state: &Arc<Mutex<SupervisorState>>,
    name: &str,
) -> Result<serde_json::Value, RpcError> {
    let killer = state.lock().unwrap().killers.remove(name);
    match killer {
        Some(k) => {
            k.terminate().await;
            tokio::time::sleep(std::time::Duration::from_secs(2)).await;
            k.force_kill().await;
            Ok(serde_json::json!({ "stopped": name }))
        }
        None => Err(RpcError {
            code: NODE_ERROR,
            message: format!("node '{name}' is not running"),
        }),
    }
}

/// Fetch a node's logs — native: read its log file; docker: stream container logs.
async fn node_logs(
    ctx: &Arc<SupervisorCtx>,
    name: &str,
    tail: Option<u64>,
) -> Result<serde_json::Value, RpcError> {
    let logs = match ctx.launches.get(name) {
        Some(NodeLaunch::Native(spec)) => {
            let all = std::fs::read_to_string(&spec.log_file).unwrap_or_default();
            tail_lines(&all, tail)
        }
        Some(NodeLaunch::Docker(spec)) => ctx
            .execution
            .container_logs(&spec.container_name, tail)
            .await
            .map_err(|e| RpcError {
                code: NODE_ERROR,
                message: e.to_string(),
            })?,
        None => {
            return Err(RpcError {
                code: NODE_ERROR,
                message: format!("unknown node '{name}'"),
            })
        }
    };
    Ok(serde_json::json!({ "logs": logs }))
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

/// Import every keypair into a node's wallet via `mina accounts import` (offline,
/// against the node's config dir). Docker: `exec` into the container; native: run
/// the node's `mina` binary on the host.
async fn node_import_accounts(
    ctx: &Arc<SupervisorCtx>,
    name: &str,
) -> Result<serde_json::Value, RpcError> {
    let Some(launch) = ctx.launches.get(name) else {
        return Err(RpcError {
            code: NODE_ERROR,
            message: format!("unknown node '{name}'"),
        });
    };
    // privkey files under network-keypairs (host), excluding the `.pub` pubkeys.
    let keypairs_dir = ctx.network_path.join("network-keypairs");
    let mut files: Vec<String> = Vec::new();
    if let Ok(rd) = std::fs::read_dir(&keypairs_dir) {
        for entry in rd.flatten() {
            if let Some(f) = entry.file_name().to_str() {
                if entry.path().is_file() && !f.contains(".pub") {
                    files.push(f.to_string());
                }
            }
        }
    }
    let mut imported = 0;
    for file in &files {
        let (container, cmd) = match launch {
            NodeLaunch::Docker(spec) => (
                spec.container_name.clone(),
                vec![
                    "mina".into(),
                    "accounts".into(),
                    "import".into(),
                    "--privkey-path".into(),
                    format!("/local-network/network-keypairs/{file}"),
                    "--config-directory".into(),
                    "/config-directory".into(),
                ],
            ),
            NodeLaunch::Native(spec) => (
                name.to_string(),
                vec![
                    spec.binary.to_string_lossy().to_string(),
                    "accounts".into(),
                    "import".into(),
                    "--privkey-path".into(),
                    keypairs_dir.join(file).to_string_lossy().to_string(),
                    "--config-directory".into(),
                    config_dir(ctx, name).to_string_lossy().to_string(),
                ],
            ),
        };
        ctx.execution.exec(&container, &cmd).await.map_err(|e| RpcError {
            code: NODE_ERROR,
            message: format!("import '{file}': {e}"),
        })?;
        imported += 1;
    }
    Ok(serde_json::json!({ "imported": imported }))
}

/// `pg_dump` the archive database. Docker: `exec` into the postgres container;
/// native: run `pg_dump` on the host against `127.0.0.1`.
async fn dump_archive_data(ctx: &Arc<SupervisorCtx>) -> Result<serde_json::Value, RpcError> {
    let pg = archive::PgConfig::default();
    let (container, cmd) = match &ctx.execution {
        Execution::Docker { .. } => (
            format!("postgres-{}", ctx.network_id),
            vec![
                "pg_dump".into(),
                "--insert".into(),
                "-U".into(),
                pg.user.to_string(),
                pg.db.to_string(),
            ],
        ),
        Execution::Native => (
            String::new(),
            vec![
                "pg_dump".into(),
                "-h".into(),
                "127.0.0.1".into(),
                "-p".into(),
                pg.port.to_string(),
                "-U".into(),
                pg.user.to_string(),
                "--insert".into(),
                pg.db.to_string(),
            ],
        ),
    };
    let data = ctx.execution.exec(&container, &cmd).await.map_err(|e| RpcError {
        code: NODE_ERROR,
        message: format!("pg_dump: {e}"),
    })?;
    Ok(serde_json::json!({ "archive_data": data }))
}

/// Run the replayer against the archive DB (the caller sets the start slot in
/// `replayer_input.json` first). Docker: `exec` `mina-replayer` in the archive-
/// service container; native: run the co-located `mina-replayer` on the host.
async fn run_replayer(
    ctx: &Arc<SupervisorCtx>,
    name: &str,
) -> Result<serde_json::Value, RpcError> {
    let svc = archive::archive_service_unit_name(name);
    let Some(launch) = ctx.launches.get(&svc) else {
        return Err(RpcError {
            code: NODE_ERROR,
            message: format!("no archive-service for node '{name}'"),
        });
    };
    let (container, cmd) = match launch {
        NodeLaunch::Docker(spec) => (
            spec.container_name.clone(),
            vec![
                "mina-replayer".into(),
                "--continue-on-error".into(),
                "--input-file".into(),
                "/local-network/replayer_input.json".into(),
                "--archive-uri".into(),
                archive::PgConfig::default().uri(&format!("postgres-{}", ctx.network_id)),
                "--output-file".into(),
                "/dev/null".into(),
            ],
        ),
        NodeLaunch::Native(spec) => {
            let bin = spec
                .binary
                .parent()
                .map(|p| p.join("mina-replayer"))
                .unwrap_or_else(|| PathBuf::from("mina-replayer"));
            (
                name.to_string(),
                vec![
                    bin.to_string_lossy().to_string(),
                    "--continue-on-error".into(),
                    "--input-file".into(),
                    ctx.network_path
                        .join("replayer_input.json")
                        .to_string_lossy()
                        .to_string(),
                    "--archive-uri".into(),
                    archive::PgConfig::default().uri("127.0.0.1"),
                    "--output-file".into(),
                    "/dev/null".into(),
                ],
            )
        }
    };
    let logs = ctx.execution.exec(&container, &cmd).await.map_err(|e| RpcError {
        code: NODE_ERROR,
        message: format!("replayer: {e}"),
    })?;
    Ok(serde_json::json!({ "replayer_logs": logs }))
}

/// Launch one node (native or docker) and register it + its waiter task. Shared
/// by startup and `node_start`.
async fn launch_and_register(
    ctx: &Arc<SupervisorCtx>,
    state: &Arc<Mutex<SupervisorState>>,
    name: &str,
    launch: &NodeLaunch,
) {
    let result = match launch {
        NodeLaunch::Native(spec) => ctx.execution.launch_native(spec),
        NodeLaunch::Docker(spec) => ctx.execution.launch_docker(spec, &ctx.network_id).await,
    };
    match result {
        Ok((unit, killer, pid)) => register_unit(state, name, pid, unit, killer),
        Err(e) => fail_unit(state, name, e.to_string()),
    }
}

/// Terminate every live unit (graceful → force). Network-level teardown is the
/// execution's job (see `Execution::teardown`).
async fn stop_units(state: &Arc<Mutex<SupervisorState>>) {
    let killers: Vec<Killer> = {
        let st = state.lock().unwrap();
        st.killers.values().cloned().collect()
    };
    for k in &killers {
        k.terminate().await;
    }
    if !killers.is_empty() {
        tokio::time::sleep(std::time::Duration::from_secs(2)).await;
        for k in &killers {
            k.force_kill().await;
        }
    }
}

fn process_alive(pid: u32) -> bool {
    use nix::sys::signal;
    use nix::unistd::Pid;
    signal::kill(Pid::from_raw(pid as i32), None).is_ok()
}

// ---------------------------------------------------------------------------
// Blocking client (used by the CLI's `status`/`stop` as thin RPC clients)
// ---------------------------------------------------------------------------

/// Send one JSON-RPC request over the socket and return the `result` value.
/// Blocking + synchronous — usable from the otherwise non-async CLI.
pub fn rpc_call(
    socket_path: &Path,
    method: &str,
    params: serde_json::Value,
) -> std::io::Result<serde_json::Value> {
    use std::io::{BufRead, BufReader as StdBufReader, Write};
    use std::os::unix::net::UnixStream as StdUnixStream;

    let mut stream = StdUnixStream::connect(socket_path)?;
    let req = serde_json::json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params,
    });
    let mut line = serde_json::to_vec(&req)?;
    line.push(b'\n');
    stream.write_all(&line)?;
    stream.flush()?;

    let mut reader = StdBufReader::new(stream);
    let mut resp_line = String::new();
    reader.read_line(&mut resp_line)?;

    let resp: serde_json::Value = serde_json::from_str(resp_line.trim())?;
    if let Some(err) = resp.get("error") {
        if !err.is_null() {
            return Err(std::io::Error::other(format!("rpc error: {err}")));
        }
    }
    Ok(resp.get("result").cloned().unwrap_or(serde_json::Value::Null))
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    /// End-to-end native: launch a real child, query `status`, then `stop`, and
    /// confirm the child is reaped and the socket is cleaned up.
    #[test]
    fn supervise_status_stop_reaps_child() {
        let dir = tempdir::TempDir::new("supervisor-test").unwrap();
        let socket_path = dir.path().join("supervisor.sock");
        let log_file = dir.path().join("sleeper.log");

        let plan = SupervisorPlan {
            network_id: "test-net".into(),
            socket_path: socket_path.clone(),
            spec: BackendSpec::Native {
                nodes: vec![NativeNodeSpec {
                    name: "sleeper".into(),
                    binary: "/bin/sleep".into(),
                    args: vec!["300".into()],
                    env: vec![],
                    log_file,
                }],
            },
        };

        let sup = std::thread::spawn(move || run_blocking(plan).unwrap());

        let mut waited = 0;
        while !socket_path.exists() && waited < 100 {
            std::thread::sleep(std::time::Duration::from_millis(50));
            waited += 1;
        }
        assert!(socket_path.exists(), "socket never appeared");

        let status = rpc_call(&socket_path, "status", serde_json::Value::Null).unwrap();
        let nodes = status["nodes"].as_array().unwrap();
        assert_eq!(nodes.len(), 1);
        assert_eq!(nodes[0]["name"], "sleeper");
        assert_eq!(nodes[0]["status"]["state"], "running");
        let pid = nodes[0]["status"]["pid"].as_u64().unwrap() as u32;
        assert!(process_alive(pid), "sleeper should be alive");

        let stop = rpc_call(&socket_path, "stop", serde_json::Value::Null).unwrap();
        assert_eq!(stop["stopping"], true);

        sup.join().unwrap();

        assert!(!process_alive(pid), "sleeper should have been killed");
        assert!(!socket_path.exists(), "socket should be removed");
    }

    /// node_stop then node_start a live unit: it dies, then relaunches with a new
    /// pid — the restart path the hardfork orchestrator drives.
    #[test]
    fn supervise_node_stop_then_start() {
        let dir = tempdir::TempDir::new("supervisor-node-test").unwrap();
        let socket_path = dir.path().join("supervisor.sock");
        let plan = SupervisorPlan {
            network_id: "test-net".into(),
            socket_path: socket_path.clone(),
            spec: BackendSpec::Native {
                nodes: vec![NativeNodeSpec {
                    name: "sleeper".into(),
                    binary: "/bin/sleep".into(),
                    args: vec!["300".into()],
                    env: vec![],
                    log_file: dir.path().join("sleeper.log"),
                }],
            },
        };
        let sup = std::thread::spawn(move || run_blocking(plan).unwrap());

        let mut waited = 0;
        while !socket_path.exists() && waited < 100 {
            std::thread::sleep(std::time::Duration::from_millis(50));
            waited += 1;
        }
        assert!(socket_path.exists());

        let name = serde_json::json!({ "name": "sleeper" });
        let st = rpc_call(&socket_path, "status", serde_json::Value::Null).unwrap();
        let pid1 = st["nodes"][0]["status"]["pid"].as_u64().unwrap() as u32;

        // node_stop: SIGTERM the unit; it dies and the waiter records `exited`.
        assert_eq!(
            rpc_call(&socket_path, "node_stop", name.clone()).unwrap()["stopped"],
            "sleeper"
        );
        std::thread::sleep(std::time::Duration::from_millis(300));
        assert!(!process_alive(pid1));
        let st = rpc_call(&socket_path, "status", serde_json::Value::Null).unwrap();
        assert_eq!(st["nodes"][0]["status"]["state"], "exited");

        // node_start: relaunch → running with a fresh pid.
        assert_eq!(
            rpc_call(&socket_path, "node_start", name.clone()).unwrap()["started"],
            "sleeper"
        );
        std::thread::sleep(std::time::Duration::from_millis(200));
        let st = rpc_call(&socket_path, "status", serde_json::Value::Null).unwrap();
        assert_eq!(st["nodes"][0]["status"]["state"], "running");
        let pid2 = st["nodes"][0]["status"]["pid"].as_u64().unwrap() as u32;
        assert_ne!(pid1, pid2);
        assert!(process_alive(pid2));

        rpc_call(&socket_path, "stop", serde_json::Value::Null).unwrap();
        sup.join().unwrap();
        assert!(!process_alive(pid2));
    }

    /// `node_dump_precomputed` reads the host file, and `node_start` with
    /// `fresh_state` wipes the unit's config dir.
    #[test]
    fn supervise_node_fresh_state_and_dump_precomputed() {
        let dir = tempdir::TempDir::new("supervisor-fresh-test").unwrap();
        let socket_path = dir.path().join("supervisor.sock");
        // network_path = socket parent ⇒ config dir at <net>/config-directory/<name>.
        let cfg = dir.path().join("config-directory").join("sleeper");
        std::fs::create_dir_all(&cfg).unwrap();
        std::fs::write(cfg.join("precomputed_blocks.log"), "block1\nblock2").unwrap();

        let plan = SupervisorPlan {
            network_id: "test-net".into(),
            socket_path: socket_path.clone(),
            spec: BackendSpec::Native {
                nodes: vec![NativeNodeSpec {
                    name: "sleeper".into(),
                    binary: "/bin/sleep".into(),
                    args: vec!["300".into()],
                    env: vec![],
                    log_file: dir.path().join("sleeper.log"),
                }],
            },
        };
        let sup = std::thread::spawn(move || run_blocking(plan).unwrap());
        let mut waited = 0;
        while !socket_path.exists() && waited < 100 {
            std::thread::sleep(std::time::Duration::from_millis(50));
            waited += 1;
        }
        assert!(socket_path.exists());

        let name = serde_json::json!({ "name": "sleeper" });
        let dump = rpc_call(&socket_path, "node_dump_precomputed", name.clone()).unwrap();
        assert_eq!(dump["precomputed_blocks"], "block1\nblock2");

        rpc_call(&socket_path, "node_stop", name.clone()).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(200));
        rpc_call(
            &socket_path,
            "node_start",
            serde_json::json!({ "name": "sleeper", "fresh_state": true }),
        )
        .unwrap();
        assert!(
            !cfg.join("precomputed_blocks.log").exists(),
            "fresh_state should have wiped the config dir"
        );

        rpc_call(&socket_path, "stop", serde_json::Value::Null).unwrap();
        sup.join().unwrap();
    }

    #[test]
    fn unknown_method_returns_error() {
        let ctx = Arc::new(SupervisorCtx {
            execution: Execution::Native,
            network_id: "t".into(),
            network_path: std::path::PathBuf::from("/tmp"),
            launches: HashMap::new(),
        });
        let state = Arc::new(Mutex::new(SupervisorState::new()));
        let shutdown = Arc::new(Notify::new());
        let req = RpcRequest {
            jsonrpc: Some("2.0".into()),
            id: serde_json::json!(7),
            method: "nope".into(),
            params: serde_json::Value::Null,
        };
        let rt = tokio::runtime::Runtime::new().unwrap();
        let resp = rt.block_on(dispatch(req, &ctx, &state, &shutdown));
        assert_eq!(resp.id, serde_json::json!(7));
        assert!(resp.result.is_none());
        assert_eq!(resp.error.unwrap().code, METHOD_NOT_FOUND);
    }

    /// End-to-end docker: launch a real alpine container as a supervisor unit,
    /// query `status`, then `stop`, and confirm teardown removes it. Requires a
    /// docker daemon; `#[ignore]`d so CI (no docker-in-docker) skips it.
    /// Run manually: `cargo test supervise_docker_unit -- --ignored --nocapture`.
    #[test]
    #[ignore]
    fn supervise_docker_unit_status_stop() {
        let dir = tempdir::TempDir::new("supervisor-docker-test").unwrap();
        let socket_path = dir.path().join("supervisor.sock");

        let plan = SupervisorPlan {
            network_id: "docker-test-net".into(),
            socket_path: socket_path.clone(),
            spec: BackendSpec::Docker {
                network_name: "minimina-suptest-net".into(),
                nodes: vec![DockerNodeSpec {
                    name: "suptest".into(),
                    container_name: "minimina-suptest-ctr".into(),
                    image: "alpine:3.19".into(),
                    entrypoint: None,
                    cmd: vec!["sleep".into(), "300".into()],
                    env: vec![],
                    ports: vec![],
                    mounts: vec![],
                    aliases: vec!["suptest-node".into()],
                }],
            },
        };

        let sup = std::thread::spawn(move || run_blocking(plan).unwrap());

        let mut waited = 0;
        while !socket_path.exists() && waited < 600 {
            std::thread::sleep(std::time::Duration::from_millis(100));
            waited += 1;
        }
        assert!(socket_path.exists(), "socket never appeared");

        let status = rpc_call(&socket_path, "status", serde_json::Value::Null).unwrap();
        let nodes = status["nodes"].as_array().unwrap();
        assert_eq!(nodes.len(), 1);
        assert_eq!(nodes[0]["status"]["state"], "running");

        let _ = rpc_call(&socket_path, "stop", serde_json::Value::Null).unwrap();
        sup.join().unwrap();
        assert!(!socket_path.exists(), "socket should be removed");
    }
}
