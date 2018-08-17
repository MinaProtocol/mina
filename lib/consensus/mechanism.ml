module type S = sig
  module Proof : sig type t [@@deriving bin_io, sexp] end

  module Consensus_state : sig
    type value [@@deriving hash, eq, compare]

    include Snark_params.Tick.Snarkable.S with type value := value

    val genesis : value

    val bit_length : int

    val var_to_bits :
         var
      -> (Snark_params.Tick.Boolean.var list, _) Snark_params.Tick.Checked.t
  end

  module Protocol_state :
    Nanobit_base.Protocol_state.S with module Consensus_state = Consensus_state

  module Consensus_data : sig
    include Snark_params.Tick.Snarkable.S

    val genesis : value
  end

  module Snark_transition :
    Nanobit_base.Snark_transition.S
    with module Consensus_data = Consensus_data
     and module Protocol_state = Protocol_state
     and module Proof = Proof

  module Internal_transition :
    Nanobit_base.Internal_transition.S
    with module Snark_transition = Snark_transition

  module External_transition :
    Nanobit_base.External_transition.S
    with module Protocol_state = Protocol_state

  val verify :
       Snark_transition.var
    -> (Snark_params.Tick.Boolean.var, _) Snark_params.Tick.Checked.t

  val update :
       Consensus_state.var
    -> Snark_transition.var
    -> (Consensus_state.var, _) Snark_params.Tick.Checked.t

  val update_unchecked :
    Consensus_state.value -> Snark_transition.value -> Consensus_state.value

  val step :
       Consensus_state.value
    -> Consensus_state.value Async_kernel.Deferred.Or_error.t

  val select : Consensus_state.value -> Consensus_state.value -> [`Keep | `Take]

  val genesis_protocol_state : Protocol_state.value

  val create_consensus_state : Protocol_state.value -> Consensus_state.value

  val create_consensus_data : Protocol_state.value -> Consensus_data.value option
end
