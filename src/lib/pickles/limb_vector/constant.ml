open Core_kernel
open Pickles_types

type 'n t = (Int64.t, 'n) Vector.t [@@deriving sexp_of]

let to_bits t =
  Vector.to_list t
  |> List.concat_map ~f:(fun n ->
         let test_bit i = Int64.(shift_right n i land one = one) in
         List.init 64 ~f:test_bit )

module Hex64 = struct
  module T = struct
    type t = Int64.t [@@deriving yojson]

    (* Modify the [of_yojson] handler to add a case for [`String].
       This isn't necessary when using Yojson's parser, because it will
       correctly infer [`Intlit] for any possible value that appears here.
       However, if this json was constructed from a GraphQL query then it will
       be encoded as a [`String] and the conversion will fail unless we handle
       it ourselves.
    *)
    let of_yojson yojson =
      match yojson with
      | `String x -> (
          try Result.Ok (Int64.of_string x)
          with _ -> Result.Error "Constant.Make.Hex64.t" )
      | _ ->
          of_yojson yojson

    include (Int64 : module type of Int64 with type t := t)

    let to_hex t =
      let lo = t land of_int 0xffffff in
      let mi = (t lsr 24) land of_int 0xffffff in
      let hi = (t lsr 48) land of_int 0xffff in
      sprintf "%04x%06x%06x" (to_int_exn hi) (to_int_exn mi) (to_int_exn lo)

    let of_hex h =
      let f s = Hex.of_string ("0x" ^ s) in
      let hi, lo = String.(f (sub h ~pos:0 ~len:8), f (sub h ~pos:8 ~len:8)) in
      (hi lsl 32) lor lo

    let%test_unit "int64 hex" =
      Quickcheck.test (Int64.gen_incl zero max_value) ~f:(fun x ->
          assert (equal x (of_hex (to_hex x))) )

    let sexp_of_t = Fn.compose String.sexp_of_t to_hex

    let t_of_sexp = Fn.compose of_hex String.t_of_sexp
  end

  include T

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = (T.t[@version_asserted])
      [@@deriving compare, sexp, yojson, hash, equal]

      let to_latest = Fn.id
    end
  end]
end

module Make (N : Vector.Nat_intf) = struct
  module A = Vector.With_length (N)

  let length = 64 * Nat.to_int N.n

  type t = Hex64.t A.t [@@deriving sexp, compare, yojson, hash, equal]

  let to_bits = to_bits

  let of_bits bits =
    let pack =
      List.foldi ~init:Int64.zero ~f:(fun i acc b ->
          if b then Int64.(acc lor shift_left one i) else acc )
    in
    let bits =
      List.groupi ~break:(fun i _ _ -> i mod 64 = 0) bits |> List.map ~f:pack
    in
    let n = List.length bits in
    let n_expected = Nat.to_int N.n in
    assert (n <= n_expected) ;
    let bits = bits @ List.init (n_expected - n) ~f:(fun _ -> Int64.zero) in
    Vector.of_list_and_length_exn bits N.n

  let of_tick_field x =
    of_bits (List.take (Backend.Tick.Field.to_bits x) length)

  let of_tock_field x =
    of_bits (List.take (Backend.Tock.Field.to_bits x) length)

  let to_tick_field t = Backend.Tick.Field.of_bits (to_bits t)

  let to_tock_field t = Backend.Tock.Field.of_bits (to_bits t)

  let dummy : t = Vector.init N.n ~f:(fun _ -> Int64.one)

  let zero : t = Vector.init N.n ~f:(fun _ -> Int64.zero)
end
