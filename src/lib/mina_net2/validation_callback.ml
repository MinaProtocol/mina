open Core
open Async
module Timeout = Timeout_lib.Core_time_ns

type validation_result = [ `Accept | `Reject | `Ignore ] [@@deriving equal]

type t = { expiration : Time_ns.t option; signal : validation_result Ivar.t }

let create expiration =
  { expiration = Some expiration; signal = Ivar.create () }

let create_without_expiration () =
  { expiration = None; signal = Ivar.create () }

let is_expired cb =
  match cb.expiration with
  | None ->
      false
  | Some expires_at ->
      Time_ns.(now () >= expires_at)

let await_timeout cb =
  if is_expired cb then Deferred.return ()
  else
    match cb.expiration with
    | None ->
        Deferred.never ()
    | Some expires_at ->
        after
          ( Time_ns.Span.to_span_float_round_nearest
          @@ Time_ns.diff expires_at (Time_ns.now ()) )

let await cb =
  if is_expired cb then Deferred.return None
  else
    match cb.expiration with
    | None ->
        Ivar.read cb.signal >>| Option.some
    | Some expires_at -> (
        match%map
          Timeout.await ()
            ~timeout_duration:(Time_ns.diff expires_at (Time_ns.now ()))
            (Ivar.read cb.signal)
        with
        | `Ok result ->
            Some result
        | `Timeout ->
            None )

let await_exn cb =
  match%map await cb with None -> failwith "timeout" | Some result -> result

let fire_if_not_already_fired cb result =
  if not (is_expired cb) then (
    if Ivar.is_full cb.signal then
      [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
    Ivar.fill cb.signal result )

let fire_exn cb result =
  if not (is_expired cb) then (
    if Ivar.is_full cb.signal then
      [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
    Ivar.fill cb.signal result )
