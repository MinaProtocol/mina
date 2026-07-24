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
//! Scope today: no detachment (foreground); `status`/`stop` only.
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
struct Node<K> {
    status: NodeStatus,
    killer: Option<K>,
}

struct SupervisorState<K> {
    nodes: HashMap<String, Node<K>>,
    shutdown: bool,
}

impl<K> SupervisorState<K> {
    fn new() -> Self {
        SupervisorState {
            nodes: HashMap::new(),
            shutdown: false,
        }
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
    let state = Arc::new(Mutex::new(SupervisorState::new()));
    let shutdown = Arc::new(Notify::new());

    // Launch every unit, each with a waiter task that reaps its exit.
    for node in B::nodes(spec) {
        match backend.launch(node).await {
            Ok((unit, killer, pid)) => register_unit::<B>(&state, node.name(), pid, unit, killer),
            Err(e) => fail_unit(&state, node.name(), e.to_string()),
        }
    }

    // Bind the RPC socket (unlink any stale socket first).
    let _ = std::fs::remove_file(socket_path);
    let listener = UnixListener::bind(socket_path)?;
    info!("supervisor: serving RPC on '{}'", socket_path.display());
    let accept_task = rpc::serve(listener, state.clone(), shutdown.clone());

    tokio::select! {
        _ = shutdown.notified() => info!("supervisor: stop requested"),
        r = tokio::signal::ctrl_c() => match r {
            Ok(()) => info!("supervisor: SIGINT received"),
            Err(e) => warn!("supervisor: signal error: {e}"),
        },
    }

    accept_task.abort();
    stop_units::<B>(&state).await;
    backend.teardown().await;
    let _ = std::fs::remove_file(socket_path);
    info!("supervisor: network '{network_id}' stopped");
    Ok(())
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
    state.lock().unwrap().nodes.insert(
        name.to_string(),
        Node {
            status: NodeStatus::Running { pid },
            killer: Some(killer),
        },
    );
    let st = state.clone();
    let name = name.to_string();
    tokio::spawn(async move {
        let code = B::wait(&mut unit).await;
        info!("supervisor: '{name}' exited (code {code:?})");
        st.lock().unwrap().nodes.insert(
            name,
            Node {
                status: NodeStatus::Exited { code },
                killer: None,
            },
        );
    });
}

fn fail_unit<K>(state: &Arc<Mutex<SupervisorState<K>>>, name: &str, error: String) {
    error!("supervisor: failed to start '{name}': {error}");
    state.lock().unwrap().nodes.insert(
        name.to_string(),
        Node {
            status: NodeStatus::Failed { error },
            killer: None,
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

    #[test]
    fn unknown_method_returns_error() {
        let state = Arc::new(Mutex::new(SupervisorState::<u32>::new()));
        let shutdown = Arc::new(Notify::new());
        let req = RpcRequest::new_test(serde_json::json!(7), "nope");
        let resp = dispatch(req, &state, &shutdown);
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
