open Async_kernel
open Core_kernel
open Mina_base
open Mina_transaction
open Pipe_lib
open Network_peer

(** A [Resource_pool_base_intf] is a mutable pool of resources that supports
 *  mutation via some [Resource_pool_diff_intf]. A [Resource_pool_base_intf]
 *  can only be initialized, and any interaction with it must go through
 *  its [Resource_pool_diff_intf] *)
module type Resource_pool_base_intf = sig
  type t

  val label : string

  type transition_frontier_diff

  type transition_frontier

  module Config : sig
    type t
  end

  (** Diff from a transition frontier extension that would update the resource pool*)
  val handle_transition_frontier_diff : transition_frontier_diff -> t -> unit

  val create :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> consensus_constants:Consensus.Constants.t
    -> time_controller:Block_time.Controller.t
    -> frontier_broadcast_pipe:
         transition_frontier Option.t Broadcast_pipe.Reader.t
    -> config:Config.t
    -> logger:Logger.t
    -> tf_diff_writer:
         ( transition_frontier_diff
         , Strict_pipe.synchronous
         , unit Deferred.t )
         Strict_pipe.Writer.t
    -> t
end

module Verification_error = struct
  type t = Fee_higher | Fee_equal | Invalid of Error.t | Failure of Error.t

  let to_error = function
    | Fee_equal ->
        Error.of_string "fee equal to cheapest work we have"
    | Fee_higher ->
        Error.of_string "fee higher than cheapest work we have"
    | Invalid err ->
        Error.tag err ~tag:"invalid"
    | Failure err ->
        Error.tag err ~tag:"failure"

  let to_short_string = function
    | Fee_equal ->
        "fee_equal"
    | Fee_higher ->
        "fee_higher"
    | Invalid _ ->
        "invalid"
    | Failure _ ->
        "failure"
end

(** A [Resource_pool_diff_intf] is a representation of a mutation to
 *  perform on a [Resource_pool_base_intf]. It includes the logic for
 *  processing this mutation and applying it to an underlying
 *  [Resource_pool_base_intf]. *)
module type Resource_pool_diff_intf = sig
  type pool

  val label : string

  type t

  type verified

  (** Part of the diff that was not added to the resource pool*)
  type rejected

  val empty : t

  val reject_overloaded_diff : verified -> rejected

  (** Used to check whether or not information was filtered out of diffs
   *  during diff application. Assumes that diff size will be the equal or
   *  smaller after application is completed. *)
  val size : t -> int

  (* TODO
     val verified_size : verified -> int
  *)

  (** How big to consider this diff for purposes of metering. *)
  val score : t -> int

  (** The maximum "diff score" permitted per IP/peer-id per 15 seconds. *)
  val max_per_15_seconds : int

  val summary : t -> string

  (** Warning: It must be safe to call this function asynchronously! *)
  val verify :
       pool
    -> t Envelope.Incoming.t
    -> (verified Envelope.Incoming.t, Verification_error.t) Deferred.Result.t

  (** Warning: Using this directly could corrupt the resource pool if it
      conincides with applying locally generated diffs or diffs from the network
      or diffs from transition frontier extensions.*)
  val unsafe_apply :
       pool
    -> verified Envelope.Incoming.t
    -> ( [ `Accept | `Reject ] * t * rejected
       , [ `Locally_generated of t * rejected | `Other of Error.t ] )
       Result.t

  val is_empty : t -> bool

  val update_metrics :
       logger:Logger.t
    -> log_gossip_heard:bool
    -> t Envelope.Incoming.t
    -> Mina_net2.Validation_callback.t
    -> unit

  val log_internal :
    ?reason:string -> logger:Logger.t -> string -> t Envelope.Incoming.t -> unit

  val t_of_verified : verified -> t
end

(** A [Resource_pool_intf] ties together an associated pair of
 *  [Resource_pool_base_intf] and [Resource_pool_diff_intf]. *)
