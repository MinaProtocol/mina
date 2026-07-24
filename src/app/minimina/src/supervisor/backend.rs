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

use super::plan::NamedSpec;

/// A backend the supervisor can run a network on. Owns network-*level*
/// resources (docker: the docker network + DNS), acquired by [`Backend::setup`]
/// from the backend's share of the plan. All unit behavior lives here as
/// associated functions; `Unit`/`Killer` are plain handle types.
pub trait Backend: Sized + Send + Sync + 'static {
    type Spec;
    type NodeSpec: NamedSpec;
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

    /// Release network-level resources (docker: remove the network). Units
    /// are torn down separately, before this (see `super::stop_units`).
    fn teardown(&self) -> impl Future<Output = ()> + Send;
}
