module type Resource_pool_base_intf = sig
  type t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val label : string

  type transition_frontier_diff

  type transition_frontier

  module Config : sig
    type t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  val handle_transition_frontier_diff :
    transition_frontier_diff -> t -> unit Async_kernel.Deferred.t

  val create :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> consensus_constants:Consensus.Constants.t
    -> time_controller:Block_time.Controller.t
    -> frontier_broadcast_pipe:
         transition_frontier Core_kernel.Option.t
         Pipe_lib.Broadcast_pipe.Reader.t
    -> config:Config.t
    -> logger:Logger.t
    -> tf_diff_writer:
         ( transition_frontier_diff
         , Pipe_lib.Strict_pipe.synchronous
         , unit Async_kernel.Deferred.t )
         Pipe_lib.Strict_pipe.Writer.t
    -> t
end

module type Resource_pool_diff_intf = sig
  type pool

  type t

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  type verified

  val verified_to_yojson : verified -> Yojson.Safe.t

  val sexp_of_verified : verified -> Ppx_sexp_conv_lib.Sexp.t

  val verified_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> verified

  type rejected

  val rejected_to_yojson : rejected -> Yojson.Safe.t

  val sexp_of_rejected : rejected -> Ppx_sexp_conv_lib.Sexp.t

  val rejected_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> rejected

  val empty : t

  val reject_overloaded_diff : verified -> rejected

  val size : t -> int

  val verified_size : verified -> int

  val score : t -> int

  val max_per_15_seconds : int

  val summary : t -> string

  val verify :
       pool
    -> t Network_peer.Envelope.Incoming.t
    -> verified Network_peer.Envelope.Incoming.t
       Async_kernel.Deferred.Or_error.t

  val unsafe_apply :
       pool
    -> verified Network_peer.Envelope.Incoming.t
    -> ( t * rejected
       , [ `Locally_generated of t * rejected | `Other of Core_kernel.Error.t ]
       )
       Core_kernel.Result.t
       Async_kernel.Deferred.t

  val is_empty : t -> bool
end

module type Resource_pool_intf = sig
  type t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val label : string

  type transition_frontier_diff

  type transition_frontier

  module Config : sig
    type t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  val handle_transition_frontier_diff :
    transition_frontier_diff -> t -> unit Async_kernel.Deferred.t

  val create :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> consensus_constants:Consensus.Constants.t
    -> time_controller:Block_time.Controller.t
    -> frontier_broadcast_pipe:
         transition_frontier Core_kernel.Option.t
         Pipe_lib.Broadcast_pipe.Reader.t
    -> config:Config.t
    -> logger:Logger.t
    -> tf_diff_writer:
         ( transition_frontier_diff
         , Pipe_lib.Strict_pipe.synchronous
         , unit Async_kernel.Deferred.t )
         Pipe_lib.Strict_pipe.Writer.t
    -> t

  module Diff : sig
    type t_ := t

    type t

    val to_yojson : t -> Yojson.Safe.t

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    type verified

    val verified_to_yojson : verified -> Yojson.Safe.t

    val sexp_of_verified : verified -> Ppx_sexp_conv_lib.Sexp.t

    val verified_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> verified

    type rejected

    val rejected_to_yojson : rejected -> Yojson.Safe.t

    val sexp_of_rejected : rejected -> Ppx_sexp_conv_lib.Sexp.t

    val rejected_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> rejected

    val empty : t

    val reject_overloaded_diff : verified -> rejected

    val size : t -> int

    val verified_size : verified -> int

    val score : t -> int

    val max_per_15_seconds : int

    val summary : t -> string

    val verify :
         t_
      -> t Network_peer.Envelope.Incoming.t
      -> verified Network_peer.Envelope.Incoming.t
         Async_kernel.Deferred.Or_error.t

    val unsafe_apply :
         t_
      -> verified Network_peer.Envelope.Incoming.t
      -> ( t * rejected
         , [ `Locally_generated of t * rejected | `Other of Core_kernel.Error.t ]
         )
         Core_kernel.Result.t
         Async_kernel.Deferred.t

    val is_empty : t -> bool
  end

  val get_rebroadcastable :
       t
    -> has_timed_out:(Core_kernel.Time.t -> [ `Ok | `Timed_out ])
    -> Diff.t list
end

