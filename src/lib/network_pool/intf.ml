open Async_kernel
open Core_kernel
open Coda_base
open Pipe_lib
open Signature_lib
open Network_peer

(** A [Resource_pool_base_intf] is a mutable pool of resources that supports
 *  mutation via some [Resource_pool_diff_intf]. A [Resource_pool_base_intf]
 *  can only be initialized, and any interaction with it must go through
 *  its [Resource_pool_diff_intf] *)
module type Resource_pool_base_intf = sig
  type t [@@deriving sexp_of]

  type transition_frontier

  module Config : sig
    type t [@@deriving sexp_of]
  end

  val create :
       frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> config:Config.t
    -> logger:Logger.t
    -> t
end

(** A [Resource_pool_diff_intf] is a representation of a mutation to
 *  perform on a [Resource_pool_base_intf]. It includes the logic for
 *  processing this mutation and applying it to an underlying
 *  [Resource_pool_base_intf]. *)
module type Resource_pool_diff_intf = sig
  type pool

  type t [@@deriving sexp, to_yojson]

  val summary : t -> string

  val apply :
       pool
    -> t Envelope.Incoming.t
    -> (t, [`Locally_generated of t | `Other of Error.t]) Result.t Deferred.t
end

(** A [Resource_pool_intf] ties together an associated pair of
 *  [Resource_pool_base_intf] and [Resource_pool_diff_intf]. *)
module type Resource_pool_intf = sig
  include Resource_pool_base_intf

  module Diff : Resource_pool_diff_intf with type pool := t

  (** Locally generated items (user commands and snarks) should be periodically
      rebroadcast, to ensure network unreliability doesn't mean they're never
      included in a block. This function gets the locally generated items that
      are currently rebroadcastable. [is_expired] is a function that returns
      true if an item that was added at a given time should not be rebroadcast
      anymore. If it does, the implementation should not return that item, and
      remove it from the set of potentially-rebroadcastable item.
  *)
  val get_rebroadcastable :
    t -> is_expired:(Time.t -> [`Expired | `Ok]) -> Diff.t list
end

(** A [Network_pool_base_intf] is the core implementation of a
 *  network pool on top of a [Resource_pool_intf]. It wraps
 *  some [Resource_pool_intf] and provides a generic interface
 *  for interacting with the [Resource_pool_intf] using the
 *  network. A [Network_pool_base_intf] wires the [Resource_pool_intf]
 *  into the network using pipes of diffs and transition frontiers.
 *  It also provides a way to apply new diffs and rebroadcast them
 *  to the network if necessary. *)
module type Network_pool_base_intf = sig
  type t

  type resource_pool

  type resource_pool_diff

  type config

  type transition_frontier

  val create :
       config:config
    -> incoming_diffs:(resource_pool_diff Envelope.Incoming.t * (bool -> unit))
                      Linear_pipe.Reader.t
    -> frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> logger:Logger.t
    -> t

  val of_resource_pool_and_diffs :
       resource_pool
    -> logger:Logger.t
    -> incoming_diffs:(resource_pool_diff Envelope.Incoming.t * (bool -> unit))
                      Linear_pipe.Reader.t
    -> t

  val resource_pool : t -> resource_pool

  val broadcasts : t -> resource_pool_diff Linear_pipe.Reader.t

  val apply_and_broadcast :
       t
    -> resource_pool_diff Envelope.Incoming.t * (bool -> unit)
    -> unit Deferred.t
end

(** A [Snark_resource_pool_intf] is a superset of a
 *  [Resource_pool_intf] specifically for handling snarks. *)
module type Snark_resource_pool_intf = sig
  type ledger_proof

  type work

  type transition_frontier

  type work_info

  include
    Resource_pool_base_intf
    with type transition_frontier := transition_frontier

  val make_config :
    trust_system:Trust_system.t -> verifier:Verifier.t -> Config.t

  type serializable [@@deriving bin_io]

  val of_serializable : serializable -> config:Config.t -> logger:Logger.t -> t

  val add_snark :
       ?is_local:bool
    -> t
    -> work:work
    -> proof:ledger_proof One_or_two.t
    -> fee:Fee_with_prover.t
    -> [`Added | `Statement_not_referenced]

  val verify_and_act :
       t
    -> work:work * ledger_proof One_or_two.t Priced_proof.t
    -> sender:Envelope.Sender.t
    -> unit Deferred.Or_error.t

  val request_proof :
    t -> work -> ledger_proof One_or_two.t Priced_proof.t option

  val snark_pool_json : t -> Yojson.Safe.json

  val all_completed_work : t -> work_info list

  val get_logger : t -> Logger.t
end

(** A [Snark_pool_diff_intf] is the resource pool diff for
 *  a [Snark_resource_pool_intf]. *)
module type Snark_pool_diff_intf = sig
  type ledger_proof

  type work

  type resource_pool

  module Stable : sig
    module V1 : sig
      type t =
        | Add_solved_work of
            work * ledger_proof One_or_two.Stable.V1.t Priced_proof.Stable.V1.t
      [@@deriving bin_io, compare, sexp, to_yojson, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving compare, sexp, to_yojson]

  val summary : t -> string

  val compact_json : t -> Yojson.Safe.json

  val apply :
       resource_pool
    -> t Envelope.Incoming.t
    -> (t, [`Locally_generated of t | `Other of Error.t]) Result.t Deferred.t
end

module type Transaction_pool_diff_intf = sig
  module Stable : sig
    module V1 : sig
      type t = User_command.Stable.V1.t list
      [@@deriving sexp, to_yojson, bin_io, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]
end

module type Transaction_resource_pool_intf = sig
  type t

  type best_tip_diff

  type transition_frontier

  include
    Resource_pool_base_intf
    with type transition_frontier := transition_frontier
     and type t := t

  val make_config : trust_system:Trust_system.t -> Config.t

  val member : t -> User_command.With_valid_signature.t -> bool

  val transactions : t -> User_command.With_valid_signature.t Sequence.t

  val all_from_user :
    t -> Public_key.Compressed.t -> User_command.With_valid_signature.t list
end
