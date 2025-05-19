open Network_peer
open Core_kernel

type t =
  [ `Block of Mina_block.initial_valid_block Envelope.Incoming.t
  | `Header of Mina_block.initial_valid_header Envelope.Incoming.t ]
  * [ `Valid_cb of Mina_net2.Validation_callback.t option ]

let to_yojson : t -> Yojson.Safe.t = function
  | `Block { sender; received_at; _ }, _ ->
      `Assoc
        [ ("sender", Envelope.Sender.to_yojson sender)
        ; ( "received_at"
          , Mina_stdlib.Time.Span.to_yojson
              (Time.to_span_since_epoch received_at) )
        ; ("kind", `String "block")
        ]
  | `Header { sender; received_at; _ }, _ ->
      `Assoc
        [ ("sender", Envelope.Sender.to_yojson sender)
        ; ( "received_at"
          , Mina_stdlib.Time.Span.to_yojson
              (Time.to_span_since_epoch received_at) )
        ; ("kind", `String "header")
        ]
