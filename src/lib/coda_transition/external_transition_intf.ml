open Core_kernel
open Async_kernel
open Coda_base
open Coda_state
open Signature_lib

module type External_transition_common_intf = sig
  type t

  val protocol_state : t -> Protocol_state.Value.t

  val protocol_state_proof : t -> Proof.t

  val blockchain_state : t -> Blockchain_state.Value.t

  val consensus_state : t -> Consensus.Data.Consensus_state.Value.t

  val staged_ledger_diff : t -> Staged_ledger_diff.t

  val state_hash : t -> State_hash.t

  val parent_hash : t -> State_hash.t

  val proposer : t -> Public_key.Compressed.t

  val user_commands : t -> User_command.t list

  val payments : t -> User_command.t list

  val delta_transition_chain_proof : t -> State_hash.t * State_body_hash.t list
end

module type External_transition_base_intf = sig
  type t [@@deriving sexp, compare, to_yojson]

  include Comparable.S with type t := t

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving sexp, eq, bin_io, to_yojson, version]
    end

    module Latest = V1
  end

  include External_transition_common_intf with type t := t
end

module type S = sig
  include External_transition_base_intf

  type external_transition = t

  module Validation : sig
    module Stable : sig
      module V1 : sig
        type ( 'time_received
             , 'proof
             , 'delta_transition_chain
             , 'frontier_dependencies
             , 'staged_ledger_diff )
             t =
          'time_received
          * 'proof
          * 'delta_transition_chain
          * 'frontier_dependencies
          * 'staged_ledger_diff
          constraint 'time_received = [`Time_received] * (unit, _) Truth.t
          constraint 'proof = [`Proof] * (unit, _) Truth.t
          constraint
            'delta_transition_chain =
            [`Delta_transition_chain]
            * (State_hash.t Non_empty_list.t, _) Truth.t
          constraint
            'frontier_dependencies =
            [`Frontier_dependencies] * (unit, _) Truth.t
          constraint
            'staged_ledger_diff =
            [`Staged_ledger_diff] * (unit, _) Truth.t
        [@@deriving version]
      end

      module Latest = V1
    end

    type ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         t =
      ( 'time_received
      , 'proof
      , 'delta_transition_chain
      , 'frontier_dependencies
      , 'staged_ledger_diff )
      Stable.Latest.t

    type fully_invalid =
      ( [`Time_received] * unit Truth.false_t
      , [`Proof] * unit Truth.false_t
      , [`Delta_transition_chain] * State_hash.t Non_empty_list.t Truth.false_t
      , [`Frontier_dependencies] * unit Truth.false_t
      , [`Staged_ledger_diff] * unit Truth.false_t )
      t

    type fully_valid =
      ( [`Time_received] * unit Truth.true_t
      , [`Proof] * unit Truth.true_t
      , [`Delta_transition_chain] * State_hash.t Non_empty_list.t Truth.true_t
      , [`Frontier_dependencies] * unit Truth.true_t
      , [`Staged_ledger_diff] * unit Truth.true_t )
      t

    type initial_valid =
      ( [`Time_received] * unit Truth.true_t
      , [`Proof] * unit Truth.true_t
      , [`Delta_transition_chain] * State_hash.t Non_empty_list.t Truth.true_t
      , [`Frontier_dependencies] * unit Truth.false_t
      , [`Staged_ledger_diff] * unit Truth.false_t )
      t

    type almost_valid =
      ( [`Time_received] * unit Truth.true_t
      , [`Proof] * unit Truth.true_t
      , [`Delta_transition_chain] * State_hash.t Non_empty_list.t Truth.true_t
      , [`Frontier_dependencies] * unit Truth.true_t
      , [`Staged_ledger_diff] * unit Truth.false_t )
      t

    type ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         with_transition =
      (external_transition, State_hash.t) With_hash.t
      * ( 'time_received
        , 'proof
        , 'delta_transition_chain
        , 'frontier_dependencies
        , 'staged_ledger_diff )
        t

    val fully_invalid : fully_invalid

    val wrap :
         (external_transition, State_hash.t) With_hash.t
      -> (external_transition, State_hash.t) With_hash.t * fully_invalid

    val extract_delta_transition_chain_witness :
         ( 'time_received
         , 'proof
         , [`Delta_transition_chain]
           * State_hash.t Non_empty_list.t Truth.true_t
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         t
      -> State_hash.t Non_empty_list.t

    val reset_frontier_dependencies_validation :
         ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , [`Frontier_dependencies] * unit Truth.true_t
         , 'staged_ledger_diff )
         with_transition
      -> ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , [`Frontier_dependencies] * unit Truth.false_t
         , 'staged_ledger_diff )
         with_transition

    val reset_staged_ledger_diff_validation :
         ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , 'frontier_dependencies
         , [`Staged_ledger_diff] * unit Truth.true_t )
         with_transition
      -> ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , 'frontier_dependencies
         , [`Staged_ledger_diff] * unit Truth.false_t )
         with_transition

    val forget_validation :
         ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         with_transition
      -> external_transition
  end

  module Initial_validated : sig
    type t =
      (external_transition, State_hash.t) With_hash.t
      * Validation.initial_valid

    include External_transition_common_intf with type t := t
  end

  module Almost_validated : sig
    type t =
      (external_transition, State_hash.t) With_hash.t * Validation.almost_valid

    include External_transition_common_intf with type t := t
  end

  module Validated : sig
    type t =
      (external_transition, State_hash.t) With_hash.t * Validation.fully_valid

    val create_unsafe :
      external_transition -> [`I_swear_this_is_safe_see_my_comment of t]

    include External_transition_base_intf with type t := t
  end

  val create :
       protocol_state:Protocol_state.Value.t
    -> protocol_state_proof:Proof.t
    -> staged_ledger_diff:Staged_ledger_diff.t
    -> delta_transition_chain_proof:State_hash.t * State_body_hash.t list
    -> t

  val timestamp : t -> Block_time.t

  val skip_time_received_validation :
       [`This_transition_was_not_received_via_gossip]
    -> ( [`Time_received] * unit Truth.false_t
       , 'proof
       , 'delta_transition_chain
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> ( [`Time_received] * unit Truth.true_t
       , 'proof
       , 'delta_transition_chain
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition

  val validate_time_received :
       ( [`Time_received] * unit Truth.false_t
       , 'proof
       , 'delta_transition_chain
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> time_received:Block_time.t
    -> ( ( [`Time_received] * unit Truth.true_t
         , 'proof
         , 'delta_transition_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         Validation.with_transition
       , [> `Invalid_time_received of [`Too_early | `Too_late of int64]] )
       Result.t

  val skip_proof_validation :
       [`This_transition_was_generated_internally]
    -> ( 'time_received
       , [`Proof] * unit Truth.false_t
       , 'delta_transition_chain
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> ( 'time_received
       , [`Proof] * unit Truth.true_t
       , 'delta_transition_chain
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition

  val skip_delta_transition_chain_validation :
       [`This_transition_was_not_received_via_gossip]
    -> ( 'time_received
       , 'proof
       , [`Delta_transition_chain]
         * State_hash.t Non_empty_list.t Truth.false_t
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> ( 'time_received
       , 'proof
       , [`Delta_transition_chain] * State_hash.t Non_empty_list.t Truth.true_t
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition

  val validate_proof :
       ( 'time_received
       , [`Proof] * unit Truth.false_t
       , 'delta_transition_chain
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> verifier:Verifier.t
    -> ( ( 'time_received
         , [`Proof] * unit Truth.true_t
         , 'delta_transition_chain
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         Validation.with_transition
       , [> `Invalid_proof | `Verifier_error of Error.t] )
       Deferred.Result.t

  val validate_delta_transition_chain :
       ( 'time_received
       , 'proof
       , [`Delta_transition_chain]
         * State_hash.t Non_empty_list.t Truth.false_t
       , 'frontier_dependencies
       , 'staged_ledger_diff )
       Validation.with_transition
    -> ( ( 'time_received
         , 'proof
         , [`Delta_transition_chain]
           * State_hash.t Non_empty_list.t Truth.true_t
         , 'frontier_dependencies
         , 'staged_ledger_diff )
         Validation.with_transition
       , [> `Invalid_delta_transition_chain_proof] )
       Result.t

  (* This functor is necessary to break the dependency cycle between the Transition_fronter and the External_transition *)
  module Transition_frontier_validation (Transition_frontier : sig
    type t

    module Breadcrumb : sig
      type t

      val validated_transition : t -> Validated.t
    end

    val root : t -> Breadcrumb.t

    val find : t -> State_hash.t -> Breadcrumb.t option
  end) : sig
    val validate_frontier_dependencies :
         ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , [`Frontier_dependencies] * unit Truth.false_t
         , 'staged_ledger_diff )
         Validation.with_transition
      -> logger:Logger.t
      -> frontier:Transition_frontier.t
      -> ( ( 'time_received
           , 'proof
           , 'delta_transition_chain
           , [`Frontier_dependencies] * unit Truth.true_t
           , 'staged_ledger_diff )
           Validation.with_transition
         , [ `Already_in_frontier
           | `Parent_missing_from_frontier
           | `Not_selected_over_frontier_root ] )
         Result.t
  end

  val skip_frontier_dependencies_validation :
       [`This_transition_belongs_to_a_detached_subtree]
    -> ( 'time_received
       , 'proof
       , 'delta_transition_chain
       , [`Frontier_dependencies] * unit Truth.false_t
       , 'staged_ledger_diff )
       Validation.with_transition
    -> ( 'time_received
       , 'proof
       , 'delta_transition_chain
       , [`Frontier_dependencies] * unit Truth.true_t
       , 'staged_ledger_diff )
       Validation.with_transition

  val validate_staged_ledger_hash :
       [`Staged_ledger_already_materialized of Staged_ledger_hash.t]
    -> ( 'time_received
       , 'proof
       , 'delta_transition_chain
       , 'frontier_dependencies
       , [`Staged_ledger_diff] * unit Truth.false_t )
       Validation.with_transition
    -> ( ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , 'frontier_dependencies
         , [`Staged_ledger_diff] * unit Truth.true_t )
         Validation.with_transition
       , [> `Staged_ledger_hash_mismatch] )
       Result.t

  val skip_staged_ledger_diff_validation :
       [`This_transition_has_a_trusted_staged_ledger]
    -> ( 'time_received
       , 'proof
       , 'delta_transition_chain
       , 'frontier_dependencies
       , [`Staged_ledger_diff] * unit Truth.false_t )
       Validation.with_transition
    -> ( 'time_received
       , 'proof
       , 'delta_transition_chain
       , 'frontier_dependencies
       , [`Staged_ledger_diff] * unit Truth.true_t )
       Validation.with_transition

  module Staged_ledger_validation : sig
    val validate_staged_ledger_diff :
         ( 'time_received
         , 'proof
         , 'delta_transition_chain
         , 'frontier_dependencies
         , [`Staged_ledger_diff] * unit Truth.false_t )
         Validation.with_transition
      -> logger:Logger.t
      -> verifier:Verifier.t
      -> parent_staged_ledger:Staged_ledger.t
      -> ( [`Just_emitted_a_proof of bool]
           * [ `External_transition_with_validation of
               ( 'time_received
               , 'proof
               , 'delta_transition_chain
               , 'frontier_dependencies
               , [`Staged_ledger_diff] * unit Truth.true_t )
               Validation.with_transition ]
           * [`Staged_ledger of Staged_ledger.t]
         , [ `Invalid_staged_ledger_diff of
             [ `Incorrect_target_staged_ledger_hash
             | `Incorrect_target_snarked_ledger_hash ]
             list
           | `Staged_ledger_application_failed of
             Staged_ledger.Staged_ledger_error.t ] )
         Deferred.Result.t
  end
end
