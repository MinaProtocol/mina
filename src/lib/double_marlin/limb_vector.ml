open Core_kernel
open Pickles_types

module Constant = struct
  type 'n t = (Int64.t, 'n) Vector.t

  let to_bits t =
    Vector.to_list t
    |> List.concat_map ~f:(fun n ->
           let test_bit i = Int64.(shift_right n i land one = one) in
           List.init 64 ~f:test_bit )

  module Make (N : Vector.Nat_intf) = struct
    module A = struct
      type 'a t = ('a, N.n) Vector.t

      include Vector.Binable (N)
    end

    type t = Int64.t A.t [@@deriving bin_io]

    let to_bits = to_bits

    let of_bits bits =
      let pack =
        List.foldi ~init:Int64.zero ~f:(fun i acc b ->
            if b then Int64.(acc lor shift_left one i) else acc )
      in
      let bits =
        List.groupi ~break:(fun i _ _ -> i mod 64 = 0) bits |> List.map ~f:pack
      in
      Vector.take_from_list bits N.n
  end
end

module Make (Impl : Snarky.Snark_intf.Run) (N : Vector.Nat_intf) = struct
  open Impl

  type t = Boolean.var list

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
