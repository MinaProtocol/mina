open Rugelach_types
module Constant = Limb_vector.Constant.Make (Nat.N2)
module Make (Impl : Snarky.Snark_intf.Run) = Limb_vector.Make (Impl) (Nat.N2)
