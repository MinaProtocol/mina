open Core_kernel
open Async

module Thread : sig
  type t = Thread.t

  val name : t -> string

  val load_state : t -> 'a Type_equal.Id.t -> 'a option

  val set_state : t -> 'a Type_equal.Id.t -> 'a -> unit

  val iter_threads : f:(t -> unit) -> unit

  val dump_thread_graph : unit -> bytes

  module Fiber : sig
    type t = Thread.Fiber.t = { id : int; parent : t option; thread : Thread.t }
  end
end

module Plugins : module type of Plugins

module Execution_timer : module type of Execution_timer

val background_thread : string -> (unit -> unit Deferred.t) -> unit

val thread : string -> (unit -> 'a Deferred.t) -> 'a Deferred.t

val sync_thread : string -> (unit -> 'a) -> 'a
