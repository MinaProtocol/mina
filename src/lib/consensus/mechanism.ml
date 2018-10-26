open Core_kernel
open Tuple_lib
open Fold_lib
open Coda_numbers

module type S = sig
  module Local_state : sig
    type t [@@deriving sexp]

    val create : unit -> t
  end

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
  end

  module Blockchain_state : Coda_base.Blockchain_state.S

  module Protocol_state :
    Coda_base.Protocol_state.S
    with module Blockchain_state = Blockchain_state
     and module Consensus_state = Consensus_state

  module Snark_transition :
    Coda_base.Snark_transition.S
    with module Blockchain_state = Blockchain_state
     and module Consensus_data = Consensus_transition_data

  module Internal_transition :
    Coda_base.Internal_transition.S
    with module Snark_transition = Snark_transition

  module External_transition :
    Coda_base.External_transition.S with module Protocol_state = Protocol_state

  val genesis_protocol_state : Protocol_state.value

  val generate_transition :
       previous_protocol_state:Protocol_state.value
    -> blockchain_state:Blockchain_state.value
    -> local_state:Local_state.t
    -> time:Unix_timestamp.t
    -> keypair:Signature_lib.Keypair.t
    -> transactions:Coda_base.Transaction.t list
    -> ledger:Coda_base.Ledger.t
    -> logger:Logger.t
    -> (Protocol_state.value * Consensus_transition_data.value) option
  (**
   * Generate a new protocol state and consensus specific transition data
   * for a new transition. Called from the proposer in order to generate
   * a new transition to propose to the network. Returns `None` if a new
   * transition cannot be generated.
   *)

  val is_transition_valid_checked :
       Snark_transition.var
    -> (Snark_params.Tick.Boolean.var, _) Snark_params.Tick.Checked.t
  (**
   * Create a checked boolean constraint for the validity of a transition.
   *)

  val next_state_checked :
       Consensus_state.var
    -> Coda_base.State_hash.var
    -> Snark_transition.var
    -> (Consensus_state.var, _) Snark_params.Tick.Checked.t
  (**
   * Create a constrained, checked var for the next consensus state of
   * a given consensus state and snark transition.
   *)

  val select :
       Consensus_state.value
    -> Consensus_state.value
    -> logger:Logger.t
    -> time_received:Unix_timestamp.t
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
    -> [`Check_again of Unix_timestamp.t | `Propose of Unix_timestamp.t]
  (**
   * Determine if and when to perform the next transition proposal. Either
   * informs the callee to check again at some time in the future, or to
   * schedule a proposal at some time in the future.
   *)

  val lock_transition :
       Consensus_state.value
    -> Consensus_state.value
    -> snarked_ledger:(unit -> Coda_base.Ledger.t Or_error.t)
    -> local_state:Local_state.t
    -> unit
  (**
   * A hook for managing local state when the locked tip is updated.
   *)
end
