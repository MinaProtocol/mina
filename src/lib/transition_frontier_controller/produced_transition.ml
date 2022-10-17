type t =
  [ `Block of
    Mina_block.Validation.initial_valid_with_block
    Network_peer.Envelope.Incoming.t
  | `Header of
    Mina_block.Validation.initial_valid_with_header
    Network_peer.Envelope.Incoming.t ]
  * [ `Valid_cb of Mina_net2.Validation_callback.t option ]
