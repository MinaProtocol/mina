open Async
open Core

type state = Peer.t

type ('query, 'response) rpc_fn =
  state -> version:int -> 'query -> 'response Deferred.t

type 'r rpc_response =
  | Failed_to_connect of Error.t
  | Connected of 'r Or_error.t Envelope.Incoming.t

module type Rpc_implementation_intf = sig
  type query

  type response

  val name : string

  val versions : unit -> Int.Set.t

  val sent_counter : Mina_metrics.Counter.t * Mina_metrics.Gauge.t

  val received_counter : Mina_metrics.Counter.t * Mina_metrics.Gauge.t

  val failed_request_counter : Mina_metrics.Counter.t

  val failed_response_counter : Mina_metrics.Counter.t

  val implement_multi :
       ?log_not_previously_seen_version:(name:string -> int -> unit)
    -> (query, response) rpc_fn
    -> state Rpc.Implementation.t list

  val dispatch_multi :
       Versioned_rpc.Connection_with_menu.t
    -> query
    -> response Deferred.Or_error.t
end

type ('query, 'response) rpc_implementation =
  (module Rpc_implementation_intf
     with type query = 'query
      and type response = 'response )

module type Rpc_interface_intf = sig
  type ('query, 'response) rpc

  type rpc_handler =
    | Rpc_handler :
        { rpc : ('q, 'r) rpc
        ; f : ('q, 'r) rpc_fn
        ; cost : 'q -> int
        ; budget : int * [ `Per of Time.Span.t ]
        }
        -> rpc_handler

  val implementation_of_rpc : ('q, 'r) rpc -> ('q, 'r) rpc_implementation

  val match_handler :
    rpc_handler -> ('q, 'r) rpc -> do_:(('q, 'r) rpc_fn -> 'a) -> 'a option
end
