(** Global slot span implementation *)

open Core_kernel

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Mina_numbers.Global_slot_span

type uint32 = Unsigned.uint32

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = sig
    include Global_slot_intf.S_span with type Stable.V1.t = A.V1.t
  end
end

module T = Nat.Make32 ()

module Make_str (_ : Wire_types.Concrete) = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Wire_types.global_slot_span = Global_slot_span of T.Stable.V1.t
      [@@unboxed] [@@deriving hash, sexp, compare, equal, yojson]

      let to_latest = Fn.id
    end
  end]

  let to_uint32 (Global_slot_span u32) : uint32 = u32

  let of_uint32 u32 : t = Global_slot_span u32

  module Checked = struct
    include T.Checked

    let constant t = constant @@ to_uint32 t

    let typ =
      Snark_params.Tick.Typ.transport T.Checked.typ ~there:to_uint32
        ~back:of_uint32
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

  let dhall_type = Ppx_dhall_type.Dhall_type.Text

  let zero = of_uint32 T.zero

  let one = of_uint32 T.one

  let succ t = of_uint32 (T.succ @@ to_uint32 t)

  let max_value = of_uint32 Unsigned.UInt32.max_int

  let to_field t = T.to_field (to_uint32 t)

  let to_input t = T.to_input (to_uint32 t)

  let to_input_legacy t = T.to_input_legacy (to_uint32 t)

  include Comparable.Make (Stable.Latest)

  let add t1 t2 =
    let u32_1 = to_uint32 t1 in
    let u32_2 = to_uint32 t2 in
    let sum = T.add u32_1 u32_2 in
    of_uint32 sum

  let sub t1 t2 =
    let u32_1 = to_uint32 t1 in
    let u32_2 = to_uint32 t2 in
    Option.map (T.sub u32_1 u32_2) ~f:of_uint32

  let of_int n = of_uint32 (T.of_int n)

  let to_int t = T.to_int (to_uint32 t)

  let random () = of_uint32 (T.random ())
end

include Wire_types.Make (Make_sig) (Make_str)
