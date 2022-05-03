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

module type Metric_intf = sig
  val validations_timed_out : Mina_metrics.Counter.t

  val rejected : Mina_metrics.Counter.t

  val ignored : Mina_metrics.Counter.t

  module Validation_time : sig
    val update : Time.Span.t -> unit
  end
end

let metrics_of_message_type m : (module Metric_intf) option =
  match m with
  | `Unknown ->
      None
  | `Block ->
      Some (module Mina_metrics.Network.Block)
  | `Snark_work ->
      Some (module Mina_metrics.Network.Snark_work)
  | `Transaction ->
      Some (module Mina_metrics.Network.Transaction)

let record_timeout_metrics cb =
  Mina_metrics.(Counter.inc_one Network.validations_timed_out) ;
  match metrics_of_message_type cb.message_type with
  | None ->
      ()
  | Some (module M) ->
      Mina_metrics.Counter.inc_one M.validations_timed_out

let record_validation_metrics message_type (result : validation_result)
    validation_time =
  match metrics_of_message_type message_type with
  | None ->
      ()
  | Some (module M) -> (
      match result with
      | `Ignore ->
          Mina_metrics.Counter.inc_one M.ignored
      | `Accept ->
          M.Validation_time.update validation_time
      | `Reject ->
          Mina_metrics.Counter.inc_one M.rejected )

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
              Time_ns.abs_diff expires_at (Time_ns.now ())
              |> Time_ns.Span.to_ms |> Time.Span.of_ms
            in
            record_validation_metrics cb.message_type result validation_time ;
            Some result
        | `Timeout ->
            record_timeout_metrics cb ; None )

let await_exn cb =
  match%map await cb with None -> failwith "timeout" | Some result -> result

let fire_if_not_already_fired cb result =
  let logger = Logger.create () in
  [%log warn] "firing a validation callback with $result"
    ~metadata:
      [ ( "result"
        , `String
            ( match result with
            | `Accept ->
                "Accept"
            | `Reject ->
                "Reject"
            | `Ignore ->
                "Ignore" ) )
      ] ;
  if not (is_expired cb) then (
    if Ivar.is_full cb.signal then [%log error] "Ivar.fill bug is here!" ;
    Ivar.fill cb.signal result )

let set_message_type t x = t.message_type <- x
