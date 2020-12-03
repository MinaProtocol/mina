open Core_kernel
open Pickles_types

module T (Impl : Snarky_backendless.Snark_intf.Run) (N : Vector.Nat_intf) =
struct
  open Impl

  type t = Boolean.var list

  let to_bits = Fn.id

  let length = 64 * Nat.to_int N.n

  module Constant = Constant.Make (N)

  let typ' bool : (t, Constant.t) Typ.t =
    Typ.list ~length bool
    |> Typ.transport ~there:Constant.to_bits ~back:Constant.of_bits

  let typ : (t, Constant.t) Typ.t = typ' Boolean.typ

  let typ_unchecked : (t, Constant.t) Typ.t = typ' Boolean.typ_unchecked

  let typ' = function `Constrained -> typ | `Unconstrained -> typ_unchecked

  let packed_typ : (Field.t, Constant.t) Typ.t =
    Typ.field
    |> Typ.transport
         ~there:(fun x -> Field.Constant.project (Constant.to_bits x))
         ~back:(fun x ->
           Constant.of_bits (List.take (Field.Constant.unpack x) length) )
end
