open Core
open Async
open Linear_pipe

module type Worker_intf = sig
  type t

  type state

  type input

  val create : input -> t

  val run : t -> unit Deferred.t

  val state_broadcasts : t -> state Pipe.Reader.t Deferred.t
end

module type S = sig
  type t

  type state

  type key

  type input

  val create : unit -> t

  val add : t -> input -> key -> unit

  val run : t -> key -> unit Deferred.t option

  val broadcasts : t -> (key * state) Linear_pipe.Reader.t
end

module Make (Worker : Worker_intf) (Key : Hashable.S_binable) :
  S
  with type state := Worker.state
   and type input := Worker.input
   and type key := Key.t
