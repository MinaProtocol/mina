open Pickles_types
module Constant = Constant.Make (Nat.N4)
module Make (Impl : Snarky.Snark_intf.Run) = Make.T (Impl) (Nat.N4)
