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

(*
module type Metric_intf = sig
  val validations_timed_out : Mina_metrics.Counter.t

  val rejected : Mina_metrics.Counter.t

  val ignored : Mina_metrics.Counter.t

  module Validation_time(Context : Mina_metrics.CONTEXT) : sig
    val update : Time.Span.t -> unit
  end

  module Processing_time(Context : Mina_metrics.CONTEXT) : sig
    val update : Time.Span.t -> unit
  end

  module Rejection_time(Context : Mina_metrics.CONTEXT) : sig
    val update : Time.Span.t -> unit
  end
end

let metrics_of_message_type m  =
  match m with
  | `Unknown ->
      None
  | `Block ->
      Some (Mina_metrics.Network.Block.validations_timed_out)
  | `Snark_work ->
      Some (Mina_metrics.Network.Snark_work.validations_timed_out)
  | `Transaction ->
      Some (Mina_metrics.Network.Transaction.validations_timed_out)

*)

let record_timeout_metrics cb =
  Mina_metrics.(Counter.inc_one Network.validations_timed_out) ;
  let counter =
    match cb.message_type with
    | `Unknown ->
        None
    | `Block ->
        Some Mina_metrics.Network.Block.validations_timed_out
    | `Snark_work ->
        Some Mina_metrics.Network.Snark_work.validations_timed_out
    | `Transaction ->
        Some Mina_metrics.Network.Transaction.validations_timed_out
  in
  Option.iter ~f:Mina_metrics.Counter.inc_one counter

let record_validation_metrics ~block_window_duration message_type
    (result : validation_result) validation_time processing_time =
  let open Mina_metrics.Network in
  let module Context = struct
    let block_window_duration = block_window_duration
  end in
  match message_type with
  | `Unknown ->
      ()
  | `Block -> (
      let module Validation_time = Block.Validation_time (Context) in
      let module Processing_time = Block.Processing_time (Context) in
      let module Rejection_time = Block.Rejection_time (Context) in
      match result with
      | `Ignore ->
          Mina_metrics.Counter.inc_one Block.ignored
      | `Accept ->
          Validation_time.update validation_time ;
          Processing_time.update processing_time
      | `Reject ->
          Mina_metrics.Counter.inc_one Block.rejected ;
          Rejection_time.update processing_time )
  | `Snark_work -> (
      let module Validation_time = Snark_work.Validation_time (Context) in
      let module Processing_time = Snark_work.Processing_time (Context) in
      let module Rejection_time = Snark_work.Rejection_time (Context) in
      match result with
      | `Ignore ->
          Mina_metrics.Counter.inc_one Block.ignored
      | `Accept ->
          Validation_time.update validation_time ;
          Processing_time.update processing_time
      | `Reject ->
          Mina_metrics.Counter.inc_one Block.rejected ;
          Rejection_time.update processing_time )
  | `Transaction -> (
      let module Validation_time = Transaction.Validation_time (Context) in
      let module Processing_time = Transaction.Processing_time (Context) in
      let module Rejection_time = Transaction.Rejection_time (Context) in
      match result with
      | `Ignore ->
          Mina_metrics.Counter.inc_one Block.ignored
      | `Accept ->
          Validation_time.update validation_time ;
          Processing_time.update processing_time
      | `Reject ->
          Mina_metrics.Counter.inc_one Block.rejected ;
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
  if not (is_expired cb) then (
    if Ivar.is_full cb.signal then
      [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
    Ivar.fill cb.signal result )

let set_message_type t x = t.message_type <- x
