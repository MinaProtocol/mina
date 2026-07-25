//! Foreground, tokio-managed network supervisor.
//!
//! `network start` builds a tokio runtime and calls [`run_blocking`]. The
//! supervisor owns the network's **units** — native child processes *or* docker
//! containers — reaping their real exit codes, and serves a hand-rolled
//! **JSON-RPC 2.0** API over a Unix domain socket so a separate short-lived CLI
//! invocation (`status`/`stop`) can drive it while it runs in the foreground.
//!
//! Module layout — one concern per file:
//! - [`plan`] — the input contract (specs + status), shared with the plan
//!   builders; depends on nothing here. The plan's `Box<dyn BackendSpec>` is
//!   the *only* dynamic call in the supervisor: the builder's choice of spec
//!   type is the backend choice, made exactly once.
//! - [`backend`] — the [`Backend`] trait: what a backend must provide. One
//!   network is *all* native or *all* docker; past the plan's one dynamic
//!   entry, everything is monomorphic in `B: Backend`, so mixing is
//!   unrepresentable.
//! - [`native`] / [`docker`] — the two backend implementations.
//! - [`rpc`] — the JSON-RPC server (per-connection tasks) and blocking client.
//! - this file — the runtime: launch every unit with a waiter task that reaps
//!   its exit, serve RPC, tear down on `stop`/SIGINT.
//!
//! Scope today: no detachment (foreground). RPCs: network-level `status`/`stop`
//! and node-level `node_start`/`node_stop`/`node_logs`.
//!
//! Concurrency: one `Arc<Mutex<SupervisorState>>` (`std::sync::Mutex`, never
//! held across `.await` — copy out, drop the guard, then await).

mod backend;
mod docker;
mod native;
pub mod plan;
mod rpc;

pub use plan::SupervisorPlan;
pub use rpc::rpc_call;

use std::collections::HashMap;
use std::path::Path;
use std::sync::{Arc, Mutex};

use log::{error, info, warn};
use tokio::net::UnixListener;
use tokio::sync::Notify;

use backend::Backend;
use plan::{NamedSpec, NodeStatus};

// ---------------------------------------------------------------------------
// Live state
// ---------------------------------------------------------------------------

/// One supervised node: its status plus, while it is alive, the handle to
/// terminate it (`None` once it has exited or if it never started).
///
/// `generation` identifies the current incarnation: each (re)launch stamps a
/// fresh generation, so a superseded unit's waiter can tell its late exit apart
/// from the fresh unit that replaced it and decline to clobber it.
struct Node<K> {
    status: NodeStatus,
    killer: Option<K>,
    generation: u64,
}

struct SupervisorState<K> {
    nodes: HashMap<String, Node<K>>,
    shutdown: bool,
    /// Monotonic source of per-node incarnation ids (see [`Node::generation`]).
    next_gen: u64,
}

impl<K> SupervisorState<K> {
    fn new() -> Self {
        SupervisorState {
            nodes: HashMap::new(),
            shutdown: false,
            next_gen: 0,
        }
    }

    /// Allocate the next incarnation id.
    fn next_generation(&mut self) -> u64 {
        let g = self.next_gen;
        self.next_gen += 1;
        g
    }

    /// Snapshot for the `status` RPC (ordered by node name for stable output).
    fn snapshot(&self) -> serde_json::Value {
        let mut names: Vec<&String> = self.nodes.keys().collect();
        names.sort();
        let nodes: Vec<serde_json::Value> = names
            .into_iter()
            .map(|n| serde_json::json!({ "name": n, "status": self.nodes[n].status }))
            .collect();
        serde_json::json!({ "nodes": nodes })
    }
}