module type Network_pool_base_intf = sig
  type t

  type resource_pool

  type resource_pool_diff

  type resource_pool_diff_verified

  type rejected_diff

  type transition_frontier_diff

  type config

  type transition_frontier

  module Broadcast_callback : sig
    type t =
      | Local of
          ((resource_pool_diff * rejected_diff) Core_kernel.Or_error.t -> unit)
      | External of Mina_net2.Validation_callback.t
  end

  val create :
       config:config
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> consensus_constants:Consensus.Constants.t
    -> time_controller:Block_time.Controller.t
    -> incoming_diffs:
         ( resource_pool_diff Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t
    -> local_diffs:
         ( resource_pool_diff
         * ((resource_pool_diff * rejected_diff) Core_kernel.Or_error.t -> unit)
         )
         Pipe_lib.Strict_pipe.Reader.t
    -> frontier_broadcast_pipe:
         transition_frontier Core_kernel.Option.t
         Pipe_lib.Broadcast_pipe.Reader.t
    -> logger:Logger.t
    -> t

  val of_resource_pool_and_diffs :
       resource_pool
    -> logger:Logger.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> incoming_diffs:
         ( resource_pool_diff Network_peer.Envelope.Incoming.t
         * Mina_net2.Validation_callback.t )
         Pipe_lib.Strict_pipe.Reader.t
    -> local_diffs:
         ( resource_pool_diff
         * ((resource_pool_diff * rejected_diff) Core_kernel.Or_error.t -> unit)
         )
         Pipe_lib.Strict_pipe.Reader.t
    -> tf_diffs:transition_frontier_diff Pipe_lib.Strict_pipe.Reader.t
    -> t

  val resource_pool : t -> resource_pool

  val broadcasts : t -> resource_pool_diff Pipe_lib.Linear_pipe.Reader.t

  val create_rate_limiter : unit -> Rate_limiter.t

  val apply_and_broadcast :
       t
    -> resource_pool_diff_verified Network_peer.Envelope.Incoming.t
    -> Broadcast_callback.t
    -> unit Async_kernel.Deferred.t
end

module type Snark_resource_pool_intf = sig
  type t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val label : string

  type transition_frontier_diff

  type transition_frontier

  module Config : sig
    type t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  val handle_transition_frontier_diff :
    transition_frontier_diff -> t -> unit Async_kernel.Deferred.t

  val create :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> consensus_constants:Consensus.Constants.t
    -> time_controller:Block_time.Controller.t
    -> frontier_broadcast_pipe:
         transition_frontier Core_kernel.Option.t
         Pipe_lib.Broadcast_pipe.Reader.t
    -> config:Config.t
    -> logger:Logger.t
    -> tf_diff_writer:
         ( transition_frontier_diff
         , Pipe_lib.Strict_pipe.synchronous
         , unit Async_kernel.Deferred.t )
         Pipe_lib.Strict_pipe.Writer.t
    -> t

  val make_config :
       trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> disk_location:string
    -> Config.t

  val add_snark :
       ?is_local:bool
    -> t
    -> work:Transaction_snark_work.Statement.t
    -> proof:Ledger_proof.t One_or_two.t
    -> fee:Mina_base.Fee_with_prover.t
    -> [ `Added | `Statement_not_referenced ] Async_kernel.Deferred.t

  val request_proof :
       t
    -> Transaction_snark_work.Statement.t
    -> Ledger_proof.t One_or_two.t Priced_proof.t option

  val verify_and_act :
       t
    -> work:
         Transaction_snark_work.Statement.t
         * Ledger_proof.t One_or_two.t Priced_proof.t
    -> sender:Network_peer.Envelope.Sender.t
    -> bool Async_kernel.Deferred.t

  val snark_pool_json : t -> Yojson.Safe.t

  val all_completed_work : t -> Transaction_snark_work.Info.t list

  val get_logger : t -> Logger.t
end

module type Snark_pool_diff_intf = sig
  type resource_pool

  type t =
    | Add_solved_work of
        Transaction_snark_work.Statement.t
        * Ledger_proof.t One_or_two.t Priced_proof.t
    | Empty

  val compare : t -> t -> int

  type verified = t

  val compare_verified : verified -> verified -> int

  type compact =
    { work : Transaction_snark_work.Statement.t
    ; fee : Currency.Fee.t
    ; prover : Signature_lib.Public_key.Compressed.t
    }

  val compact_to_yojson : compact -> Yojson.Safe.t

  val compact_of_yojson :
    Yojson.Safe.t -> compact Ppx_deriving_yojson_runtime.error_or

  val hash_fold_compact :
    Ppx_hash_lib.Std.Hash.state -> compact -> Ppx_hash_lib.Std.Hash.state

  val hash_compact : compact -> Ppx_hash_lib.Std.Hash.hash_value

  val to_yojson : verified -> Yojson.Safe.t

  val t_of_sexp : Sexplib0.Sexp.t -> verified

  val sexp_of_t : verified -> Sexplib0.Sexp.t

  val verified_to_yojson : verified -> Yojson.Safe.t

  val sexp_of_verified : verified -> Ppx_sexp_conv_lib.Sexp.t

  val verified_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> verified

  type rejected

  val rejected_to_yojson : rejected -> Yojson.Safe.t

  val sexp_of_rejected : rejected -> Ppx_sexp_conv_lib.Sexp.t

  val rejected_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> rejected

  val empty : verified

  val reject_overloaded_diff : verified -> rejected

  val size : verified -> int

  val verified_size : verified -> int

  val score : verified -> int

  val max_per_15_seconds : int

  val summary : verified -> string

  val verify :
       resource_pool
    -> verified Network_peer.Envelope.Incoming.t
    -> verified Network_peer.Envelope.Incoming.t
       Async_kernel.Deferred.Or_error.t

  val unsafe_apply :
       resource_pool
    -> verified Network_peer.Envelope.Incoming.t
    -> ( verified * rejected
       , [ `Locally_generated of verified * rejected
         | `Other of Core_kernel.Error.t ] )
       Core_kernel.Result.t
       Async_kernel.Deferred.t

  val is_empty : verified -> bool

  val to_compact : verified -> compact option

  val compact_json : verified -> Yojson.Safe.t option

  val of_result :
       ( ('a, 'b, 'c) Snark_work_lib.Work.Single.Spec.t
         Snark_work_lib.Work.Spec.t
       , Ledger_proof.t )
       Snark_work_lib.Work.Result.t
    -> verified
end

module type Transaction_pool_diff_intf = sig
  type resource_pool

  type t = Mina_base.User_command.t list

  val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

  module Diff_error : sig
    type t =
      | Insufficient_replace_fee
      | Invalid_signature
      | Duplicate
      | Sender_account_does_not_exist
      | Invalid_nonce
      | Insufficient_funds
      | Insufficient_fee
      | Overflow
      | Bad_token
      | Unwanted_fee_token
      | Expired
      | Overloaded

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t

    val to_string_hum : t -> string
  end

  module Rejected : sig
    type t = (Mina_base.User_command.t * Diff_error.t) list

    val to_yojson : t -> Yojson.Safe.t

    val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

    val t_of_sexp : Sexplib0.Sexp.t -> t

    val sexp_of_t : t -> Sexplib0.Sexp.t
  end

  val to_yojson : t -> Yojson.Safe.t

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  type verified

  val verified_to_yojson : verified -> Yojson.Safe.t

  val sexp_of_verified : verified -> Ppx_sexp_conv_lib.Sexp.t

  val verified_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> verified

  type rejected = Rejected.t

  val rejected_to_yojson : rejected -> Yojson.Safe.t

  val sexp_of_rejected : rejected -> Ppx_sexp_conv_lib.Sexp.t

  val rejected_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> rejected

  val empty : t

  val reject_overloaded_diff : verified -> rejected

  val size : t -> int

  val verified_size : verified -> int

  val score : t -> int

  val max_per_15_seconds : int

  val summary : t -> string

  val verify :
       resource_pool
    -> t Network_peer.Envelope.Incoming.t
    -> verified Network_peer.Envelope.Incoming.t
       Async_kernel.Deferred.Or_error.t

  val unsafe_apply :
       resource_pool
    -> verified Network_peer.Envelope.Incoming.t
    -> ( t * rejected
       , [ `Locally_generated of t * rejected | `Other of Core_kernel.Error.t ]
       )
       Core_kernel.Result.t
       Async_kernel.Deferred.t

  val is_empty : t -> bool
end

module type Transaction_resource_pool_intf = sig
  type t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val label : string

  type transition_frontier_diff

  type transition_frontier

  module Config : sig
    type t

    val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
  end

  val handle_transition_frontier_diff :
    transition_frontier_diff -> t -> unit Async_kernel.Deferred.t

  val create :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> consensus_constants:Consensus.Constants.t
    -> time_controller:Block_time.Controller.t
    -> frontier_broadcast_pipe:
         transition_frontier Core_kernel.Option.t
         Pipe_lib.Broadcast_pipe.Reader.t
    -> config:Config.t
    -> logger:Logger.t
    -> tf_diff_writer:
         ( transition_frontier_diff
         , Pipe_lib.Strict_pipe.synchronous
         , unit Async_kernel.Deferred.t )
         Pipe_lib.Strict_pipe.Writer.t
    -> t

  val make_config :
       trust_system:Trust_system.t
    -> pool_max_size:int
    -> verifier:Verifier.t
    -> Config.t

  val member :
    t -> Mina_base.Transaction_hash.User_command_with_valid_signature.t -> bool

  val transactions :
       logger:Logger.t
    -> t
    -> Mina_base.Transaction_hash.User_command_with_valid_signature.t
       Core_kernel.Sequence.t

  val all_from_account :
       t
    -> Mina_base.Account_id.t
    -> Mina_base.Transaction_hash.User_command_with_valid_signature.t list

  val get_all :
    t -> Mina_base.Transaction_hash.User_command_with_valid_signature.t list

  val find_by_hash :
       t
    -> Mina_base.Transaction_hash.t
    -> Mina_base.Transaction_hash.User_command_with_valid_signature.t option
end

module type Base_ledger_intf = sig
  type t

  module Location : sig
    type t
  end

  val location_of_account : t -> Mina_base.Account_id.t -> Location.t option

  val location_of_account_batch :
       t
    -> Mina_base.Account_id.t list
    -> (Mina_base.Account_id.t * Location.t option) list

  val get : t -> Location.t -> Mina_base.Account.t option

  val get_batch :
    t -> Location.t list -> (Location.t * Mina_base.Account.t option) list

  val detached_signal : t -> unit Async_kernel.Deferred.t
end
