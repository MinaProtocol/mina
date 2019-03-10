open Snarky
open Snark
open Bitstring_lib

type ('h, 'a, 'f) t =
  {tree: ('h, 'a) Snarky_merkle_tree.t; index: 'f Snarky_merkle_tree.Index.t}

module type Inputs_intf = sig
  module M : Snark_intf.Run

  open M

  module Elt : sig
    type t

    val if_ : Boolean.var -> then_:t -> else_:t -> t
  end

  module Tree : Snarky_merkle_tree.S with module M = M and type Elt.t = Elt.t
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  open M
  module T = Tree

  type nonrec t = (T.Hash.t, Elt.t, field) t

  (* In the context of Coda,
   the index could be excluded in computing the hash of
   this value since it can be inferred from the length of
   the blockchain, but we include it to prevent potential
   errors. *)

  let cond_incr_index ~max_size ~depth (b : Boolean.var) (index : T.Index.t) =
    let i = Field.(T.Index.to_field index + (b :> t)) in
    let overflow = Field.equal i (Field.of_int max_size) in
    let pushback = Field.of_int max_size in
    Field.(i - ((overflow :> Field.t) * pushback))
    |> T.Index.of_field_exn ~depth

  let add ?if_ {tree; index} elt =
    let should_add, update =
      match if_ with
      | None -> (Boolean.true_, fun _prev -> elt)
      | Some b -> (b, fun prev -> Elt.if_ b ~then_:prev ~else_:elt)
    in
    let next_index =
      cond_incr_index ~max_size:(T.max_size tree) ~depth:(T.depth tree)
        should_add index
    in
    {tree= T.modify tree index ~f:update; index= next_index}
end
