open Pickles_types
module Constant = Limb_vector.Constant.Make (Nat.N4)
module Make (Impl : Snarky.Snark_intf.Run) = Limb_vector.Make (Impl) (Nat.N4)

(*
let length = 256

module Constant = struct
end

module Make (Impl : Snarky.Snark_intf.Run) = struct
  open Impl

  type t = Field.t

  module Constant = Field.Constant

  module Unpacked = struct
    type t = Boolean.var list

    module Constant = struct
      type t = bool list
    end

    let assert_equal t1 t2 =
      assert (List.length t1 = length) ;
      assert (List.length t2 = length) ;
      Field.Assert.equal (Field.pack t1) (Field.pack t2)

    let typ = Typ.list ~length Boolean.typ
  end
end *)
