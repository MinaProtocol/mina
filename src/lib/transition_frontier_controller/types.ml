module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

type produced_transition =
  [ `Block of
    Mina_block.Validation.initial_valid_with_block
    Network_peer.Envelope.Incoming.t
  | `Header of
    Mina_block.Validation.initial_valid_with_header
    Network_peer.Envelope.Incoming.t ]
  * [ `Valid_cb of Mina_net2.Validation_callback.t option ]
