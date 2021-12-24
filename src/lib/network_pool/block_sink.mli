open Network_peer
open Mina_transition

include
  Mina_net2.Sink.S_with_void
    with type msg :=
          External_transition.t Envelope.Incoming.t
          * Block_time.t
          * Mina_net2.Validation_callback.t

val create :
     logger:Logger.t
  -> slot_duration_ms:Block_time.Span.t
  -> ( External_transition.t Envelope.Incoming.t
     * Block_time.t
     * Mina_net2.Validation_callback.t )
     Pipe_lib.Strict_pipe.Reader.t
     * t