module type Resource_pool_intf = sig
  include Resource_pool_base_intf

  module Diff : Resource_pool_diff_intf with type pool := t

  (** Locally generated items (user commands and snarks) should be periodically
      rebroadcast, to ensure network unreliability doesn't mean they're never
      included in a block. This function gets the locally generated items that
      are currently rebroadcastable. [has_timed_out] is a function that returns
      true if an item that was added at a given time should not be rebroadcast
      anymore. If it does, the implementation should not return that item, and
      remove it from the set of potentially-rebroadcastable item.
  *)
  val get_rebroadcastable :
    t -> has_timed_out:(Time.t -> [ `Timed_out | `Ok ]) -> Diff.t list
end

module type Broadcast_callback = sig
  type resource_pool_diff

  type rejected_diff

  type t =
    | Local of
        (   ( [ `Broadcasted | `Not_broadcasted ]
            * resource_pool_diff
            * rejected_diff )
            Or_error.t
         -> unit )
    | External of Mina_net2.Validation_callback.t

  val drop : resource_pool_diff -> rejected_diff -> t -> unit
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

  type resource_pool_diff_verified

  type rejected_diff

  type transition_frontier_diff

  type config

  type transition_frontier

  module Local_sink :
    Mina_net2.Sink.S_with_void
      with type msg :=
        resource_pool_diff
        * (   ( [ `Broadcasted | `Not_broadcasted ]
              * resource_pool_diff
              * rejected_diff )
              Or_error.t
           -> unit )

  module Remote_sink :
    Mina_net2.Sink.S_with_void
      with type msg :=
        resource_pool_diff Envelope.Incoming.t * Mina_net2.Validation_callback.t

  module Broadcast_callback :
    Broadcast_callback
      with type resource_pool_diff := resource_pool_diff
       and type rejected_diff := rejected_diff

  val create :
       config:config
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> consensus_constants:Consensus.Constants.t
    -> time_controller:Block_time.Controller.t
    -> frontier_broadcast_pipe:
         transition_frontier Option.t Broadcast_pipe.Reader.t
    -> logger:Logger.t
    -> log_gossip_heard:bool
    -> on_remote_push:(unit -> unit Deferred.t)
    -> block_window_duration:Time.Span.t
    -> t * Remote_sink.t * Local_sink.t

  val of_resource_pool_and_diffs :
       resource_pool
    -> logger:Logger.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> tf_diffs:transition_frontier_diff Strict_pipe.Reader.t
    -> log_gossip_heard:bool
    -> on_remote_push:(unit -> unit Deferred.t)
    -> block_window_duration:Time.Span.t
    -> t * Remote_sink.t * Local_sink.t

  val resource_pool : t -> resource_pool

  val broadcasts : t -> resource_pool_diff With_nonce.t Linear_pipe.Reader.t

  val create_rate_limiter : unit -> Rate_limiter.t

  val apply_and_broadcast :
       t
    -> resource_pool_diff_verified Envelope.Incoming.t
    -> Broadcast_callback.t
    -> unit

  val apply_no_broadcast :
    t -> resource_pool_diff_verified Envelope.Incoming.t -> unit
end

(** A [Snark_resource_pool_intf] is a superset of a
 *  [Resource_pool_intf] specifically for handling snarks. *)
module type Snark_resource_pool_intf = sig
  include Resource_pool_base_intf

  val proof_cache_db : t -> Proof_cache_tag.cache_db

  val make_config :
       trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> disk_location:string
    -> proof_cache_db:Proof_cache_tag.cache_db
    -> Config.t

  val add_snark :
       ?is_local:bool
    -> t
    -> work:Transaction_snark_work.Statement.t
    -> proof:Ledger_proof.Cached.t One_or_two.t
    -> fee:Fee_with_prover.t
    -> [ `Added | `Statement_not_referenced ]

  val request_proof :
       t
    -> Transaction_snark_work.Statement.t
    -> Ledger_proof.Cached.t One_or_two.t Priced_proof.t option

  val verify_and_act :
       t
    -> work:
         Transaction_snark_work.Statement.t
         * Ledger_proof.t One_or_two.t Priced_proof.t
    -> sender:Envelope.Sender.t
    -> (unit, Verification_error.t) Deferred.Result.t

  val snark_pool_json : t -> Yojson.Safe.t

  val all_completed_work : t -> Transaction_snark_work.Info.t list

  val get_logger : t -> Logger.t
end

(** A [Snark_pool_diff_intf] is the resource pool diff for
 *  a [Snark_resource_pool_intf]. *)
