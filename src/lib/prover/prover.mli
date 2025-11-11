module type S = Intf.S

include S

val prove_from_input_sexp : t -> Base.Sexp.t -> bool Async.Deferred.t

val create_genesis_block_locally :
     Worker_state.t
  -> Genesis_proof.Inputs.t
  -> Blockchain_snark.Blockchain.t Async_kernel.Deferred.Or_error.t

val create_genesis_block_inputs :
     Genesis_proof.Inputs.t
  -> Blockchain_snark.Blockchain.t
     * Mina_state.Protocol_state.Value.t
     * Mina_state.Snark_transition.value
     * 'a option
     * Consensus.Data.Prover_state.t
     * Mina_base.Pending_coinbase_witness.t
