open Core
open Async
module Timeout = Timeout_lib.Core_time_ns

type validation_result = [ `Accept | `Reject | `Ignore ] [@@deriving equal]

type t =
  { expiration : Time_ns.t option
  ; signal : validation_result Ivar.t
  ; mutable message_type : [ `Unknown | `Block | `Snark_work | `Transaction ]
  }

let create expiration =
  { expiration = Some expiration
  ; signal = Ivar.create ()
  ; message_type = `Unknown
  }

let create_without_expiration () =
  { expiration = None; signal = Ivar.create (); message_type = `Unknown }

let is_expired cb =
  match cb.expiration with
  | None ->
      false
  | Some expires_at ->
      Time_ns.(now () >= expires_at)

let record_timeout_metrics cb =
  match cb.message_type with
  | `Unknown ->
      Mina_metrics.(Counter.inc_one Network.validations_timed_out)
  | `Block ->
      Mina_metrics.(Counter.inc_one Network.block_validations_timed_out)
  | `Snark_work ->
      Mina_metrics.(Counter.inc_one Network.snark_work_validations_timed_out)
  | `Transaction ->
      Mina_metrics.(Counter.inc_one Network.transaction_validations_timed_out)

let record_validation_metrics message_type (result : validation_result)
    validation_time =
  match (message_type, result) with
  | `Unknown, _ ->
      (*should not be unknown if the result was computed*)
      ()
  | `Block, `Ignore ->
      Mina_metrics.(Counter.inc_one Network.blocks_ignored)
  | `Block, `Reject ->
      Mina_metrics.(Counter.inc_one Network.blocks_rejected)
  | `Block, `Accept ->
      Mina_metrics.(Network.Block_validation_time.update validation_time)
  | `Snark_work, `Ignore ->
      Mina_metrics.(Counter.inc_one Network.snark_work_ignored)
  | `Snark_work, `Reject ->
      Mina_metrics.(Counter.inc_one Network.snark_work_rejected)
  | `Snark_work, `Accept ->
      Mina_metrics.(Network.Snark_work_validation_time.update validation_time)
  | `Transaction, `Ignore ->
      Mina_metrics.(Counter.inc_one Network.transactions_ignored)
  | `Transaction, `Reject ->
      Mina_metrics.(Counter.inc_one Network.transactions_rejected)
  | `Transaction, `Accept ->
      Mina_metrics.(Network.Transaction_validation_time.update validation_time)

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
  if is_expired cb then (record_timeout_metrics cb ; Deferred.return None)
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
            let validation_time =
              Time_ns.diff expires_at (Time_ns.now ())
              |> Time_ns.Span.to_ms |> Time.Span.of_ms
            in
            record_validation_metrics cb.message_type result validation_time ;
            Some result
        | `Timeout ->
            record_timeout_metrics cb ; None )

let await_exn cb =
  match%map await cb with None -> failwith "timeout" | Some result -> result

let fire_if_not_already_fired cb result =
  if not (is_expired cb) then (
    if Ivar.is_full cb.signal then
      [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
    Ivar.fill cb.signal result )

let set_message_type t x = t.message_type <- x
