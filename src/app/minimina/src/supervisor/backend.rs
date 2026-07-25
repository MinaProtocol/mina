//! The backend seam: what a backend must provide for the supervisor to run it.
//!
//! A network runs entirely on **one** backend — native processes *or* docker
//! containers, never a mix. Dispatch happens exactly once, when the plan
//! builder picks its spec type (see [`super::plan::BackendSpec`]); from there
//! the whole runtime is monomorphic in `B: Backend`, so mixing is
//! unrepresentable.
//!
//! One trait, two handle *types*: a unit's wait handle and its kill handle
//! must be separate objects because they live in different tasks — the waiter
//! task owns the unit exclusively (`wait` takes `&mut`; a process `Child` is
//! not cloneable), while kill handles are cloned out of shared state at
//! teardown. Docker collapses both into one cloneable handle type; native is
//! why the two slots exist.
//!
//! Async methods are declared as `impl Future + Send` (RPITIT) rather than
//! `async fn` so the supervisor may await them inside spawned tasks.

use std::future::Future;
use std::io;
use std::path::Path;

use super::plan::NamedSpec;

/// A backend the supervisor can run a network on. Owns network-*level*
/// resources (docker: the docker network + DNS), acquired by [`Backend::setup`]
/// from the backend's share of the plan. All unit behavior lives here as
/// associated functions; `Unit`/`Killer` are plain handle types.
pub trait Backend: Sized + Send + Sync + 'static {
    type Spec;
    /// Per-node spec. `Clone + Send + Sync` so the supervisor can retain a copy
    /// of each (shared with RPC handlers) to relaunch a stopped unit by name.
    type NodeSpec: NamedSpec + Clone + Send + Sync + 'static;
    /// A live unit's wait handle. Exclusively owned by its waiter task.
    type Unit: Send + 'static;
    /// A live unit's kill handle. Cloned out of shared state at teardown.
    type Killer: Clone + Send + 'static;

    /// Acquire network-level resources and return the live backend.
    fn setup(spec: &Self::Spec, network_id: &str) -> impl Future<Output = io::Result<Self>> + Send;

    /// The per-node specs carried by this backend's share of the plan.
    fn nodes(spec: &Self::Spec) -> &[Self::NodeSpec];

    /// Launch one node, returning its live unit, kill handle, and host pid.
    fn launch(
        &self,
        node: &Self::NodeSpec,
    ) -> impl Future<Output = io::Result<(Self::Unit, Self::Killer, Option<u32>)>> + Send;

    /// Await the unit's exit and return its exit code (`None` if unknown).
    fn wait(unit: &mut Self::Unit) -> impl Future<Output = Option<i32>> + Send;

    /// Graceful stop (SIGTERM / `docker stop`).
    fn terminate(killer: &Self::Killer) -> impl Future<Output = ()> + Send;

    /// Forceful removal (SIGKILL survivors / `docker rm -f`).
    fn force_kill(killer: &Self::Killer) -> impl Future<Output = ()> + Send;

    /// Fetch one node's logs (native: read its log file; docker: container
    /// logs). `tail` limits to the last N lines when `Some`.
    fn logs(
        &self,
        node: &Self::NodeSpec,
        tail: Option<u64>,
    ) -> impl Future<Output = io::Result<String>> + Send;

    // --- exec-based archive/account ops. The command each op runs is inherently
    // backend-specific (container-internal paths + `exec` vs host-absolute paths
    // + a host process), so each backend owns the whole op rather than sharing a
    // generic `exec` primitive. ---

    /// Import each privkey file in `files` (found under
    /// `<network_path>/network-keypairs`) into node `node`'s wallet, offline.
    /// Returns the number imported.
    fn import_accounts(
        &self,
        node: &Self::NodeSpec,
        network_path: &Path,
        files: &[String],
    ) -> impl Future<Output = io::Result<u64>> + Send;

    /// `pg_dump` the archive database (docker: `exec` in the postgres container;
    /// native: `pg_dump` over TCP to 127.0.0.1). Returns the dump text.
    fn dump_archive_data(
        &self,
        network_id: &str,
    ) -> impl Future<Output = io::Result<String>> + Send;

    /// Run the replayer against the archive DB via archive-service unit `svc`
    /// (the caller has already written the start slot into `replayer_input.json`).
    /// Returns the replayer's output.
    fn run_replayer(
        &self,
        svc: &Self::NodeSpec,
        network_path: &Path,
        network_id: &str,
    ) -> impl Future<Output = io::Result<String>> + Send;

    /// Release network-level resources (docker: remove the network). Units
    /// are torn down separately, before this (see `super::stop_units`).
    fn teardown(&self) -> impl Future<Output = ()> + Send;
}
