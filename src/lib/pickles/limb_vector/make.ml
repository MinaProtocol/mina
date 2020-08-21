open Core_kernel
open Pickles_types

module T (Impl : Snarky_backendless.Snark_intf.Run) (N : Vector.Nat_intf) =
struct
  open Impl

  type t = Boolean.var list

  let to_bits = Fn.id

  let length = 64 * Nat.to_int N.n

  module Constant = Constant.Make (N)

  let typ : (t, Constant.t) Typ.t =
    Typ.list ~length Boolean.typ
    |> Typ.transport ~there:Constant.to_bits ~back:Constant.of_bits

  let packed_typ : (Field.t, Constant.t) Typ.t =
    Typ.field
    |> Typ.transport
         ~there:(fun x -> Field.Constant.project (Constant.to_bits x))
         ~back:(fun x ->
           Constant.of_bits (List.take (Field.Constant.unpack x) length) )
end
