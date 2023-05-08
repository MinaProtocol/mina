open Async_kernel
open Pipe_lib
open Frontier_base

module type Extension_base_intf = sig
  type t

  type view

  val name : string

  val create : logger:Logger.t -> Full_frontier.t -> t * view

  (* It is of upmost importance to make this synchronous. To prevent data races via context switching *)
  val handle_diffs :
    t -> Full_frontier.t -> Diff.Full.With_mutant.t list -> view option
end

module type Broadcasted_extension_intf = sig
  type t

  type extension

  type view

  val name : string

  val create : extension * view -> t Deferred.t

  val close : t -> unit

  val extension : t -> extension

  val peek : t -> view

  val reader : t -> view Broadcast_pipe.Reader.t

  val update :
    t -> Full_frontier.t -> Diff.Full.With_mutant.t list -> unit Deferred.t
end

module type Extension_intf = sig
  include Extension_base_intf

  module Broadcasted :
    Broadcasted_extension_intf with type extension = t and type view = view
end
