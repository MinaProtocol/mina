open Network_peer
open Mina_base

type Structured_log_events.t +=
  | Block_received of { state_hash : State_hash.t; sender : Envelope.Sender.t }
  [@@deriving register_event]

type block_or_header =
  [ `Block of Mina_block.t Envelope.Incoming.t
  | `Header of Mina_block.Header.t Envelope.Incoming.t 
  | `Transition of Mina_block.t Envelope.Incoming.t
  ]


include
  Mina_net2.Sink.S_with_void
    with type msg :=
      [ `Block of Mina_block.t Envelope.Incoming.t 
      | `Header of
      Mina_wire_types.Mina_block_header.M.V2.t
      Network_peer.Envelope.Incoming.t  
      | `Transition of Mina_block.t Envelope.Incoming.t
      ]
      * [ `Time_received of Block_time.t ]
      * [ `Valid_cb of Mina_net2.Validation_callback.t ]

type block_sink_config =
  { logger : Logger.t
  ; slot_duration_ms : Block_time.Span.t
  ; on_push : unit -> unit Async_kernel.Deferred.t
  ; time_controller : Block_time.Controller.t
  ; log_gossip_heard : bool
  ; consensus_constants : Consensus.Constants.t
  ; genesis_constants : Genesis_constants.t
  ; constraint_constants : Genesis_constants.Constraint_constants.t
  }

val create :
     block_sink_config
  -> ( 
    [ `Block of
    Mina_block__Block.Stable.V2.t
    Network_peer.Envelope.Incoming.t
| `Header of
    Mina_wire_types.Mina_block_header.M.V2.t
    Network_peer.Envelope.Incoming.t 
 | `Transition of Mina_block__Block.Stable.V2.t Network_peer.Envelope.Incoming.t   
    ] * 
[ `Time_received of Mina_wire_types.Block_time.M.V1.t ] *
[ `Valid_cb of Mina_net2.Validation_callback.t ]   
  )
     Pipe_lib.Strict_pipe.Reader.t
     * t