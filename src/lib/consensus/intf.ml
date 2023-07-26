open Core_kernel
open Mina_numbers
open Async
open Currency
open Signature_lib
open Mina_base

module type CONTEXT = sig
  val logger : Logger.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Constants.t
end

module type Constants = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t
    end
  end]

  val create : protocol_constants:Genesis_constants.Protocol.t -> t

  val gc_parameters :
       t
    -> [ `Acceptable_network_delay of Length.t ]
       * [ `Gc_width of Length.t ]
       * [ `Gc_width_epoch of Length.t ]
       * [ `Gc_width_slot of Length.t ]
       * [ `Gc_interval of Length.t ]
end

module type Blockchain_state = sig
  module Poly : sig
    type ( 'staged_ledger_hash
         , 'snarked_ledger_hash
         , 'local_state
         , 'time
         , 'body_reference
         , 'signed_amount
         , 'pending_coinbase_stack
         , 'fee_excess
         , 'sok_digest )
         t
    [@@deriving sexp]
  end

  module Value : sig
    type t =
      ( Staged_ledger_hash.t
      , Frozen_ledger_hash.t
      , Mina_transaction_logic.Zkapp_command_logic.Local_state.Value.t
      , Block_time.t
      , Body_reference.t
      , Amount.Signed.t
      , Pending_coinbase.Stack_versioned.Stable.V1.t
      , Fee_excess.Stable.V1.t
      , unit )
      Poly.t
    [@@deriving sexp]
  end

  type var =
    ( Staged_ledger_hash.var
    , Frozen_ledger_hash.var
    , Mina_transaction_logic.Zkapp_command_logic.Local_state.Checked.t
    , Block_time.Checked.t
    , Body_reference.var
    , Currency.Amount.Signed.var
    , Pending_coinbase.Stack.var
    , Fee_excess.var
    , unit )
    Poly.t

  val staged_ledger_hash :
    ('staged_ledger_hash, _, _, _, _, _, _, _, _) Poly.t -> 'staged_ledger_hash

  val snarked_ledger_hash :
    (_, 'frozen_ledger_hash, _, _, _, _, _, _, _) Poly.t -> 'frozen_ledger_hash

  val genesis_ledger_hash :
    (_, 'frozen_ledger_hash, _, _, _, _, _, _, _) Poly.t -> 'frozen_ledger_hash

  val timestamp : (_, _, _, 'time, _, _, _, _, _) Poly.t -> 'time

  val body_reference :
    (_, _, _, _, 'body_reference, _, _, _, _) Poly.t -> 'body_reference
end

module type Protocol_state = sig
  type blockchain_state

  type blockchain_state_var

  type consensus_state

  type consensus_state_var

  module Poly : sig
    type ('state_hash, 'body) t [@@deriving equal, hash, sexp, to_yojson]
  end

  module Body : sig
    module Poly : sig
      type ('state_hash, 'blockchain_state, 'consensus_state, 'constants) t
      [@@deriving sexp]
    end

    module Value : sig
      type t =
        ( State_hash.t
        , blockchain_state
        , consensus_state
        , Protocol_constants_checked.Value.Stable.V1.t )
        Poly.t
      [@@deriving sexp, to_yojson]
    end

    type var =
      ( State_hash.var
      , blockchain_state_var
      , consensus_state_var
      , Protocol_constants_checked.var )
      Poly.t
  end

  module Value : sig
    type t = (State_hash.t, Body.Value.t) Poly.t
    [@@deriving sexp, equal, compare]
  end

  type var = (State_hash.var, Body.var) Poly.t

  val create_value :
       previous_state_hash:State_hash.t
    -> genesis_state_hash:State_hash.t
    -> blockchain_state:blockchain_state
    -> consensus_state:consensus_state
    -> constants:Protocol_constants_checked.Value.t
    -> Value.t

  val previous_state_hash : ('state_hash, _) Poly.t -> 'state_hash

  val body : (_, 'body) Poly.t -> 'body

  val blockchain_state :
    (_, (_, 'blockchain_state, _, _) Body.Poly.t) Poly.t -> 'blockchain_state

  val genesis_state_hash :
    ?state_hash:State_hash.t option -> Value.t -> State_hash.t

  val consensus_state :
    (_, (_, _, 'consensus_state, _) Body.Poly.t) Poly.t -> 'consensus_state

  val constants : (_, (_, _, _, 'constants) Body.Poly.t) Poly.t -> 'constants

  val hash : Value.t -> State_hash.t
end

module type Snark_transition = sig
  type blockchain_state_var

  type consensus_transition_var

  module Poly : sig
    type ('blockchain_state, 'consensus_transition, 'pending_coinbase_update) t
    [@@deriving sexp]
  end

  module Value : sig
    type t [@@deriving sexp]
  end

  type var =
    ( blockchain_state_var
    , consensus_transition_var
    , Pending_coinbase.Update.var )
    Poly.t

  val consensus_transition :
    (_, 'consensus_transition, _) Poly.t -> 'consensus_transition

  val blockchain_state : ('blockchain_state, _, _) Poly.t -> 'blockchain_state
end

module type State_hooks = sig
  type consensus_state

  type consensus_state_var

  type consensus_transition

  type block_data

  type blockchain_state

  type protocol_state

  type protocol_state_var

  type snark_transition_var

  (**
   * Generate a new protocol state and consensus specific transition data
   * for a new transition. Called from the block producer in order to generate
   * a new transition to broadcast to the network. Returns `None` if a new
   * transition cannot be generated.
  *)
  val generate_transition :
       previous_protocol_state:protocol_state
    -> blockchain_state:blockchain_state
    -> current_time:Unix_timestamp.t
    -> block_data:block_data
    -> supercharge_coinbase:bool
    -> snarked_ledger_hash:Mina_base.Frozen_ledger_hash.t
    -> genesis_ledger_hash:Mina_base.Frozen_ledger_hash.t
    -> supply_increase:Currency.Amount.Signed.t
    -> logger:Logger.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> protocol_state * consensus_transition

  (**
   * Create a constrained, checked var for the next consensus state of
   * a given consensus state and snark transition.
  *)
  val next_state_checked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> prev_state:protocol_state_var
    -> prev_state_hash:Mina_base.State_hash.var
    -> snark_transition_var
    -> Currency.Amount.Signed.var
    -> ([ `Success of Snark_params.Tick.Boolean.var ] * consensus_state_var)
       Snark_params.Tick.Checked.t

  val genesis_winner : Public_key.Compressed.t * Private_key.t

  module For_tests : sig
    val gen_consensus_state :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> constants:Constants.t
      -> gen_slot_advancement:int Quickcheck.Generator.t
      -> (   previous_protocol_state:
               protocol_state Mina_base.State_hash.With_state_hashes.t
          -> snarked_ledger_hash:Mina_base.Frozen_ledger_hash.t
          -> coinbase_receiver:Public_key.Compressed.t
          -> supercharge_coinbase:bool
          -> consensus_state )
         Quickcheck.Generator.t
  end
