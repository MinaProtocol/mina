open Core_kernel

type uint32 = Unsigned.uint32

module type S = sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, compare]
    end
  end]

  module T : Intf.UInt32

  val to_uint32 : t -> uint32

  val of_uint32 : uint32 -> t
end

module Make (M : S) = struct
  type global_slot_span = Global_slot_span.t

  module T = M.T

  let to_uint32 = M.to_uint32

  let of_uint32 = M.of_uint32

  module Checked = struct
    include T.Checked

    type global_slot_span_checked = Global_slot_span.Checked.t

    let constant t = constant (to_uint32 t)

    open Snark_params.Tick

    let add t (span : global_slot_span_checked) =
      let t' = Global_slot_span.Checked.to_field span |> Unsafe.of_field in
      add t t'

    let sub t (span : global_slot_span_checked) =
      let t' = Global_slot_span.Checked.to_field span |> Unsafe.of_field in
      sub t t'

    let diff t1 t2 : global_slot_span_checked Checked.t =
      let%map diff = T.Checked.sub t1 t2 in
      let field = T.Checked.to_field diff in
      (* `of_field` is the identity function, here applied to a checked field *)
      Global_slot_span.Checked.Unsafe.of_field field

    let typ = Typ.transport T.Checked.typ ~there:to_uint32 ~back:of_uint32

    let diff_or_zero t1 t2 =
      let%map underflow, diff = T.Checked.sub_or_zero t1 t2 in
      let field = T.Checked.to_field diff in
      (* `of_field` is the identity function, here applied to a checked field *)
      let span = Global_slot_span.Checked.Unsafe.of_field field in
      (underflow, span)
  end

  let to_string t = Unsigned.UInt32.to_string @@ to_uint32 t

  let of_string s = of_uint32 @@ Unsigned.UInt32.of_string s

  let typ = Checked.typ

  let gen =
    let%map.Quickcheck u32 = T.gen in
    of_uint32 u32

  let gen_incl t1 t2 =
    let u32_1 = to_uint32 t1 in
    let u32_2 = to_uint32 t2 in
    let%map.Quickcheck u32 = T.gen_incl u32_1 u32_2 in
    of_uint32 u32

  let zero = of_uint32 T.zero

  let one = of_uint32 T.one

  let succ t =
    let u32 = to_uint32 t in
    of_uint32 (T.succ u32)

  let max_value = of_uint32 Unsigned.UInt32.max_int

  let to_field t = T.to_field (to_uint32 t)

  let to_input t = T.to_input (to_uint32 t)

  let to_input_legacy t = T.to_input_legacy (to_uint32 t)

  include Comparable.Make (M.Stable.Latest)

  let add t span =
    let u32_slot = to_uint32 t in
    let u32_span = Global_slot_span.to_uint32 span in
    let u32_sum = T.add u32_slot u32_span in
    of_uint32 u32_sum

  let sub t span =
    let u32_slot = to_uint32 t in
    let u32_span = Global_slot_span.to_uint32 span in
    Option.map (T.sub u32_slot u32_span) ~f:of_uint32

  let diff t1 t2 =
    let u32_1 = to_uint32 t1 in
    let u32_2 = to_uint32 t2 in
    Option.map (T.sub u32_1 u32_2) ~f:Global_slot_span.of_uint32

  let of_int n = of_uint32 (T.of_int n)

  let to_int t = T.to_int (to_uint32 t)

  let random () = of_uint32 (T.random ())
end
