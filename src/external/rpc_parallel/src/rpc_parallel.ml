open! Core

(** A type-safe parallel library built on top of Async_rpc.

    {[
      module Worker = Rpc_parallel.Make (T : Worker_spec)
    ]}

    The [Worker] module can be used to spawn new workers, either locally or remotely, and
    run functions on these workers. [T] specifies which functions can be run on a
    [Worker.t] as well as the implementations for these functions. In addition, [T]
    specifies worker states and connection states. See README for more details *)

module Remote_executable   = Remote_executable
module Executable_location = Executable_location
module Managed             = Parallel_managed
module Map_reduce          = Map_reduce

include Parallel

(** Old [Std] style interface, which has slightly different module names. *)
module Std = struct end
[@@deprecated "[since 2016-11] Use [Rpc_parallel] instead of [Rpc_parallel.Std]"]

module Parallel = Parallel
[@@deprecated "[since 2016-11] Use [Rpc_parallel] instead of [Rpc_parallel.Parallel]"]

module Parallel_managed = Parallel_managed
[@@deprecated "[since 2016-11] Use [Rpc_parallel.Managed] instead of \
               [Rpc_parallel.Parallel_managed]"]