end

module type S = sig
  val name : string

  (** Return a string that tells a human what the consensus view of an instant in time is.
    *
    * This is mostly useful for PoStake and other consensus mechanisms that have their own
    * notions of time.
  *)
  val time_hum : constants:Constants.t -> Block_time.t -> string

  module Constants = Constants

  module Configuration : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t =
          { delta : int
          ; k : int
          ; slots_per_epoch : int
          ; slot_duration : int
          ; epoch_duration : int
          ; genesis_state_timestamp : Block_time.Stable.V1.t
          ; acceptable_network_delay : int
          }
        [@@deriving yojson, fields]
      end
    end]

    val t :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> protocol_constants:Genesis_constants.Protocol.t
      -> t
  end

  module Genesis_epoch_data : sig
    module Data : sig
      type t =
        { ledger : Mina_ledger.Ledger.t Lazy.t; seed : Mina_base.Epoch_seed.t }
    end

    type tt = { staking : Data.t; next : Data.t option }

    type t = tt option

    val for_unit_tests : t

    val compiled : t
  end

  module Data : sig
    module Local_state : sig
      module Snapshot : sig
        type t

        module Ledger_snapshot : sig
          type t =
            | Genesis_epoch_ledger of Mina_ledger.Ledger.t
            | Ledger_db of Mina_ledger.Ledger.Db.t

          val close : t -> unit

          val merkle_root : t -> Mina_base.Ledger_hash.t
        end
      end

      type t [@@deriving to_yojson]

      val create :
           Signature_lib.Public_key.Compressed.Set.t
        -> context:(module CONTEXT)
        -> genesis_ledger:Mina_ledger.Ledger.t Lazy.t
        -> genesis_epoch_data:Genesis_epoch_data.t
        -> epoch_ledger_location:string
        -> genesis_state_hash:State_hash.t
        -> t

      val current_block_production_keys :
        t -> Signature_lib.Public_key.Compressed.Set.t

      val current_epoch_delegatee_table :
           local_state:t
        -> Mina_base.Account.t Mina_base.Account.Index.Table.t
           Public_key.Compressed.Table.t

      val last_epoch_delegatee_table :
           local_state:t
        -> Mina_base.Account.t Mina_base.Account.Index.Table.t
           Public_key.Compressed.Table.t
           option

      val next_epoch_ledger : t -> Snapshot.Ledger_snapshot.t

      val staking_epoch_ledger : t -> Snapshot.Ledger_snapshot.t

      (** Swap in a new set of block production keys and invalidate and/or
          recompute cached data *)
      val block_production_keys_swap :
           constants:Constants.t
        -> t
        -> Signature_lib.Public_key.Compressed.Set.t
        -> Block_time.t
        -> unit

      module For_tests : sig
        type snapshot_identifier =
          | Staking_epoch_snapshot
          | Next_epoch_snapshot

        (* set epoch ledgers in local state for testing
           relies on persnickety imperative code that should not be exposed more generally
        *)
        val set_snapshot : t -> snapshot_identifier -> Snapshot.t -> unit

        (* snapshot with empty delegatee table *)
        val snapshot_of_ledger : Snapshot.Ledger_snapshot.t -> Snapshot.t
      end
    end

    module Vrf : sig
      val check :
           context:(module CONTEXT)
        -> global_slot:Mina_numbers.Global_slot_since_hard_fork.t
        -> seed:Mina_base.Epoch_seed.t
        -> producer_private_key:Signature_lib.Private_key.t
        -> producer_public_key:Signature_lib.Public_key.Compressed.t
        -> total_stake:Amount.t
        -> get_delegators:
             (   Public_key.Compressed.t
              -> Mina_base.Account.t Mina_base.Account.Index.Table.t option )
        -> ( ( [ `Vrf_eval of string ]
             * [> `Vrf_output of Consensus_vrf.Output_hash.t ]
             * [> `Delegator of
                  Signature_lib.Public_key.Compressed.t
                  * Mina_base.Account.Index.t ] )
             option
           , unit )
           Interruptible.t
    end

    module Prover_state : sig
      [%%versioned:
      module Stable : sig
        [@@@no_toplevel_latest_type]

        module V2 : sig
          type t

          val to_latest : t -> t
        end
      end]

      type t = Stable.Latest.t [@@deriving to_yojson, sexp]

      val genesis_data : genesis_epoch_ledger:Mina_ledger.Ledger.t Lazy.t -> t

      val precomputed_handler :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> genesis_epoch_ledger:Mina_ledger.Ledger.t Lazy.t
        -> Snark_params.Tick.Handler.t

      val handler :
           t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> pending_coinbase:Mina_base.Pending_coinbase_witness.t
        -> Snark_params.Tick.Handler.t

      val ledger_depth : t -> int
    end

    module Consensus_transition : sig
      module Value : sig
        [%%versioned:
        module Stable : sig
          module V1 : sig
            type t [@@deriving sexp, to_yojson]
          end
        end]
      end

      include Snark_params.Tick.Snarkable.S with type value := Value.t

      val genesis : Value.t
    end

    module Consensus_time : sig
      [%%versioned:
      module Stable : sig
        module V1 : sig
          type t [@@deriving compare, sexp, yojson]
        end
      end]

      val to_string_hum : t -> string

      val to_time : constants:Constants.t -> t -> Block_time.t

      val of_time_exn : constants:Constants.t -> Block_time.t -> t

      (** Gets the corresponding a reasonable consensus time that is considered to be "old" and not accepted by other peers by the consensus mechanism *)
      val get_old : constants:Constants.t -> t -> t

      val to_uint32 : t -> Unsigned.UInt32.t

      val epoch : t -> Unsigned.UInt32.t

      val slot : t -> Unsigned.UInt32.t

      val succ : t -> t

      val start_time : constants:Constants.t -> t -> Block_time.t

      val end_time : constants:Constants.t -> t -> Block_time.t

      val to_global_slot : t -> Mina_numbers.Global_slot_since_hard_fork.t

      val of_global_slot :
        constants:Constants.t -> Mina_numbers.Global_slot_since_hard_fork.t -> t

      val zero : constants:Constants.t -> t
    end

    module Consensus_state : sig
      module Value : sig
        [%%versioned:
        module Stable : sig
          module V2 : sig
            type t [@@deriving hash, equal, compare, sexp, yojson]
          end
        end]

        module For_tests : sig
          val with_global_slot_since_genesis :
            t -> Mina_numbers.Global_slot_since_genesis.t -> t
        end
      end

      type display [@@deriving yojson]

      type var

      val typ :
           constraint_constants:Genesis_constants.Constraint_constants.t
        -> (var, Value.t) Snark_params.Tick.Typ.t

      val negative_one :
           genesis_ledger:Mina_ledger.Ledger.t Lazy.t
        -> genesis_epoch_data:Genesis_epoch_data.t
        -> constants:Constants.t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> Value.t

      val create_genesis_from_transition :
           negative_one_protocol_state_hash:Mina_base.State_hash.t
        -> consensus_transition:Consensus_transition.Value.t
        -> genesis_ledger:Mina_ledger.Ledger.t Lazy.t
        -> genesis_epoch_data:Genesis_epoch_data.t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> constants:Constants.t
        -> Value.t

      val create_genesis :
           negative_one_protocol_state_hash:Mina_base.State_hash.t
        -> genesis_ledger:Mina_ledger.Ledger.t Lazy.t
        -> genesis_epoch_data:Genesis_epoch_data.t
        -> constraint_constants:Genesis_constants.Constraint_constants.t
        -> constants:Constants.t
        -> Value.t

      open Snark_params.Tick

      val var_to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t

      val to_input : Value.t -> Field.t Random_oracle.Input.Chunked.t

      val display : Value.t -> display

      val consensus_time : Value.t -> Consensus_time.t

      val blockchain_length : Value.t -> Length.t

      val min_window_density : Value.t -> Length.t

      val sub_window_densities : Value.t -> Length.t list

      val block_stake_winner : Value.t -> Public_key.Compressed.t

      val last_vrf_output : Value.t -> string

      val block_creator : Value.t -> Public_key.Compressed.t

      val coinbase_receiver : Value.t -> Public_key.Compressed.t

      val coinbase_receiver_var : var -> Public_key.Compressed.var

      val curr_global_slot_var : var -> Global_slot_since_hard_fork.Checked.t

      val blockchain_length_var : var -> Length.Checked.t

      val min_window_density_var : var -> Length.Checked.t

      val total_currency_var : var -> Amount.Checked.t

      val staking_epoch_data_var : var -> Mina_base.Epoch_data.var

      val staking_epoch_data : Value.t -> Mina_base.Epoch_data.Value.t

      val next_epoch_data_var : var -> Mina_base.Epoch_data.var

      val next_epoch_data : Value.t -> Mina_base.Epoch_data.Value.t

      val graphql_type : unit -> ('ctx, Value.t option) Graphql_async.Schema.typ

      val curr_slot : Value.t -> Slot.t

      val epoch_count : Value.t -> Length.t

      val curr_global_slot :
        Value.t -> Mina_numbers.Global_slot_since_hard_fork.t

      val total_currency : Value.t -> Amount.t

      val global_slot_since_genesis :
        Value.t -> Mina_numbers.Global_slot_since_genesis.t

      val global_slot_since_genesis_var :
        var -> Mina_numbers.Global_slot_since_genesis.Checked.t

      val is_genesis_state : Value.t -> bool

      val is_genesis_state_var : var -> Boolean.var Checked.t

      val supercharge_coinbase_var : var -> Boolean.var

      val supercharge_coinbase : Value.t -> bool
    end

    module Block_data : sig
      type t

      val epoch_ledger : t -> Mina_ledger.Sparse_ledger.t

      val global_slot : t -> Mina_numbers.Global_slot_since_hard_fork.t

      val prover_state : t -> Prover_state.t

      val global_slot_since_genesis :
        t -> Mina_numbers.Global_slot_since_genesis.t

      val coinbase_receiver : t -> Public_key.Compressed.t
    end

    module Epoch_data_for_vrf : sig
      [%%versioned:
      module Stable : sig
        module V2 : sig
          type t =
            { epoch_ledger : Mina_base.Epoch_ledger.Value.Stable.V1.t
            ; epoch_seed : Mina_base.Epoch_seed.Stable.V1.t
            ; epoch : Mina_numbers.Length.Stable.V1.t
            ; global_slot : Mina_numbers.Global_slot_since_hard_fork.Stable.V1.t
            ; global_slot_since_genesis :
                Mina_numbers.Global_slot_since_genesis.Stable.V1.t
            ; delegatee_table :
                Mina_base.Account.Stable.V2.t
                Mina_base.Account.Index.Stable.V1.Table.t
                Public_key.Compressed.Stable.V1.Table.t
            }
          [@@deriving sexp]

          val to_latest : t -> t
        end
      end]
    end

    module Slot_won : sig
      [%%versioned:
      module Stable : sig
        module V2 : sig
          type t =
            { delegator :
                Signature_lib.Public_key.Compressed.Stable.V1.t
                * Mina_base.Account.Index.Stable.V1.t
            ; producer : Signature_lib.Keypair.Stable.V1.t
            ; global_slot : Mina_numbers.Global_slot_since_hard_fork.Stable.V1.t
            ; global_slot_since_genesis :
                Mina_numbers.Global_slot_since_genesis.Stable.V1.t
            ; vrf_result : Consensus_vrf.Output_hash.Stable.V1.t
            }
          [@@deriving sexp]

          val to_latest : t -> t
        end
      end]
    end
  end

  module Coinbase_receiver : sig
    (* Producer: block producer receives coinbases
       Other: specified account (with default token) receives coinbases
    *)

    type t = [ `Producer | `Other of Public_key.Compressed.t ]
    [@@deriving yojson]
  end

  module Hooks : sig
    open Data

    (* Check whether we are in the genesis epoch *)
    val is_genesis_epoch : constants:Constants.t -> Block_time.t -> bool

    (**
     * Check that a consensus state was received at a valid time.
    *)
    val received_at_valid_time :
         constants:Constants.t
      -> Consensus_state.Value.t
      -> time_received:Unix_timestamp.t
      -> (unit, [ `Too_early | `Too_late of int64 ]) result

    type select_status = [ `Keep | `Take ] [@@deriving equal]

    (**
     * Select between two ledger builder controller tips given the consensus
     * states for the two tips. Returns `\`Keep` if the first tip should be
     * kept, or `\`Take` if the second tip should be taken instead.
    *)
    val select :
         context:(module CONTEXT)
      -> existing:
           Consensus_state.Value.t Mina_base.State_hash.With_state_hashes.t
      -> candidate:
           Consensus_state.Value.t Mina_base.State_hash.With_state_hashes.t
      -> select_status

    (** Data required to evaluate VRFs for an epoch *)
    val get_epoch_data_for_vrf :
         constants:Constants.t
      -> Unix_timestamp.t
      -> Consensus_state.Value.t
      -> local_state:Local_state.t
      -> logger:Logger.t
      -> Data.Epoch_data_for_vrf.t * Local_state.Snapshot.Ledger_snapshot.t

    val get_block_data :
         slot_won:Slot_won.t
      -> ledger_snapshot:Local_state.Snapshot.Ledger_snapshot.t
      -> coinbase_receiver:Coinbase_receiver.t
      -> Block_data.t

    (**
     * A hook for managing local state when the locked tip is updated.
     *)
    val frontier_root_transition :
         Consensus_state.Value.t
      -> Consensus_state.Value.t
      -> local_state:Local_state.t
      -> snarked_ledger:Mina_ledger.Ledger.Db.t
      -> genesis_ledger_hash:Mina_base.Frozen_ledger_hash.t
      -> unit

    (**
     * Indicator of when we should bootstrap
     *)
    val should_bootstrap :
         context:(module CONTEXT)
      -> existing:
           Consensus_state.Value.t Mina_base.State_hash.With_state_hashes.t
      -> candidate:
           Consensus_state.Value.t Mina_base.State_hash.With_state_hashes.t
      -> bool

    val get_epoch_ledger :
         constants:Constants.t
      -> consensus_state:Consensus_state.Value.t
      -> local_state:Local_state.t
      -> Data.Local_state.Snapshot.Ledger_snapshot.t

    val epoch_end_time :
      constants:Constants.t -> Mina_numbers.Length.t -> Block_time.t

    (** Data needed to synchronize the local state. *)
    type local_state_sync [@@deriving to_yojson]

    (**
     * Predicate indicating whether or not the local state requires synchronization.
     *)
    val required_local_state_sync :
         constants:Constants.t
      -> consensus_state:Consensus_state.Value.t
      -> local_state:Local_state.t
      -> local_state_sync option

    (**
     * Synchronize local state over the network.

     * [glue_sync_ledger] is [Mina_networking.glue_sync_ledger], with the [Mina_networking.t] argument
       already supplied
     *)
    val sync_local_state :
         context:(module CONTEXT)
      -> trust_system:Trust_system.t
      -> local_state:Local_state.t
      -> glue_sync_ledger:
           (   preferred:Network_peer.Peer.t list
            -> (Frozen_ledger_hash.t * Mina_ledger.Sync_ledger.Query.t)
               Pipe_lib.Linear_pipe.Reader.t
            -> ( Frozen_ledger_hash.t
               * Mina_ledger.Sync_ledger.Query.t
               * Mina_ledger.Sync_ledger.Answer.t
                 Network_peer.Envelope.Incoming.t )
               Pipe.Writer.t
            -> unit )
      -> local_state_sync
      -> unit Deferred.Or_error.t

    module Make_state_hooks
        (Blockchain_state : Blockchain_state)
        (Protocol_state : Protocol_state
                            with type blockchain_state :=
                              Blockchain_state.Value.t
                             and type blockchain_state_var :=
                              Blockchain_state.var
                             and type consensus_state := Consensus_state.Value.t
                             and type consensus_state_var := Consensus_state.var)
        (Snark_transition : Snark_transition
                              with type blockchain_state_var :=
                                Blockchain_state.var
                               and type consensus_transition_var :=
                                Consensus_transition.var) :
      State_hooks
        with type blockchain_state := Blockchain_state.Value.t
         and type protocol_state := Protocol_state.Value.t
         and type protocol_state_var := Protocol_state.var
         and type snark_transition_var := Snark_transition.var
         and type consensus_state := Consensus_state.Value.t
         and type consensus_state_var := Consensus_state.var
         and type consensus_transition := Consensus_transition.Value.t
         and type block_data := Block_data.t
  end

  module Body_reference = Body_reference
end
