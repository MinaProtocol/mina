open Protocols.Coda_pow
open Coda_base

module type S = sig
  module Time : Time_intf

  include Transition_frontier.Inputs_intf

  module State_proof :
    Proof_intf
    with type input := Consensus.Mechanism.Protocol_state.value
     and type t := Proof.t

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger := Staged_ledger.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
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
