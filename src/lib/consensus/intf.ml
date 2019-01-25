open Core_kernel
open Tuple_lib
open Fold_lib
open Coda_numbers

module type Prover_state_intf = sig
  type t [@@deriving bin_io, sexp]

  val precomputed_handler : Snark_params.Tick.Handler.t

  val handler : t -> Snark_params.Tick.Handler.t
end

(** Constants are defined with a single letter (latin or greek) based on
 * their usage in the Ouroboros suite of papers *)
module type Shared_constants = sig
  val k : int
  (** k is the number of blocks required to reach finality *)

  val coinbase : Currency.Amount.t
  (** The amount of money minted and given to the proposer whenever a block
   * is created *)

  val block_duration_ms : Int64.t
  (** The window of time available to create a block *)
end

module Proof_of_signature = struct
  module Inputs = struct
    module type S = sig
      module Time : Protocols.Coda_pow.Time_intf

      module Genesis_ledger : sig
        val t : Coda_base.Ledger.t
      end

      module Constants : Shared_constants
    end
  end
end

module Proof_of_stake = struct
  module Inputs = struct
    module type S = sig
      module Time : sig
        type t

        module Span : sig
          type t

          val to_ms : t -> Int64.t

          val of_ms : Int64.t -> t

          val ( + ) : t -> t -> t

          val ( * ) : t -> t -> t
        end

        val ( < ) : t -> t -> bool

        val ( >= ) : t -> t -> bool

        val diff : t -> t -> Span.t

        val to_span_since_epoch : t -> Span.t

        val of_span_since_epoch : Span.t -> t

        val add : t -> Span.t -> t
      end

      module Constants : sig
        include Shared_constants

        val genesis_state_timestamp : Time.t

        val c : int
        (** c is the number of slots after which we can be confident at least one
         * block was produced (Note: c=8 in Ouroboros Praos papers) *)

        val delta : int
        (** delta is the network delay (as a number of slots) that we can be sure
         * we've received a block if it was gossiped by some honest node on the
         * network *)
      end
    end
  end
end

module type S = sig
  module Local_state : sig
    type t [@@deriving sexp]

    val create : Signature_lib.Keypair.t option -> t
  end

  module Constants : Shared_constants

  module Consensus_transition_data : sig
    type value [@@deriving bin_io, sexp]

    include Snark_params.Tick.Snarkable.S with type value := value

    val genesis : value
  end

  module Consensus_state : sig
    type value [@@deriving hash, eq, compare, bin_io, sexp]

    include Snark_params.Tick.Snarkable.S with type value := value

    val genesis : value

    val length_in_triples : int

    val var_to_triples :
         var
      -> ( Snark_params.Tick.Boolean.var Triple.t list
         , _ )
         Snark_params.Tick.Checked.t

    val fold : value -> bool Triple.t Fold.t

    val length : value -> Length.t

    val to_lite : (value -> Lite_base.Consensus_state.t) option

    val to_string_record : value -> string
  end

  module Blockchain_state : Coda_base.Blockchain_state.S

  module Prover_state : Prover_state_intf

  module Protocol_state :
    Coda_base.Protocol_state.S
    with module Blockchain_state = Blockchain_state
     and module Consensus_state = Consensus_state

  module Snark_transition :
    Coda_base.Snark_transition.S
    with module Blockchain_state = Blockchain_state
     and module Consensus_data = Consensus_transition_data

  module Proposal_data : sig
    type t

    val prover_state : t -> Prover_state.t
  end

  module For_tests : sig
    val gen_consensus_state :
         gen_slot_advancement:int Quickcheck.Generator.t
      -> (   previous_protocol_state:( Protocol_state.value
                                     , Coda_base.State_hash.t )
                                     With_hash.t
          -> snarked_ledger_hash:Coda_base.Frozen_ledger_hash.t
          -> Consensus_state.value)
         Quickcheck.Generator.t
  end

  val genesis_protocol_state :
    (Protocol_state.value, Coda_base.State_hash.t) With_hash.t

  val generate_transition :
       previous_protocol_state:Protocol_state.value
    -> blockchain_state:Blockchain_state.value
    -> time:Unix_timestamp.t
    -> proposal_data:Proposal_data.t
    -> transactions:Coda_base.User_command.t list
    -> snarked_ledger_hash:Coda_base.Frozen_ledger_hash.t
    -> supply_increase:Currency.Amount.t
    -> logger:Logger.t
    -> Protocol_state.value * Consensus_transition_data.value
  (**
   * Generate a new protocol state and consensus specific transition data
   * for a new transition. Called from the proposer in order to generate
   * a new transition to propose to the network. Returns `None` if a new
   * transition cannot be generated.
  *)

  val received_at_valid_time :
    Consensus_state.value -> time_received:Unix_timestamp.t -> bool
  (**
   * Check that a consensus state was received at a valid time.
  *)

  val next_state_checked :
       prev_state:Protocol_state.var
    -> prev_state_hash:Coda_base.State_hash.var
    -> Snark_transition.var
    -> Currency.Amount.var
    -> ( [`Success of Snark_params.Tick.Boolean.var] * Consensus_state.var
       , _ )
       Snark_params.Tick.Checked.t
  (**
   * Create a constrained, checked var for the next consensus state of
   * a given consensus state and snark transition.
  *)

  val select :
       existing:Consensus_state.value
    -> candidate:Consensus_state.value
    -> logger:Logger.t
    -> [`Keep | `Take]
  (**
   * Select between two ledger builder controller tips given the consensus
   * states for the two tips. Returns `\`Keep` if the first tip should be
   * kept, or `\`Take` if the second tip should be taken instead.
  *)

  val next_proposal :
       Unix_timestamp.t
    -> Consensus_state.value
    -> local_state:Local_state.t
    -> keypair:Signature_lib.Keypair.t
    -> logger:Logger.t
    -> [ `Check_again of Unix_timestamp.t
       | `Propose of Unix_timestamp.t * Proposal_data.t ]
  (**
   * Determine if and when to perform the next transition proposal. Either
   * informs the callee to check again at some time in the future, or to
   * schedule a proposal at some time in the future.
  *)

  val lock_transition :
       ?proposer_public_key:Signature_lib.Public_key.Compressed.t
    -> Consensus_state.value
    -> Consensus_state.value
    -> snarked_ledger:(unit -> Coda_base.Ledger.t Or_error.t)
    -> local_state:Local_state.t
    -> unit
  (**
   * A hook for managing local state when the locked tip is updated.
  *)

  val should_bootstrap :
    existing:Consensus_state.value -> candidate:Consensus_state.value -> bool
  (**
     * Indicator of when we should bootstrap  
    *)
end
