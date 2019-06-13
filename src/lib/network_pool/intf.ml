open Async_kernel
open Core_kernel
open Coda_base
open Pipe_lib

module type Resource_pool_base_intf = sig
  type t [@@deriving sexp]

  type transition_frontier

  val create :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> t
end

module type Resource_pool_diff_intf = sig
  type pool

  type t [@@deriving sexp]

  val summary : t -> string

  val apply : pool -> t Envelope.Incoming.t -> t Deferred.Or_error.t
end

module type Resource_pool_intf = sig
  include Resource_pool_base_intf

  module Diff : Resource_pool_diff_intf with type pool := t
end

module type Network_pool_base_intf = sig
  type t

  type resource_pool

  type resource_pool_diff

  type transition_frontier

  val create :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> incoming_diffs:resource_pool_diff Envelope.Incoming.t
                      Linear_pipe.Reader.t
    -> frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> t

  val of_resource_pool_and_diffs :
       resource_pool
    -> logger:Logger.t
    -> incoming_diffs:resource_pool_diff Envelope.Incoming.t
                      Linear_pipe.Reader.t
    -> t

  val resource_pool : t -> resource_pool

  val broadcasts : t -> resource_pool_diff Linear_pipe.Reader.t

  val apply_and_broadcast :
    t -> resource_pool_diff Envelope.Incoming.t -> unit Deferred.t
end

module type Snark_resource_pool_intf = sig
  type ledger_proof

  type work

  type transition_frontier

  include
    Resource_pool_base_intf
    with type transition_frontier := transition_frontier

  val bin_writer_t : t Bin_prot.Writer.t

  val add_snark :
       t
    -> work:work
    -> proof:ledger_proof list
    -> fee:Fee_with_prover.t
    -> [`Rebroadcast | `Don't_rebroadcast]

  val request_proof : t -> work -> ledger_proof list Priced_proof.t option
end

module type Snark_pool_diff_intf = sig
  type ledger_proof

  type work

  type resource_pool

  module Stable : sig
    module V1 : sig
      type t =
        | Add_solved_work of work * ledger_proof list Priced_proof.Stable.V1.t
      [@@deriving sexp, yojson, bin_io, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, yojson]

  val summary : t -> string

  val apply : resource_pool -> t Envelope.Incoming.t -> t Deferred.Or_error.t
end
