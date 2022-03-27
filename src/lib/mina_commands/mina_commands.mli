val txn_count : int Core.ref

val get_account :
     Mina_lib.t
  -> Mina_base.Account_id.t
  -> Mina_base.Account.t Base__Option.t Participating_state.T.t

val get_accounts :
  Mina_lib.t -> Mina_base.Account.t list Participating_state.T.t

val string_of_public_key : Mina_base.Account.t -> string

val get_public_keys : Mina_lib.t -> string list Participating_state.T.t

val get_keys_with_details :
  Mina_lib.t -> (string * int * int) list Participating_state.T.t

val get_nonce :
     Mina_lib.t
  -> Mina_base.Account_id.t
  -> Mina_numbers.Account_nonce.Stable.V1.t Participating_state.Option.T.t

val get_balance :
     Mina_lib.t
  -> Mina_base.Account_id.t
  -> Currency.Balance.Stable.V1.t Participating_state.Option.T.t

val get_trust_status :
     Mina_lib.t
  -> Async.Unix.Inet_addr.Blocking_sexp.t
  -> (Network_peer.Peer.t * Trust_system__.Peer_status.t) list

val get_trust_status_all :
  Mina_lib.t -> (Network_peer.Peer.t * Trust_system__.Peer_status.t) list

val reset_trust_status :
     Mina_lib.t
  -> Async.Unix.Inet_addr.Blocking_sexp.t
  -> (Network_peer.Peer.t * Trust_system__.Peer_status.t) list

val setup_and_submit_user_command :
     Mina_lib.t
  -> User_command_input.t
  -> (Mina_base.Signed_command.Stable.V1.t, Core.Error.t) Core._result
     Async.Deferred.t
     Participating_state.T.t

val setup_and_submit_user_commands :
     Mina_lib.t
  -> User_command_input.t list
  -> ( Network_pool.Transaction_pool.Resource_pool.Diff.t
     * Network_pool.Transaction_pool.Resource_pool.Diff.Rejected.t )
     Async_kernel.Deferred.Or_error.t
     Participating_state.T.t

module Receipt_chain_verifier : sig
  val verify :
       init:Mina_base.Receipt.Chain_hash.t
    -> Mina_base.User_command.t list
    -> Mina_base.Receipt.Chain_hash.t
    -> Mina_base.Receipt.Chain_hash.t Non_empty_list.t option
end

val chain_id_inputs :
  Mina_lib.t -> Data_hash_lib.State_hash.t * Genesis_constants.t * string list

val verify_payment :
     Mina_lib.t
  -> Mina_base.Account_id.t
  -> Mina_base.User_command.t
  -> Mina_base.Receipt.Chain_hash.t * Mina_base.User_command.t list
  -> unit Base__Or_error.t Participating_state.T.t

type active_state_fields =
  { num_accounts : int option
  ; blockchain_length : int option
  ; ledger_merkle_root : string option
  ; state_hash : string option
  ; consensus_time_best_tip : Consensus.Data.Consensus_time.t option
  ; global_slot_since_genesis_best_tip : int option
  }

val max_block_height : int Core.ref

val get_status :
     flag:[< `None | `Performance ]
  -> Mina_lib.t
  -> Daemon_rpcs.Types.Status.t Async_kernel__Deferred.t

val clear_hist_status :
     flag:[< `None | `Performance ]
  -> Mina_lib.t
  -> Daemon_rpcs.Types.Status.t Async_kernel__Deferred.t

module Subscriptions : sig
  val new_block :
       Mina_lib.t
    -> Mina_lib.Subscriptions.Optional_public_key.Table.key
       Core_kernel.Hashtbl.key
    -> (Filtered_external_transition.t, Mina_base.State_hash.t) With_hash.t
       Async_kernel.Pipe.Reader.t

  val reorganization : Mina_lib.t -> [ `Changed ] Async_kernel.Pipe.Reader.t
end

module For_tests : sig
  module Subscriptions : sig
    val new_user_commands :
         Mina_lib.t
      -> Mina_base.Account.key
      -> Mina_base.Signed_command.t Async_kernel.Pipe.Reader.t
  end
end
