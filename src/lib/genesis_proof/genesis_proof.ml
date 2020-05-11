open Coda_base
open Coda_state

module Inputs = struct
  type t =
    { genesis_constants: Genesis_constants.t
    ; genesis_ledger: Genesis_ledger.Packed.t
    ; protocol_state_with_hash:
        (Protocol_state.value, State_hash.t) With_hash.t
    ; base_hash: State_hash.t }
end

module T = struct
  type t =
    { genesis_constants: Genesis_constants.t
    ; genesis_ledger: Genesis_ledger.Packed.t
    ; protocol_state_with_hash:
        (Protocol_state.value, State_hash.t) With_hash.t
    ; base_hash: State_hash.t
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

let wrap ~keys:(module Keys : Keys_lib.Keys.S) hash proof =
  let open Snark_params in
  let module Wrap = Keys.Wrap in
  let input = Wrap_input.of_tick_field hash in
  let proof =
    Tock.prove
      (Tock.Keypair.pk Wrap.keys)
      Wrap.input {Wrap.Prover_state.proof} Wrap.main input
  in
  assert (Tock.verify proof (Tock.Keypair.vk Wrap.keys) Wrap.input input) ;
  proof

let base_proof ?(logger = Logger.create ()) ~proof_level ~constraint_constants
    ~keys:((module Keys : Keys_lib.Keys.S) as keys) (t : Inputs.t) =
  let genesis_ledger = Genesis_ledger.Packed.t t.genesis_ledger in
  let protocol_constants = t.genesis_constants.protocol in
  let open Snark_params in
  let prover_state =
    { Keys.Step.Prover_state.prev_proof= Tock.Proof.dummy
    ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
    ; prev_state=
        Protocol_state.negative_one ~genesis_ledger ~constraint_constants
          ~protocol_constants
    ; genesis_state_hash= t.protocol_state_with_hash.hash
    ; expected_next_state= None
    ; update= Snark_transition.genesis ~genesis_ledger }
  in
  let main x =
    Tick.handle
      (Keys.Step.main ~logger ~proof_level ~constraint_constants x)
      (Consensus.Data.Prover_state.precomputed_handler ~genesis_ledger)
  in
  let tick =
    Tick.prove
      (Tick.Keypair.pk Keys.Step.keys)
      (Keys.Step.input ()) prover_state main t.base_hash
  in
  assert (
    Tick.verify tick
      (Tick.Keypair.vk Keys.Step.keys)
      (Keys.Step.input ()) t.base_hash ) ;
  wrap ~keys t.base_hash tick

let create_values ?logger ~proof_level ~constraint_constants ~keys
    (t : Inputs.t) =
  { genesis_constants= t.genesis_constants
  ; genesis_ledger= t.genesis_ledger
  ; protocol_state_with_hash= t.protocol_state_with_hash
  ; base_hash= t.base_hash
  ; genesis_proof=
      base_proof ?logger ~proof_level ~constraint_constants ~keys t }
