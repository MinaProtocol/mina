open Coda_base
open Coda_state

module Inputs = struct
  type t =
    { genesis_constants: Genesis_constants.t
    ; genesis_ledger: Genesis_ledger.Packed.t
    ; protocol_state_with_hash:
        (Protocol_state.value, State_hash.t) With_hash.t }
end

module T = struct
  type t =
    { genesis_constants: Genesis_constants.t
    ; genesis_ledger: Genesis_ledger.Packed.t
    ; protocol_state_with_hash:
        (Protocol_state.value, State_hash.t) With_hash.t
    ; genesis_proof: Proof.t }

  let genesis_constants {genesis_constants; _} = genesis_constants

  let protocol_constants t = (genesis_constants t).protocol

  let ledger_depth {genesis_ledger; _} =
    Genesis_ledger.Packed.depth genesis_ledger

  let genesis_ledger {genesis_ledger; _} =
    Genesis_ledger.Packed.t genesis_ledger

  let accounts {genesis_ledger; _} =
    Genesis_ledger.Packed.accounts genesis_ledger

  let find_new_account_record_exn {genesis_ledger; _} =
    Genesis_ledger.Packed.find_new_account_record_exn genesis_ledger

  let largest_account_exn {genesis_ledger; _} =
    Genesis_ledger.Packed.largest_account_exn genesis_ledger

  let largest_account_keypair_exn {genesis_ledger; _} =
    Genesis_ledger.Packed.largest_account_keypair_exn genesis_ledger

  let keypair_of_account_record_exn {genesis_ledger; _} =
    Genesis_ledger.Packed.keypair_of_account_record_exn genesis_ledger

  let genesis_state_with_hash {protocol_state_with_hash; _} =
    protocol_state_with_hash

  let genesis_state t = (genesis_state_with_hash t).data

  let genesis_state_hash t = (genesis_state_with_hash t).hash

  let genesis_proof {genesis_proof; _} = genesis_proof
end

include T

let base_proof ~proof_level:(_ : Genesis_constants.Proof_level.t)
    ~constraint_constants
    (module B : Blockchain_snark.Blockchain_snark_state.S) (t : Inputs.t) =
  let genesis_ledger = Genesis_ledger.Packed.t t.genesis_ledger in
  let protocol_constants = t.genesis_constants.protocol in
  let prev_state =
    Protocol_state.negative_one ~constraint_constants ~genesis_ledger
      ~protocol_constants
  in
  let curr = t.protocol_state_with_hash.data in
  let dummy_txn_stmt : Transaction_snark.Statement.With_sok.t =
    { sok_digest= Coda_base.Sok_message.Digest.default
    ; source=
        Blockchain_state.snarked_ledger_hash
          (Protocol_state.blockchain_state prev_state)
    ; target=
        Blockchain_state.snarked_ledger_hash
          (Protocol_state.blockchain_state curr)
    ; supply_increase= Currency.Amount.zero
    ; fee_excess= Currency.Amount.Signed.zero
    ; pending_coinbase_stack_state=
        { source= Coda_base.Pending_coinbase.Stack.empty
        ; target= Coda_base.Pending_coinbase.Stack.empty } }
  in
  let dummy = Coda_base.Proof.dummy in
  B.step
    ~handler:
      (Consensus.Data.Prover_state.precomputed_handler
         ~genesis_ledger:Test_genesis_ledger.t)
    { transition= Snark_transition.genesis ~genesis_ledger:Test_genesis_ledger.t
    ; prev_state }
    [(prev_state, dummy); (dummy_txn_stmt, dummy)]
    t.protocol_state_with_hash.data

let create_values ~proof_level ~constraint_constants b (t : Inputs.t) =
  { genesis_constants= t.genesis_constants
  ; genesis_ledger= t.genesis_ledger
  ; protocol_state_with_hash= t.protocol_state_with_hash
  ; genesis_proof= base_proof ~proof_level ~constraint_constants b t }
