open Coda_base
open Coda_state

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

let base_proof ?(logger = Logger.create ())
    ~keys:((module Keys : Keys_lib.Keys.S) as keys) ~genesis_ledger
    ~protocol_constants
    ~(protocol_state_with_hash :
       (Protocol_state.value, State_hash.t) With_hash.t) ~base_hash () =
  let open Snark_params in
  let prover_state =
    { Keys.Step.Prover_state.prev_proof= Tock.Proof.dummy
    ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
    ; prev_state=
        Protocol_state.negative_one ~genesis_ledger ~protocol_constants
    ; genesis_state_hash= protocol_state_with_hash.hash
    ; expected_next_state= None
    ; update= Snark_transition.genesis ~genesis_ledger }
  in
  let main x =
    Tick.handle (Keys.Step.main ~logger x)
      (Consensus.Data.Prover_state.precomputed_handler ~genesis_ledger)
  in
  let tick =
    Tick.prove
      (Tick.Keypair.pk Keys.Step.keys)
      (Keys.Step.input ()) prover_state main base_hash
  in
  assert (
    Tick.verify tick
      (Tick.Keypair.vk Keys.Step.keys)
      (Keys.Step.input ()) base_hash ) ;
  wrap ~keys base_hash tick

let create = base_proof
