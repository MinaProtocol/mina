open Async
open Core
open Integration_test_lib.Util
open Integration_test_lib
module Timeout = Timeout_lib.Core_time
module Node = Local_network.Node



type t =
{ logger : Logger.t
; event_reader : (Node.t * Event_type.event) Pipe.Reader.t
}

let create ~logger ~(network : Local_network.t) =
  let event_reader, _ = Pipe.create () in
  { logger; event_reader }

let event_reader { event_reader; _ } = event_reader

let destroy t : unit Deferred.Or_error.t =
  Deferred.unit
