open Core
open Async
open Linear_pipe

module type Worker_intf = sig
  type t

  type input [@@deriving bin_io]

  type state [@@deriving bin_io]

  val create : input -> t Deferred.t

  val new_states : t -> state Pipe.Reader.t

  val run : t -> unit Deferred.t
end

module type Parallel_worker_intf = sig
  type t

  type input

  type state

  type config

  val create : input -> config -> t Deferred.t

  val new_states : t -> state Pipe.Reader.t Deferred.t

  val run : t -> unit Deferred.t
end

module Make (Worker : Worker_intf) :
  Parallel_worker_intf
  with type input = Worker.input
   and type state = Worker.state
   and type config = (string, string, string) Config.t
