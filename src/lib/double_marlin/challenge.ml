module Make (Impl : Snarky.Snark_intf.Run) = struct
  open Impl

  type t = Boolean.var list

  let length = 128

  module Constant = struct
    type t = bool list
  end

  let typ = Typ.list ~length Boolean.typ
end