/// Immutable per-run context: built once, then only read. Shared (`Arc`) with
/// every RPC handler so node ops can reach the backend and each node's retained
/// launch spec without touching the mutable state lock.
struct SupervisorCtx<B: Backend> {
    /// The live backend, used to (re)launch units and read their logs.
    backend: B,
    /// Each node's launch spec, retained so a stopped unit can be relaunched by
    /// name (`node_start`) — the restart path the hardfork orchestrator drives.
    launches: HashMap<String, B::NodeSpec>,
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Build a tokio runtime and run the supervisor to completion (blocking).
/// Returns when the network is torn down (via `stop` RPC or SIGINT).
pub fn run_blocking(plan: SupervisorPlan) -> std::io::Result<()> {
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;
    rt.block_on(plan.spec.run(&plan.network_id, &plan.socket_path))
}

/// The whole runtime, generic in the backend. Entered through
/// [`plan::BackendSpec::run`], which each backend impl points at itself —
/// dispatch already happened when the plan was built.
async fn run_backend<B: Backend>(
    spec: &B::Spec,
    network_id: &str,
    socket_path: &Path,
) -> std::io::Result<()> {
    let backend = B::setup(spec, network_id).await?;

    // Retain each node's launch spec (for `node_start`) and remember the launch
    // order, then share it all (`Arc`) with the RPC handlers.
    let order: Vec<String> = B::nodes(spec).iter().map(|n| n.name().to_string()).collect();
    let launches: HashMap<String, B::NodeSpec> = B::nodes(spec)
        .iter()
        .map(|n| (n.name().to_string(), n.clone()))
        .collect();
    let ctx = Arc::new(SupervisorCtx { backend, launches });
    let state = Arc::new(Mutex::new(SupervisorState::new()));
    let shutdown = Arc::new(Notify::new());

    // Launch every unit in order, each with a waiter task that reaps its exit.
    for name in &order {
        launch_and_register::<B>(&ctx, &state, name).await;
    }

    // Bind the RPC socket (unlink any stale socket first).
    let _ = std::fs::remove_file(socket_path);
    let listener = UnixListener::bind(socket_path)?;
    info!("supervisor: serving RPC on '{}'", socket_path.display());
    let accept_task = rpc::serve::<B>(listener, ctx.clone(), state.clone(), shutdown.clone());

    tokio::select! {
        _ = shutdown.notified() => info!("supervisor: stop requested"),
        r = tokio::signal::ctrl_c() => match r {
            Ok(()) => info!("supervisor: SIGINT received"),
            Err(e) => warn!("supervisor: signal error: {e}"),
        },
    }

    accept_task.abort();
    stop_units::<B>(&state).await;
    ctx.backend.teardown().await;
    let _ = std::fs::remove_file(socket_path);
    info!("supervisor: network '{network_id}' stopped");
    Ok(())
}

/// Launch one node from its retained spec and register it + its waiter task.
/// Shared by startup and `node_start`; an unknown name or a launch error is
/// recorded as a `Failed` node rather than propagated.
async fn launch_and_register<B: Backend>(
    ctx: &Arc<SupervisorCtx<B>>,
    state: &Arc<Mutex<SupervisorState<B::Killer>>>,
    name: &str,
) {
    let Some(node) = ctx.launches.get(name) else {
        fail_unit(state, name, format!("unknown node '{name}'"));
        return;
    };
    match ctx.backend.launch(node).await {
        Ok((unit, killer, pid)) => register_unit::<B>(state, name, pid, unit, killer),
        Err(e) => fail_unit(state, name, e.to_string()),
    }
}

// ---------------------------------------------------------------------------
// Node-level RPC operations
// ---------------------------------------------------------------------------

/// (Re)start a single node from its retained launch spec. Errors if it is
/// already running or the name is unknown.
async fn node_start<B: Backend>(
    ctx: &Arc<SupervisorCtx<B>>,
    state: &Arc<Mutex<SupervisorState<B::Killer>>>,
    name: &str,
) -> Result<serde_json::Value, String> {
    // Reserve the name under the lock so two concurrent `node_start`s can't both
    // pass the "already running" check and both launch: reject if running or
    // unknown, else stamp a placeholder that blocks a racing start until the
    // real unit registers (or fails). `launch_and_register` then overwrites it.
    {
        let mut st = state.lock().unwrap();
        if matches!(
            st.nodes.get(name).map(|n| &n.status),
            Some(NodeStatus::Running { .. })
        ) {
            return Err(format!("node '{name}' is already running"));
        }
        if !ctx.launches.contains_key(name) {
            return Err(format!("unknown node '{name}'"));
        }
        let generation = st.next_generation();
        st.nodes.insert(
            name.to_string(),
            Node {
                status: NodeStatus::Running { pid: None },
                killer: None,
                generation,
            },
        );
    }
    launch_and_register::<B>(ctx, state, name).await;
    Ok(serde_json::json!({ "started": name }))
}

/// Stop a single node (graceful → force). Its killer is taken from state so
/// teardown won't touch it again; the waiter task records the exit.
async fn node_stop<B: Backend>(
    state: &Arc<Mutex<SupervisorState<B::Killer>>>,
    name: &str,
) -> Result<serde_json::Value, String> {
    let killer = state
        .lock()
        .unwrap()
        .nodes
        .get_mut(name)
        .and_then(|n| n.killer.take());
    match killer {
        Some(k) => {
            B::terminate(&k).await;
            // Give the unit up to ~2s to exit on SIGTERM (its waiter flips the
            // status to `Exited`), polling so a fast exit returns promptly;
            // force-kill only if it is still alive at the deadline.
            let mut exited = false;
            for _ in 0..20 {
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
                if matches!(
                    state.lock().unwrap().nodes.get(name).map(|n| &n.status),
                    Some(NodeStatus::Exited { .. })
                ) {
                    exited = true;
                    break;
                }
            }
            if !exited {
                B::force_kill(&k).await;
            }
            Ok(serde_json::json!({ "stopped": name }))
        }
        None => Err(format!("node '{name}' is not running")),
    }
}

/// Fetch a node's logs — native reads its log file; docker streams the
/// container's logs. `tail` limits to the last N lines.
async fn node_logs<B: Backend>(
    ctx: &Arc<SupervisorCtx<B>>,
    name: &str,
    tail: Option<u64>,
) -> Result<serde_json::Value, String> {
    let node = ctx
        .launches
        .get(name)
        .ok_or_else(|| format!("unknown node '{name}'"))?;
    let logs = ctx
        .backend
        .logs(node, tail)
        .await
        .map_err(|e| e.to_string())?;
    Ok(serde_json::json!({ "logs": logs }))
}

/// Record a launched unit in state and spawn its waiter task.
fn register_unit<B: Backend>(
    state: &Arc<Mutex<SupervisorState<B::Killer>>>,
    name: &str,
    pid: Option<u32>,
    mut unit: B::Unit,
    killer: B::Killer,
) {
    info!("supervisor: started '{name}' (pid {pid:?})");
    let generation = {
        let mut st = state.lock().unwrap();
        let generation = st.next_generation();
        st.nodes.insert(
            name.to_string(),
            Node {
                status: NodeStatus::Running { pid },
                killer: Some(killer),
                generation,
            },
        );
        generation
    };
    let st = state.clone();
    let name = name.to_string();
    tokio::spawn(async move {
        let code = B::wait(&mut unit).await;
        info!("supervisor: '{name}' exited (code {code:?})");
        // Only record the exit if this is still the current incarnation: a
        // restart (`node_start`) supersedes an older unit, whose late exit must
        // not clobber the fresh unit's `Running` state (leaving it untracked).
        let mut st = st.lock().unwrap();
        if let Some(node) = st.nodes.get_mut(&name) {
            if node.generation == generation {
                node.status = NodeStatus::Exited { code };
                node.killer = None;
            }
        }
    });
}

fn fail_unit<K>(state: &Arc<Mutex<SupervisorState<K>>>, name: &str, error: String) {
    error!("supervisor: failed to start '{name}': {error}");
    let mut st = state.lock().unwrap();
    let generation = st.next_generation();
    st.nodes.insert(
        name.to_string(),
        Node {
            status: NodeStatus::Failed { error },
            killer: None,
            generation,
        },
    );
}

/// Terminate every live unit (graceful → force). Network-level teardown is the
/// backend's job (see [`Backend::teardown`]).
async fn stop_units<B: Backend>(state: &Arc<Mutex<SupervisorState<B::Killer>>>) {
    let killers: Vec<B::Killer> = {
        let st = state.lock().unwrap();
        st.nodes.values().filter_map(|n| n.killer.clone()).collect()
    };
    for k in &killers {
        B::terminate(k).await;
    }
    if !killers.is_empty() {
        tokio::time::sleep(std::time::Duration::from_secs(2)).await;
        for k in &killers {
            B::force_kill(k).await;
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::native::process_alive;
    use super::plan::{DockerBackendSpec, DockerNodeSpec, NativeBackendSpec, NativeNodeSpec};
    use super::rpc::{dispatch, RpcRequest, METHOD_NOT_FOUND};
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
            spec: Box::new(NativeBackendSpec {
                nodes: vec![NativeNodeSpec {
                    name: "sleeper".into(),
                    binary: "/bin/sleep".into(),
                    args: vec!["300".into()],
                    env: vec![],
                    log_file,
                }],
            }),
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

    /// node_stop then node_start a live unit: it dies, then relaunches with a
    /// new pid — the restart path the hardfork orchestrator drives.
    #[test]
    fn supervise_node_stop_then_start() {
        let dir = tempdir::TempDir::new("supervisor-node-test").unwrap();
        let socket_path = dir.path().join("supervisor.sock");

        let plan = SupervisorPlan {
            network_id: "test-net".into(),
            socket_path: socket_path.clone(),
            spec: Box::new(NativeBackendSpec {
                nodes: vec![NativeNodeSpec {
                    name: "sleeper".into(),
                    binary: "/bin/sleep".into(),
                    args: vec!["300".into()],
                    env: vec![],
                    log_file: dir.path().join("sleeper.log"),
                }],
            }),
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

    #[test]
    fn unknown_method_returns_error() {
        let ctx = Arc::new(SupervisorCtx::<native::NativeBackend> {
            backend: native::NativeBackend,
            launches: HashMap::new(),
        });
        let state = Arc::new(Mutex::new(SupervisorState::<u32>::new()));
        let shutdown = Arc::new(Notify::new());
        let req = RpcRequest::new_test(serde_json::json!(7), "nope");
        let rt = tokio::runtime::Runtime::new().unwrap();
        let resp = rt.block_on(dispatch::<native::NativeBackend>(
            req, &ctx, &state, &shutdown,
        ));
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
            spec: Box::new(DockerBackendSpec {
                network_name: "minimina-suptest-net".into(),
                nodes: vec![DockerNodeSpec {
                    name: "minimina-suptest-ctr".into(),
                    image: "alpine:3.19".into(),
                    entrypoint: None,
                    cmd: vec!["sleep".into(), "300".into()],
                    env: vec![],
                    ports: vec![],
                    mounts: vec![],
                    aliases: vec!["suptest-node".into()],
                }],
            }),
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
