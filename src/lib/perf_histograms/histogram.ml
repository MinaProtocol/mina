open Core_kernel

(** Loosely modelled on https://chromium.googlesource.com/chromium/src/+/HEAD/tools/metrics/histograms/README.md *)

module Make (Elem : sig
  type t [@@deriving yojson, bin_io]

  module Params : sig
    type t0 = t

    type t

    val buckets : t -> int

    val create : ?min:t0 -> ?max:t0 -> ?buckets:int -> unit -> t
  end

  val bucket : params:Params.t -> t -> [`Index of int | `Overflow | `Underflow]

  val interval_of_bucket : params:Params.t -> int -> t * t
end) =
struct
  type t =
    { buckets: int Array.t
    ; intervals: (Elem.t * Elem.t) List.t
    ; mutable underflow: int
    ; mutable overflow: int
    ; params: Elem.Params.t }

  let create ?buckets ?min ?max () =
    let params = Elem.Params.create ?min ?max ?buckets () in
    let intervals =
      List.init (Elem.Params.buckets params) ~f:(fun i ->
          Elem.interval_of_bucket ~params i )
    in
    { buckets= Array.init (Elem.Params.buckets params) ~f:(fun _ -> 0)
    ; intervals
    ; underflow= 0
    ; overflow= 0
    ; params }

  let clear t =
    Array.fill t.buckets ~pos:0 ~len:(Array.length t.buckets) 0 ;
    t.underflow <- 0 ;
    t.overflow <- 0

  module Pretty = struct
    type t =
      { values: int list
      ; intervals: (Elem.t * Elem.t) list
      ; underflow: int
      ; overflow: int }
    [@@deriving yojson, bin_io]
  end

  let report {intervals; buckets; underflow; overflow; params= _} =
    {Pretty.values= Array.to_list buckets; intervals; underflow; overflow}

  let add ({params; _} as t) e =
    match Elem.bucket ~params e with
    | `Index i -> Array.replace t.buckets i ~f:Int.succ
    | `Overflow -> t.overflow <- t.overflow + 1
    | `Underflow -> t.underflow <- t.underflow + 1
end

module Exp_time_spans = Make (struct
  (** Note: All time spans are represented in JSON as floating point millis *)
  type t = Time.Span.t [@@deriving bin_io]

  let to_yojson t = `Float (Time.Span.to_ms t)

  let of_yojson t =
    let open Ppx_deriving_yojson_runtime in
    match t with
    | `Float ms -> Result.Ok (Time.Span.of_ms ms)
    | _ -> Result.Error "Not a floating point milliseconds value"

  module Params = struct
    type t0 = t

    type t = {a: float; b: float; buckets: int}

    let buckets {buckets; _} = buckets

    (* See http://mathworld.wolfram.com/LeastSquaresFittingLogarithmic.html *)
    let fit min max buckets =
      let x0, y0 = (Time.Span.to_ms min, Float.zero) in
      let x1, y1 = (Time.Span.to_ms max, Float.of_int buckets) in
      let n = 2.0 in
      let sum f = f (x0, y0) +. f (x1, y1) in
      let b =
        let num =
          let f1 (x, y) = y *. Float.log x in
          let f2 (_, y) = y in
          let f3 (x, _) = Float.log x in
          let left = n *. sum f1 in
          let right = sum f2 *. sum f3 in
          left -. right
        in
        let denom =
          let f1 (x, _) =
            let lnx = Float.log x in
            lnx *. lnx
          in
          let f2 (x, _) = Float.log x in
          let right = sum f2 in
          (n *. sum f1) -. (right *. right)
        in
        num /. denom
      in
      let a =
        let num =
          let f1 (_, y) = y in
          let f2 (x, _) = Float.log x in
          sum f1 -. (b *. sum f2)
        in
        num /. n
      in
      (a, b)

    let create ?(min = Time.Span.of_sec 1.) ?(max = Time.Span.of_min 5.)
        ?(buckets = 50) () =
      let a, b = fit min max buckets in
      {a; b; buckets}
  end

  let interval_of_bucket ~params:{Params.a; b; _} i =
    (* f-1(y) = e^{y/b - a/b} *)
    let f_1 y =
      let y = Float.of_int y in
      Float.exp ((y /. b) -. (a /. b))
    in
    (Time.Span.of_ms (f_1 i), Time.Span.of_ms (f_1 (i + 1)))

  let bucket ~params:{Params.a; b; buckets} span =
    let x = Time.Span.to_ms span in
    if Float.( <= ) x 0.0 then `Underflow
    else
      (* y = a + b log(x) *)
      let res = a +. (b *. Float.log x) |> Int.of_float in
      if res >= buckets then `Overflow
      else if res < 0 then `Underflow
      else `Index res
end)

let%test_unit "reports properly with overflows and underflows and table hits" =
  let open Exp_time_spans in
  let tbl =
    create ~buckets:50 ~min:(Time.Span.of_ms 1.) ~max:(Time.Span.of_day 1.) ()
  in
  let r = report tbl in
  assert (r.Pretty.underflow = 0) ;
  assert (r.Pretty.overflow = 0) ;
  (* underflow *)
  add tbl (Time.Span.of_us 100.) ;
  (* in the table *)
  add tbl (Time.Span.of_ms 100.) ;
  add tbl (Time.Span.of_sec 100.) ;
  add tbl (Time.Span.of_day 0.5) ;
  (* overflow *)
  add tbl (Time.Span.of_day 2.) ;
  let r = report tbl in
  assert (List.sum ~f:Fn.id (module Int) r.Pretty.values = 3) ;
  assert (r.Pretty.underflow = 1) ;
  assert (r.Pretty.overflow = 1)
