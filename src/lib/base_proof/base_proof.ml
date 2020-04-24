open Snark_params
open Coda_base
open Coda_state

module type Protocol_config = sig
  val config : Runtime_config.Protocol.t

  val protocol_state_with_hash :
    (Protocol_state.Value.t, State_hash.t) With_hash.t

  module Genesis_ledger : sig
    val t : Ledger.t Lazy.t
  end
end

module type S = sig
  val base_hash : Tick.Field.t

  val base_proof : Proof.t
end

module Make (Keys : Keys_lib.Keys.S) (Protocol_config : Protocol_config) =
struct
  let base_hash =
    Keys.Step.instance_hash Protocol_config.protocol_state_with_hash.data

  let wrap hash proof =
    let module Wrap = Keys.Wrap in
    let input = Wrap_input.of_tick_field hash in
    let proof =
      Tock.prove
        (Tock.Keypair.pk Wrap.keys)
        Wrap.input {Wrap.Prover_state.proof} Wrap.main input
    in
    assert (Tock.verify proof (Tock.Keypair.vk Wrap.keys) Wrap.input input) ;
    proof

  let base_proof =
    let prover_state =
      { Keys.Step.Prover_state.prev_proof= Tock.Proof.dummy
      ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
      ; prev_state=
          Protocol_state.negative_one
            ~genesis_ledger:Protocol_config.Genesis_ledger.t
            ~protocol_config:Protocol_config.config
      ; genesis_state_hash= Protocol_config.protocol_state_with_hash.hash
      ; expected_next_state= None
      ; update=
          Snark_transition.genesis
            ~genesis_ledger:Protocol_config.Genesis_ledger.t }
    in
    let main x =
      Tick.handle
        (Keys.Step.main ~logger:(Logger.create ()) x)
        (Consensus.Data.Prover_state.precomputed_handler
           ~genesis_ledger:Protocol_config.Genesis_ledger.t)
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
    wrap base_hash tick
end