module type Snark_pool_diff_intf = sig
  type resource_pool

  type t = Mina_wire_types.Network_pool.Snark_pool.Diff_versioned.V2.t =
    | Add_solved_work of
        Transaction_snark_work.Statement.t
        * Ledger_proof.t One_or_two.t Priced_proof.t
    | Empty

  module Cached : sig
    type t =
      | Add_solved_work of
          Transaction_snark_work.Statement.t
          * Ledger_proof.Cached.t One_or_two.t Priced_proof.t
      | Empty

    val read_all_proofs_from_disk :
      t -> Mina_wire_types.Network_pool.Snark_pool.Diff_versioned.V2.t

    val write_all_proofs_to_disk :
         proof_cache_db:Proof_cache_tag.cache_db
      -> Mina_wire_types.Network_pool.Snark_pool.Diff_versioned.V2.t
      -> t
  end

  type verified = Cached.t

  type compact =
    { work_ids : int One_or_two.t
    ; fee : Currency.Fee.t
    ; prover : Signature_lib.Public_key.Compressed.t
    }
  [@@deriving yojson, hash]

  type Structured_log_events.t +=
    | Snark_work_received of { work : compact; sender : Envelope.Sender.t }
    [@@deriving register_event]

  include
    Resource_pool_diff_intf
      with type t := t
       and type verified := Cached.t
       and type pool := resource_pool

  val to_compact : t -> compact option

  val compact_json : t -> Yojson.Safe.t option

  val of_result :
       ( (_, _) Snark_work_lib.Work.Single.Spec.t Snark_work_lib.Work.Spec.t
       , Ledger_proof.t )
       Snark_work_lib.Work.Result.t
    -> t
end

module type Transaction_pool_diff_intf = sig
  type resource_pool

  type t = User_command.Stable.Latest.t list

  module Diff_error : sig
    type t =
      | Insufficient_replace_fee
      | Duplicate
      | Invalid_nonce
      | Insufficient_funds
      | Overflow
      | Bad_token
      | Unwanted_fee_token
      | Expired
      | Overloaded
      | Fee_payer_account_not_found
      | Fee_payer_not_permitted_to_send
      | After_slot_tx_end
    [@@deriving yojson]

    val to_string_hum : t -> string
  end

  module Rejected : sig
    type t = (User_command.Stable.Latest.t * Diff_error.t) list
  end

  type Structured_log_events.t +=
    | Transactions_received of
        { fee_payer_summaries : User_command.fee_payer_summary_t list
        ; sender : Envelope.Sender.t
        }
    [@@deriving register_event]

  include
    Resource_pool_diff_intf
      with type t := t
       and type pool := resource_pool
       and type rejected = Rejected.t
end

module type Transaction_resource_pool_intf = sig
  type t

  include Resource_pool_base_intf with type t := t

  val make_config :
       trust_system:Trust_system.t
    -> pool_max_size:int
    -> verifier:Verifier.t
    -> genesis_constants:Genesis_constants.t
    -> slot_tx_end:Mina_numbers.Global_slot_since_hard_fork.t option
    -> vk_cache_db:Zkapp_vk_cache_tag.cache_db
    -> proof_cache_db:Proof_cache_tag.cache_db
    -> Config.t

  val member : t -> Transaction_hash.t -> bool

  val transactions :
    t -> Transaction_hash.User_command_with_valid_signature.t Sequence.t

  val all_from_account :
       t
    -> Account_id.t
    -> Transaction_hash.User_command_with_valid_signature.t list

  val get_all : t -> Transaction_hash.User_command_with_valid_signature.t list

  val find_by_hash :
       t
    -> Transaction_hash.t
    -> Transaction_hash.User_command_with_valid_signature.t option
end

module type Base_ledger_intf = sig
  type t

  module Location : sig
    type t
  end

  val location_of_account : t -> Account_id.t -> Location.t option

  val location_of_account_batch :
    t -> Account_id.t list -> (Account_id.t * Location.t option) list

  val get : t -> Location.t -> Account.t option

  val accounts : t -> Account_id.Set.t Deferred.t

  val get_batch : t -> Location.t list -> (Location.t * Account.t option) list

  val detached_signal : t -> unit Deferred.t
end
