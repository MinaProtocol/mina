module T
    (Impl : Snarky_backendless.Snark_intf.Run)
    (N : Pickles_types.Vector.Nat_intf) =
struct
  open Impl

  type t = Field.t

  let length = 64 * Pickles_types.Nat.to_int N.n

  module Constant = Constant.Make (N)

  let typ : (Field.t, Constant.t) Typ.t =
    Typ.field
    |> Typ.transport
         ~there:(fun x -> Field.Constant.project (Constant.to_bits x))
         ~back:(fun x ->
           Constant.of_bits
             (Core_kernel.List.take (Field.Constant.unpack x) length) )
end
