//! Foreground, tokio-managed network supervisor (skeleton — layer 1).
//!
//! `network start` (native) builds a tokio runtime and calls [`run_blocking`].
//! The supervisor owns the daemons **as its children** (so it reaps their real
//! exit codes), and serves a hand-rolled **JSON-RPC 2.0** API over a Unix domain
//! socket so a separate short-lived CLI invocation (`status`/`stop`) can drive it
//! while it runs in the foreground.
//!
//! Scope of this skeleton (see wayfinder ticket `supervisor-skeleton`):
//!   * no detachment — the process stays attached to the terminal;
//!   * no workloads, no read/control RPCs beyond `status`/`stop`;
//!   * native backend only.
//!
//! Concurrency model: one `Arc<Mutex<SupervisorState>>` (a `std::sync::Mutex`
//! that is **never held across an `.await`** — we copy data out, drop the guard,
//! then await). Writers are the per-child waiter tasks and the RPC handlers.
//!
//! Transport: newline-delimited JSON. Each request is one line
//! (`{"jsonrpc":"2.0","id":..,"method":..,"params":..}`) and each response is one
//! line — directly interoperable with Go's `json.Encoder`/`json.Decoder`.

use log::{error, info, warn};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixListener;
use tokio::sync::Notify;

// ---------------------------------------------------------------------------
// Plan subset
// ---------------------------------------------------------------------------

/// One daemon the supervisor launches and owns. This is the *subset* of the
/// materialized plan the skeleton needs; the full `materialized-plan.json` shape
/// is produced later by the sampler/materializer.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct NodeSpec {
    pub name: String,
    pub binary: PathBuf,
    pub args: Vec<String>,
    #[serde(default)]
    pub env: Vec<(String, String)>,
    pub log_file: PathBuf,
}

/// Everything the supervisor needs to run a network. Held as the in-memory SSOT
/// for the process lifetime; never re-read from disk.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct SupervisorPlan {
    pub network_id: String,
    pub socket_path: PathBuf,
    pub nodes: Vec<NodeSpec>,
}

// ---------------------------------------------------------------------------
// Live state
// ---------------------------------------------------------------------------

/// Per-node status. `Exited` carries the reaped code so migrate-exit
/// clean-vs-crash is distinguishable downstream.
#[derive(Clone, Debug, Serialize)]
#[serde(tag = "state", rename_all = "snake_case")]
pub enum NodeStatus {
    Running { pid: u32 },
    Exited { code: Option<i32> },
    Failed { error: String },
}

struct SupervisorState {
    nodes: HashMap<String, NodeStatus>,
    /// PIDs of live children, for teardown.
    pids: HashMap<String, u32>,
    shutdown: bool,
}

