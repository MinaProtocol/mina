open Core_kernel
open Tuple_lib
open Fold_lib

module type S = sig
  module Proof : sig
    type t [@@deriving bin_io, sexp]
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
  end

  module Protocol_state :
    Nanobit_base.Protocol_state.S with module Consensus_state = Consensus_state

  module Snark_transition :
    Nanobit_base.Snark_transition.S
    with module Consensus_data = Consensus_transition_data
     and module Proof = Proof

  module Internal_transition :
    Nanobit_base.Internal_transition.S
    with module Snark_transition = Snark_transition

  module External_transition :
    Nanobit_base.External_transition.S
    with module Protocol_state = Protocol_state

  module Local_state : sig
    type t
  end

  module Ledger_hash : sig
    type t
  end

  module Ledger_pool : Rc_pool.S with type key := Ledger_hash.t

  module Ledger : sig
    type t

    val copy : t -> t
  end

  val verify :
       Snark_transition.var
    -> (Snark_params.Tick.Boolean.var, _) Snark_params.Tick.Checked.t

  val update :
       consensus:Consensus_state.value
    -> transition:Snark_transition.value
    -> state:Local_state.t
    -> pool:Ledger.t Ledger_pool.t
    -> last_ledger:Ledger.t
    -> next_ledger:Ledger.t
    -> (Consensus_state.value * Local_state.t) Or_error.t

  val update_var :
       Consensus_state.var
    -> Snark_transition.var
    -> (Consensus_state.var, _) Snark_params.Tick.Checked.t

  val step :
       Consensus_state.value
    -> Consensus_state.value Async_kernel.Deferred.Or_error.t

  val select : Consensus_state.value -> Consensus_state.value -> [`Keep | `Take]

  val generate_transition :
       previous_protocol_state:Protocol_state.value
    -> blockchain_state:Nanobit_base.Blockchain_state.value
    -> time:Int64.t
    -> transactions:Nanobit_base.Transaction.t list
    -> Protocol_state.value * Consensus_transition_data.value

  val genesis_protocol_state : Protocol_state.value
end
