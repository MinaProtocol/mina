open Protocols.Coda_pow

module type S = sig
  module Time : Time_intf

  module Consensus_mechanism :
    Consensus_mechanism_intf
    with type protocol_state_hash := Coda_base.State_hash.t
     and type protocol_state_proof := Coda_base.Proof.t

  module External_transition : External_transition_intf
    with type protocol_state := Consensus_mechanism.Protocol_state.value
     and type protocol_state_proof := Coda_base.Proof.t

  module Proof :
    Proof_intf
    with type input := Consensus_mechanism.Protocol_state.value
     and type t := Coda_base.Proof.t

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := Coda_base.State_hash.t
     and type external_transition := External_transition.t
end

(*
module Test : S = struct
  module Proof = Test_mocks.Proof.Bool

  module Consensus_mechanism = struct
    (* we are only interested in mocking the external transition *)
    include Test_mocks.Consensus.Mechanism.Stubs.Make (struct
      module Consensus_state = Test_mocks.Consensus.State.Stubs.Full
      module Blockchain_state = Test_mocks.Blockchain_state.Stubs.Full
      module Protocol_state = Test_mocks.Protocol_state.Stubs.Full (Blockchain_state) (Consensus_state)
      module External_transition = Test_mocks.External_transition.Int (Protocol_state)
      module Snark_transition = Test_mocks.Snark_Transition.Stubs.Full (Protocol_state)
      module Internal_transition = Test_mocks.Internal_transition.Stubs.Full (Protocol_state) (Snark_transition)
    end)
  end
end
 *)