impl SupervisorState {
    fn new() -> Self {
        SupervisorState {
            nodes: HashMap::new(),
            pids: HashMap::new(),
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
// JSON-RPC 2.0 envelope (hand-rolled)
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct RpcRequest {
    #[allow(dead_code)]
    jsonrpc: Option<String>,
    #[serde(default)]
    id: serde_json::Value,
    method: String,
    #[allow(dead_code)]
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

// JSON-RPC method-not-found code.
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
    let state = Arc::new(Mutex::new(SupervisorState::new()));
    let shutdown = Arc::new(Notify::new());

    // Spawn every daemon as a child + a waiter task that reaps its exit.
    for node in &plan.nodes {
        match spawn_node(node) {
            Ok(mut child) => {
                let pid = child.id().unwrap_or(0);
                info!("supervisor: started '{}' (pid {})", node.name, pid);
                {
                    let mut st = state.lock().unwrap();
                    st.nodes
                        .insert(node.name.clone(), NodeStatus::Running { pid });
                    st.pids.insert(node.name.clone(), pid);
                }
                let st = state.clone();
                let name = node.name.clone();
                tokio::spawn(async move {
                    let code = match child.wait().await {
                        Ok(status) => status.code(),
                        Err(e) => {
                            warn!("supervisor: wait() failed for '{name}': {e}");
                            None
                        }
                    };
                    info!("supervisor: '{name}' exited (code {code:?})");
                    let mut st = st.lock().unwrap();
                    st.nodes.insert(name.clone(), NodeStatus::Exited { code });
                    st.pids.remove(&name);
                });
            }
            Err(e) => {
                error!("supervisor: failed to start '{}': {e}", node.name);
                state.lock().unwrap().nodes.insert(
                    node.name.clone(),
                    NodeStatus::Failed {
                        error: e.to_string(),
                    },
                );
            }
        }
    }

    // Bind the RPC socket (unlink any stale socket first).
    let _ = std::fs::remove_file(&plan.socket_path);
    let listener = UnixListener::bind(&plan.socket_path)?;
    info!(
        "supervisor: serving RPC on '{}'",
        plan.socket_path.display()
    );

    // Accept loop as its own task so the main task can select on shutdown.
    let accept_state = state.clone();
    let accept_shutdown = shutdown.clone();
    let accept_task = tokio::spawn(async move {
        loop {
            match listener.accept().await {
                Ok((stream, _addr)) => {
                    let st = accept_state.clone();
                    let sd = accept_shutdown.clone();
                    tokio::spawn(handle_connection(stream, st, sd));
                }
                Err(e) => {
                    warn!("supervisor: accept error: {e}");
                    break;
                }
            }
        }
    });

    // Wait for a stop request or SIGINT.
    tokio::select! {
        _ = shutdown.notified() => info!("supervisor: stop requested"),
        r = tokio::signal::ctrl_c() => {
            match r {
                Ok(()) => info!("supervisor: SIGINT received"),
                Err(e) => warn!("supervisor: signal error: {e}"),
            }
        }
    }

    // Teardown: stop accepting, kill children, clean up the socket.
    accept_task.abort();
    teardown(&state);
    let _ = std::fs::remove_file(&plan.socket_path);
    info!("supervisor: network '{}' stopped", plan.network_id);
    Ok(())
}

/// Handle one client connection: newline-delimited JSON-RPC request/response.
async fn handle_connection(
    stream: tokio::net::UnixStream,
    state: Arc<Mutex<SupervisorState>>,
    shutdown: Arc<Notify>,
) {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();
    loop {
        let line = match lines.next_line().await {
            Ok(Some(l)) => l,
            Ok(None) => break, // client closed
            Err(e) => {
                warn!("supervisor: read error: {e}");
                break;
            }
        };
        if line.trim().is_empty() {
            continue;
        }

        let response = match serde_json::from_str::<RpcRequest>(&line) {
            Ok(req) => dispatch(req, &state, &shutdown),
            Err(e) => RpcResponse::err(
                serde_json::Value::Null,
                -32700, // parse error
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

/// Dispatch a single request. Pure w.r.t. the socket — locks state only briefly,
/// never across an await (there are no awaits here).
fn dispatch(
    req: RpcRequest,
    state: &Arc<Mutex<SupervisorState>>,
    shutdown: &Arc<Notify>,
) -> RpcResponse {
    match req.method.as_str() {
        "status" => {
            let snap = state.lock().unwrap().snapshot();
            RpcResponse::ok(req.id, snap)
        }
        "stop" => {
            state.lock().unwrap().shutdown = true;
            shutdown.notify_one();
            RpcResponse::ok(req.id, serde_json::json!({ "stopping": true }))
        }
        other => RpcResponse::err(
            req.id,
            METHOD_NOT_FOUND,
            format!("unknown method '{other}'"),
        ),
    }
}

/// Spawn a daemon as an owned child. Sets `PR_SET_PDEATHSIG(SIGKILL)` so the
/// child dies if the supervisor dies (best-effort backstop; teardown does an
/// explicit kill).
fn spawn_node(node: &NodeSpec) -> std::io::Result<tokio::process::Child> {
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
    // async-signal-safe. Note: pdeathsig is keyed to the calling *thread*, so on
    // a multi-thread runtime it is a best-effort backstop, not a guarantee.
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

/// SIGTERM every live child, give them a moment, then SIGKILL survivors.
fn teardown(state: &Arc<Mutex<SupervisorState>>) {
    use nix::sys::signal::{self, Signal};
    use nix::unistd::Pid;

    let pids: Vec<(String, u32)> = {
        let st = state.lock().unwrap();
        st.pids.iter().map(|(n, p)| (n.clone(), *p)).collect()
    };
    if pids.is_empty() {
        return;
    }

    for (name, pid) in &pids {
        info!("supervisor: SIGTERM '{name}' (pid {pid})");
        let _ = signal::kill(Pid::from_raw(*pid as i32), Signal::SIGTERM);
    }
    std::thread::sleep(std::time::Duration::from_secs(2));
    for (name, pid) in &pids {
        if process_alive(*pid) {
            warn!("supervisor: SIGKILL '{name}' (pid {pid})");
            let _ = signal::kill(Pid::from_raw(*pid as i32), Signal::SIGKILL);
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
/// Blocking + synchronous — usable from the otherwise non-async CLI without
/// dragging tokio into the caller.
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
    Ok(resp
        .get("result")
        .cloned()
        .unwrap_or(serde_json::Value::Null))
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    /// End-to-end: launch a real child under the supervisor, query `status`,
    /// then `stop`, and confirm the child is reaped and the socket is cleaned up.
    #[test]
    fn supervise_status_stop_reaps_child() {
        let dir = tempdir::TempDir::new("supervisor-test").unwrap();
        let socket_path = dir.path().join("supervisor.sock");
        let log_file = dir.path().join("sleeper.log");

        let plan = SupervisorPlan {
            network_id: "test-net".into(),
            socket_path: socket_path.clone(),
            nodes: vec![NodeSpec {
                name: "sleeper".into(),
                binary: "/bin/sleep".into(),
                args: vec!["300".into()],
                env: vec![],
                log_file,
            }],
        };

        // Run the supervisor on its own thread.
        let sup = std::thread::spawn(move || run_blocking(plan).unwrap());

        // Wait for the socket to appear.
        let mut waited = 0;
        while !socket_path.exists() && waited < 100 {
            std::thread::sleep(std::time::Duration::from_millis(50));
            waited += 1;
        }
        assert!(socket_path.exists(), "socket never appeared");

        // status -> the sleeper should be running with a pid.
        let status = rpc_call(&socket_path, "status", serde_json::Value::Null).unwrap();
        let nodes = status["nodes"].as_array().unwrap();
        assert_eq!(nodes.len(), 1);
        assert_eq!(nodes[0]["name"], "sleeper");
        assert_eq!(nodes[0]["status"]["state"], "running");
        let pid = nodes[0]["status"]["pid"].as_u64().unwrap() as u32;
        assert!(process_alive(pid), "sleeper should be alive");

        // stop -> supervisor tears down and returns.
        let stop = rpc_call(&socket_path, "stop", serde_json::Value::Null).unwrap();
        assert_eq!(stop["stopping"], true);

        sup.join().unwrap();

        // The child must be gone and the socket cleaned up.
        assert!(!process_alive(pid), "sleeper should have been killed");
        assert!(!socket_path.exists(), "socket should be removed");
    }

    #[test]
    fn unknown_method_returns_error() {
        let state = Arc::new(Mutex::new(SupervisorState::new()));
        let shutdown = Arc::new(Notify::new());
        let req = RpcRequest {
            jsonrpc: Some("2.0".into()),
            id: serde_json::json!(7),
            method: "nope".into(),
            params: serde_json::Value::Null,
        };
        let resp = dispatch(req, &state, &shutdown);
        assert_eq!(resp.id, serde_json::json!(7));
        assert!(resp.result.is_none());
        assert_eq!(resp.error.unwrap().code, METHOD_NOT_FOUND);
    }
}
