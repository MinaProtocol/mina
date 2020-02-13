[%%import
"/src/config.mlh"]

open Async_kernel
open Core_kernel
open Snark_params
open Tick
open Unsigned_extended
open Snark_bits

(* Milliseconds since epoch *)
[%%versioned
module Stable = struct
  module V1 = struct
    type t = UInt64.Stable.V1.t [@@deriving sexp, compare, eq, hash, yojson]

    let to_latest = Fn.id

    module T = struct
      type typ = t [@@deriving sexp, compare, hash]

      type t = typ [@@deriving sexp, compare, hash]
    end

    include Hashable.Make (T)
  end
end]

module Controller = struct
  [%%if
  time_offsets]

  type t = Time.Span.t Lazy.t

  let create offset = offset

  let basic ~logger =
    lazy
      (let offset =
         match Core.Sys.getenv "CODA_TIME_OFFSET" with
         | Some tm ->
             Int.of_string tm
         | None ->
             Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
               "Environment variable CODA_TIME_OFFSET not found, using \
                default of 0" ;
             0
       in
       Core_kernel.Time.Span.of_int_sec offset)

  [%%else]

  type t = unit

  let create () = ()

  let basic ~logger:_ = ()

  [%%endif]
end

type t = Stable.Latest.t [@@deriving sexp, compare, hash, yojson]

type time = t

module B = Bits
module Bits = Bits.UInt64
include B.Snarkable.UInt64 (Tick)

module Span = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = UInt64.Stable.V1.t [@@deriving sexp, compare]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare]

  module Bits = B.UInt64
  include B.Snarkable.UInt64 (Tick)

  let of_time_span s = UInt64.of_int64 (Int64.of_float (Time.Span.to_ms s))

  let to_time_ns_span s =
    Time_ns.Span.of_ms (Int64.to_float (UInt64.to_int64 s))

  let to_string_hum s = to_time_ns_span s |> Time_ns.Span.to_string_hum

  let to_ms = UInt64.to_int64

  let of_ms = UInt64.of_int64

  let ( + ) = UInt64.Infix.( + )

  let ( - ) = UInt64.Infix.( - )

  let ( * ) = UInt64.Infix.( * )

  let ( < ) = UInt64.( < )

  let ( > ) = UInt64.( > )

  let ( = ) = UInt64.( = )

  let ( <= ) = UInt64.( <= )

  let ( >= ) = UInt64.( >= )

  let min = UInt64.min

  let zero = UInt64.zero
end

include Comparable.Make (Stable.Latest)
include Hashable.Make (Stable.Latest)

let of_time t =
  UInt64.of_int64
    (Int64.of_float (Time.Span.to_ms (Time.to_span_since_epoch t)))

let to_time t =
  Time.of_span_since_epoch
    (Time.Span.of_ms (Int64.to_float (UInt64.to_int64 t)))

[%%if
time_offsets]

let now offset = of_time (Time.sub (Time.now ()) (Lazy.force offset))

[%%else]

let now _ = of_time (Time.now ())

[%%endif]

let field_var_to_unpacked (x : Tick.Field.Var.t) =
  Tick.Field.Checked.unpack ~length:64 x

let epoch = of_time Time.epoch

let add x y = UInt64.add x y

let diff x y = UInt64.sub x y

let sub x y = UInt64.sub x y

let to_span_since_epoch t = diff t epoch

let of_span_since_epoch s = UInt64.add s epoch

let diff_checked x y =
  let pack = Tick.Field.Var.project in
  Span.unpack_var Tick.Field.Checked.(pack x - pack y)

let modulus t span = UInt64.rem t span

let unpacked_to_number var =
  let bits = Span.Unpacked.var_to_bits var in
  Number.of_bits (bits :> Boolean.var list)

let to_int64 = Fn.compose Span.to_ms to_span_since_epoch

let of_int64 = Fn.compose of_span_since_epoch Span.of_ms

let to_string = Fn.compose Int64.to_string to_int64

let of_string_exn string =
  Int64.of_string string |> Span.of_ms |> of_span_since_epoch

let gen_incl time_beginning time_end =
  let open Quickcheck.Let_syntax in
  let time_beginning_int64 = to_int64 time_beginning in
  let time_end_int64 = to_int64 time_end in
  let%map int64_time_span =
    Int64.(gen_incl time_beginning_int64 time_end_int64)
  in
  of_span_since_epoch @@ Span.of_ms int64_time_span

let gen =
  let open Quickcheck.Let_syntax in
  let%map int64_time_span = Int64.(gen_incl zero max_value) in
  of_span_since_epoch @@ Span.of_ms int64_time_span

module Timeout = struct
  type 'a t =
    { deferred: 'a Deferred.t
    ; cancel: 'a -> unit
    ; start_time: time
    ; span: Span.t
    ; ctrl: Controller.t }

  let create ctrl span ~f:action =
    let open Deferred.Let_syntax in
    let cancel_ivar = Ivar.create () in
    let timeout = after (Span.to_time_ns_span span) >>| fun () -> None in
    let deferred =
      Deferred.any [Ivar.read cancel_ivar; timeout]
      >>| function None -> action (now ctrl) | Some x -> x
    in
    let cancel value = Ivar.fill_if_empty cancel_ivar (Some value) in
    {ctrl; deferred; cancel; start_time= now ctrl; span}

  let to_deferred {deferred; _} = deferred

  let peek {deferred; _} = Deferred.peek deferred

  let cancel _ {cancel; _} value = cancel value

  let remaining_time {ctrl: _; start_time; span; _} =
    let current_time = now ctrl in
    let time_elapsed = diff current_time start_time in
    Span.(span - time_elapsed)

  let await ~timeout_duration time_controller deferred =
    let timeout =
      Deferred.create (fun ivar ->
          ignore (create time_controller timeout_duration ~f:(Ivar.fill ivar))
      )
    in
    Deferred.(
      choose
        [choice deferred (fun x -> `Ok x); choice timeout (Fn.const `Timeout)])

  let await_exn ~timeout_duration time_controller deferred =
    let open Deferred.Let_syntax in
    match%map await ~timeout_duration time_controller deferred with
    | `Timeout ->
        failwith "timeout"
    | `Ok x ->
        x
end

module Timer = struct
  type t =
    { time_controller: Controller.t
    ; f: unit -> unit
    ; span: Span.t
    ; mutable timeout: unit Timeout.t option }

  let create time_controller span ~f = {time_controller; span; f; timeout= None}

  let start t =
    assert (Option.is_none t.timeout) ;
    let rec run_timeout t =
      t.timeout
      <- Some
           (Timeout.create t.time_controller t.span ~f:(fun _ ->
                t.f () ; run_timeout t ))
    in
    run_timeout t

  let stop t =
    Option.iter t.timeout ~f:(fun timeout ->
        Timeout.cancel t.time_controller timeout () ) ;
    t.timeout <- None

  let reset t = stop t ; start t
end
