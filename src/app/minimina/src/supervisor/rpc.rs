//! Hand-rolled JSON-RPC 2.0 over a Unix domain socket.
//!
//! Server side: newline-delimited request/response, one task per connection
//! ([`serve`]). Client side: a blocking [`rpc_call`] usable from the otherwise
//! non-async CLI. Framing is interoperable with Go's
//! `json.Encoder`/`json.Decoder`.

use std::path::Path;
use std::sync::{Arc, Mutex};

use log::{error, warn};
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixListener;
use tokio::sync::Notify;

use super::backend::Backend;
use super::{SupervisorCtx, SupervisorState};

#[derive(Deserialize)]
pub(super) struct RpcRequest {
    #[allow(dead_code)]
    jsonrpc: Option<String>,
    #[serde(default)]
    pub(super) id: serde_json::Value,
    pub(super) method: String,
    #[serde(default)]
    params: serde_json::Value,
}

impl RpcRequest {
    /// Parse one request line; a malformed line becomes the error response to
    /// send back (parsing details stay inside this type).
    fn parse(line: &str) -> Result<RpcRequest, RpcResponse> {
        serde_json::from_str(line).map_err(|e| {
            RpcResponse::err(
                serde_json::Value::Null,
                PARSE_ERROR,
                format!("invalid request: {e}"),
            )
        })
    }
}

#[cfg(test)]
impl RpcRequest {
    pub(super) fn new_test(id: serde_json::Value, method: &str) -> RpcRequest {
        RpcRequest {
            jsonrpc: Some("2.0".into()),
            id,
            method: method.into(),
            params: serde_json::Value::Null,
        }
    }
}

#[derive(Serialize)]
pub(super) struct RpcResponse {
    jsonrpc: &'static str,
    pub(super) id: serde_json::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(super) result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(super) error: Option<RpcError>,
}

#[derive(Serialize)]
pub(super) struct RpcError {
    pub(super) code: i64,
    pub(super) message: String,
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

pub(super) const METHOD_NOT_FOUND: i64 = -32601;
const PARSE_ERROR: i64 = -32700;
const INVALID_PARAMS: i64 = -32602;
/// Server-defined error for a node operation that failed (unknown/duplicate
/// node, launch failure, log read failure).
const NODE_ERROR: i64 = -32000;

/// Extract a required string `name` param, or the error response for a missing
/// one.
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

/// Spawn the accept loop: one connection-handler task per client.
pub(super) fn serve<B: Backend>(
    listener: UnixListener,
    ctx: Arc<SupervisorCtx<B>>,
    state: Arc<Mutex<SupervisorState<B::Killer>>>,
    shutdown: Arc<Notify>,
) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        loop {
            match listener.accept().await {
                Ok((stream, _addr)) => {
                    tokio::spawn(handle_connection::<B>(
                        stream,
                        ctx.clone(),
                        state.clone(),
                        shutdown.clone(),
                    ));
                }
                Err(e) => {
                    // The socket is the only way to drive the network; if it
                    // dies, tear down cleanly rather than run undrivable.
                    error!("supervisor: accept error, shutting down: {e}");
                    shutdown.notify_one();
                    break;
                }
            }
        }
    })
}

/// Handle one client connection: newline-delimited JSON-RPC request/response.
async fn handle_connection<B: Backend>(
    stream: tokio::net::UnixStream,
    ctx: Arc<SupervisorCtx<B>>,
    state: Arc<Mutex<SupervisorState<B::Killer>>>,
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

        let response = match RpcRequest::parse(&line) {
            Ok(req) => dispatch::<B>(req, &ctx, &state, &shutdown).await,
            Err(resp) => resp,
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

/// Dispatch a single request. State-mutating helpers keep the `std::sync::Mutex`
/// only for the moment they touch it, never across an `.await`; node ops reach
/// the backend + retained specs through `ctx`.
pub(super) async fn dispatch<B: Backend>(
    req: RpcRequest,
    ctx: &Arc<SupervisorCtx<B>>,
    state: &Arc<Mutex<SupervisorState<B::Killer>>>,
    shutdown: &Arc<Notify>,
) -> RpcResponse {
    let id = req.id.clone();
    let node_err = |message: String| RpcError {
        code: NODE_ERROR,
        message,
    };
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
                super::node_start::<B>(ctx, state, &name, fresh)
                    .await
                    .map_err(node_err)
            }
            Err(e) => Err(e),
        },
        "node_stop" => match param_name(&req.params) {
            Ok(name) => super::node_stop::<B>(state, &name).await.map_err(node_err),
            Err(e) => Err(e),
        },
        "node_logs" => match param_name(&req.params) {
            Ok(name) => {
                let tail = req.params.get("tail").and_then(|v| v.as_u64());
                super::node_logs::<B>(ctx, &name, tail)
                    .await
                    .map_err(node_err)
            }
            Err(e) => Err(e),
        },
        "node_dump_precomputed" => match param_name(&req.params) {
            Ok(name) => super::node_dump_precomputed::<B>(ctx, &name).map_err(node_err),
            Err(e) => Err(e),
        },
        "node_import_accounts" => match param_name(&req.params) {
            Ok(name) => super::node_import_accounts::<B>(ctx, &name)
                .await
                .map_err(node_err),
            Err(e) => Err(e),
        },
        "dump_archive_data" => super::dump_archive_data::<B>(ctx).await.map_err(node_err),
        "run_replayer" => match param_name(&req.params) {
            Ok(name) => super::run_replayer::<B>(ctx, &name).await.map_err(node_err),
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
    Ok(resp
        .get("result")
        .cloned()
        .unwrap_or(serde_json::Value::Null))
}
