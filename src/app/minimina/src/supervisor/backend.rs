//! The backend seam: what a backend must provide for the supervisor to run it.
//!
//! A network runs entirely on **one** backend — native processes *or* docker
//! containers, never a mix. That single-axis invariant is enforced statically:
//! [`super::run`] matches the plan's [`super::plan::BackendSpec`] exactly once,
//! then hands off to the monomorphic `run_backend<B: Backend>`, so a
//! `NativeBackend` can only ever launch [`super::plan::NativeNodeSpec`]s and
//! yield native units (associated types — there is no unit×backend matrix to
//! guard against at runtime).
//!
//! Async methods are declared as `impl Future + Send` (RPITIT) rather than
//! `async fn` so the supervisor may await them inside spawned tasks.

use std::future::Future;
use std::io;

use super::plan::NamedSpec;

/// A live unit the supervisor awaits for exit. Owned by its waiter task.
pub trait Unit: Send + 'static {
    /// Await the unit's exit and return its exit code (`None` if unknown).
    fn wait(&mut self) -> impl Future<Output = Option<i32>> + Send;
}

/// A cheap, cloneable handle to terminate a unit during teardown.
pub trait Killer: Clone + Send + 'static {
    /// Graceful stop (SIGTERM / `docker stop`).
    fn terminate(&self) -> impl Future<Output = ()> + Send;
    /// Forceful removal (SIGKILL survivors / `docker rm -f`).
    fn force_kill(&self) -> impl Future<Output = ()> + Send;
}

/// A backend the supervisor can run a network on. Owns network-*level*
/// resources (docker: the docker network + DNS); constructed by a
/// backend-specific `setup` (not part of the trait — acquisition differs
/// too much per backend to share a signature).
pub trait Backend: Send + Sync + 'static {
    type NodeSpec: NamedSpec;
    type Unit: Unit;
    type Killer: Killer;

    /// Launch one node, returning its live unit, kill handle, and host pid.
    fn launch(
        &self,
        node: &Self::NodeSpec,
    ) -> impl Future<Output = io::Result<(Self::Unit, Self::Killer, Option<u32>)>> + Send;

    /// Release network-level resources (docker: remove the network). Units
    /// are torn down separately, before this (see `super::stop_units`).
    fn teardown(&self) -> impl Future<Output = ()> + Send;
}
