## v0.10

- Changed the API to make the shutdown behavior of workers more explicit

## v0.9

## 113.43.00

- Take away `@@deriving bin_io` for managed workers.

- Introduce a `spawn_in_foreground` function that returns a `Process.t` along with the worker.

  Also use this opportunity to clean up the handling of file descriptors in the `spawn` case as well.

- Add a couple features to Rpc\_parallel to make debugging connection issues
  easier.

  * Add `Worker.Connection.close_reason`
  * Add `Worker.Connection.sexp_of_t`


- Add some extra security around making Rpc calls to workers.

  Because we do not expose the port of a worker, unless you do really
  hacky things, you are going to go through Rpc\_parallel when running
  Rpcs.  When Rpc\_parallel connects to a worker, it initializes a
  connection state (that includes the worker state). This
  initialization would raise if the worker did not have a server
  listening on the port that the client was talking to. Add some
  security by enforcing unification of worker\_ids instead of ports
  (which will be reused by the OS).

- Make an Rpc_parallel test case deterministic

## 113.33.00

- Adding the mandatory arguments `redirect_stderr` and `redirect_stdout` to `Map_reduce` so it is easier to debug your workers.
  Also removed `spawn_exn` in favor of only exposing `spawn_config_exn`. If you want to spawn a single worker, make a config of one worker.

- Cleans up the implementation-side interface for aborting `Pipe_rpc`s.

  Summary

  The `aborted` `Deferred.t` that got passed to `Pipe_rpc` implementations is
  gone. The situations where it would have been determined now close the reading
  end of the user-supplied pipe instead.

  Details

  Previously, when an RPC dispatcher decided to abort a query, the RPC
  implementation would get its `aborted` `Deferred.t` filled in, but would remain
  free to write some final elements to the pipe.

  This is a little bit more flexible than the new interface, but it's also
  problematic in that the implementer could easily just not pay attention to
  `aborted`. (They're not obligated to pay attention to when the pipe is closed,
  either, but at least they can't keep writing to it.) We don't think the extra
  flexibility was used at all.

  In the future, we may also simplify the client side to remove the `abort`
  function on the dispatch side (at least when not using `dispatch_iter`). For the
  time being it remains, but closing the received pipe is the preferred way of
  aborting the query.

  There are a couple of known ways this might have changed behavior from before.
  Both of these appear not to cause problems in the jane repo.

  - In the past, an implementation could write to a pipe as long as the client
    didn't disconnect, even if it closed its pipe. Now writes will raise after
    a client closes its pipe (or calls `abort`), since the implementor's pipe will
    also be closed in this case. Doing this was already unsafe, though, since the
    pipe *was* closed if the RPC connection was closed.

  - `aborted` was only determined if a client aborted the query or the connection
    was closed. The new alternative, `Pipe.closed` called on the returned pipe,
    will also be determined if the implementation closes the pipe itself. This is
    unlikely to cause serious issues but could potentially cause some confusing
    logging.

- Deal with an fd leak in Managed worker connections

- This feature completely restructured `rpc_parallel` to make it more
  transparent in what it does and doesn't do. I offloaded all the
  connection management and cleanup responsibilities to the user.

  What `Rpc_parallel` used to do for you:
  ------------------------------------
   - Internally there was a special (behind the scenes) Rpc connection
     maintained between the worker and its master upon spawn. Upon this
     connection closing, the worker would shut itself down and the
     master would be notified of a connection lost.
   - We would keep a connection table for you. `run` was called on the
     worker type (i.e. a host and port) because it's implementation
     would get a connection (using an existing one or doing a
     `Rpc.Connection.client`).

  What it now does:
  -----------------
   - No special Rpc connection is maintained, so all cleanup is the job
     of the user
   - No internal connection table. `run` is called on a connection type,
     so you have to manage connections yourself
   - Exposes connection states (unique to each connection) along with
     worker states (shared between connections)
   - There is an explicit `Managed` module that does connection
     management for you
   - There is an explicit `Heartbeater` type that can be used in spawned
     workers to connect to their master and handle cleanup

- There was a race condition where `spawn` would return a `Worker.t` even though the worker had not daemonized yet.
  This manifested itself in a spurious test case failure.

  This also allowed for running the worker initialization code before we daemonize.

- Reuse the master rpc settings when the worker connects using the `Heartbeater` module

- Make all global state and rpc servers lazy.

  Namely:
  1) Toplevel hashtables are initialized with size 1 to reduce overhead due to linking with `Rpc_parallel`
  2) The master rpc server is only started upon the first call to spawn


- Fixed a `Rpc_parallel` bug that caused a Master to Worker call to never return.

- Add new functions `spawn_and_connect` and `spawn_and_connection_exn` which return back the worker and a connection to the worker.

  Also, move all the example code off of the managed module

- Some refactoring:

  1) Take `serve` out of the `Connection` module. It shouldn't be in there because it does nothing with the `Connection.t` type
  2) Remove some unnecessary functions defined on `Connection.t`'s. E.g. no longer expose `close_reason` because all the exception handling will be done with the registered exn handlers.
  3) Move `Rpc_settings` module
  4) Separate `global_state` into `as_worker` and `as_master`
  5) Some cleanup with how we are managing worker ids
  6) create a record type for `Init_connection_state_rpc.query`

## 113.24.00

- Switched to PPX.

- Expose the `connection_timeout` argument in rpc\_parallel. This argument
  exists in `Rpc_parallel_core.Parallel`, but it is not exposed in
  `Rpc_parallel.Parallel`.

- Allow custom handling of missed async\_rpc heartbeats.

- Give a better error message when redirecting output on a remote box to a file
  path that does not exist.

- remove unncessary chmod 700 call on the remote executable

- Give a clear error message for the common mistake of not making the
  `Parallel.Make_worker()` functor application top-level

- Make errors/exceptions in `Rpc_parallel` more observable

  - Make stderr and stdout redirection mandatory in order to encourage logging stderr
  - Clean up the use of monitors across `Rpc_parallel`
  - Fix bug with exceptions that are sent directly to `Monitor.main`
    (e.g. `Async_log` does this)

- Add the ability to explicitly initialize as a master and use some subcommand for the
  worker. This would allow writing programs with complex command structures that don't have
  to invoke a bunch of `Rpc_parallel` logic and start RPC servers for every command.


- Add the ability to get log messages from a worker sent back to the master.
  In fact, any worker can register for the log messages of any other workers.

## 113.00.00

- Fixed a file-descriptor leak

    There was a file descriptor leak when killing workers.  Their stdin,
    stdout, and stderr remain open. We now close them after the worker process
    exits.

## 112.24.00

- Added `Parallel.State.get` function, to check whether `Rpc_parallel` has been
  initialized correctly.
- Added `Map_reduce` module, which is an easy-to-use parallel map/reduce library.

  It can be used to map/fold over a list while utilizing multiple cores on multiple machines.

  Also added support for workers to keep their own inner state.

- Fixed bug in which  zombie process was created per spawned worker.

  Also fixed shutdown on remote workers

- Made it possible for workers to spawn other workers, i.e.  act as masters.

- Made the connection timeout configurable and bumped the default to 10s.

## 112.17.00

- Follow changes in Async RPC

## 112.01.00

Initial import.
