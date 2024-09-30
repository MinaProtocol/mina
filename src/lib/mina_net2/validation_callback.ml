open Core
open Async
module Timeout = Timeout_lib.Core_time_ns

type validation_result = [ `Accept | `Reject | `Ignore ] [@@deriving equal]

type t =
  { expiration : Time_ns.t option
  ; created_at : Time_ns.t
  ; signal : validation_result Ivar.t
  ; mutable message_type : [ `Unknown | `Block | `Snark_work | `Transaction ]
  }

let create expiration =
  { expiration = Some expiration
  ; created_at = Time_ns.now ()
  ; signal = Ivar.create ()
  ; message_type = `Unknown
  }

let create_without_expiration () =
  { expiration = None
  ; created_at = Time_ns.now ()
  ; signal = Ivar.create ()
  ; message_type = `Unknown
  }

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

  module Processing_time : sig
    val update : Time.Span.t -> unit
  end

  module Rejection_time : sig
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
    validation_time processing_time ~block_window_duration:_ (*TODO remove*) =
  match metrics_of_message_type message_type with
  | None ->
      ()
  | Some (module M) -> (
      match result with
      | `Ignore ->
          Mina_metrics.Counter.inc_one M.ignored
      | `Accept ->
          let module Validation_time = M.Validation_time in
          Validation_time.update validation_time ;
          let module Processing_time = M.Processing_time in
          Processing_time.update processing_time
      | `Reject ->
          Mina_metrics.Counter.inc_one M.rejected ;
          let module Rejection_time = M.Rejection_time in
          Rejection_time.update processing_time )

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

let await ~block_window_duration cb =
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
            let processing_time =
              Time_ns.abs_diff (Time_ns.now ()) cb.created_at
              |> Time_ns.Span.to_ms |> Time.Span.of_ms
            in
            record_validation_metrics ~block_window_duration cb.message_type
              result validation_time processing_time ;
            Some result
        | `Timeout ->
            record_timeout_metrics cb ; None )

let await_exn ~block_window_duration cb =
  match%map await ~block_window_duration cb with
  | None ->
      failwith "timeout"
  | Some result ->
      result

let fire_if_not_already_fired cb result =
  if not (is_expired cb) then Ivar.fill_if_empty cb.signal result

let set_message_type t x = t.message_type <- x
