open Snarky

type ('h, 'a, 'f) t

module type Inputs_intf = sig
  module M : Snark_intf.Run

  open M

  module Elt : sig
    type t

    val if_ : Boolean.var -> then_:t -> else_:t -> t
  end

  module Tree : Snarky_merkle_tree.S with module M = M and type Elt.t = Elt.t
end

module Make (Inputs : Inputs_intf) : sig
  open Inputs

  type nonrec t = (Tree.Hash.t, Elt.t, M.field) t

  val add : ?if_:M.Boolean.var -> t -> Elt.t -> t
end
