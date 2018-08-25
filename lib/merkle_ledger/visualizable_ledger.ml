open Core

module type Ledger_intf = sig
  type t

  type hash [@@deriving sexp, eq]

  val max_depth : int

  val get_inner_hash_at_addr_exn : t -> Direction.t list -> hash
end

module Make (L : Ledger_intf) = struct
  type t = L.t

  type tree =
    | Leaf of (Direction.t list * L.hash)
    | Node of (Direction.t list * L.hash * tree * tree)
  [@@deriving sexp, eq]

  let to_tree t =
    let rec go i dirs =
      if i = L.max_depth then Leaf (dirs, L.get_inner_hash_at_addr_exn t dirs)
      else
        let hash = L.get_inner_hash_at_addr_exn t dirs in
        let left = go (i + 1) (dirs @ [Direction.Left]) in
        let right = go (i + 1) (dirs @ [Direction.Right]) in
        Node (dirs, hash, left, right)
    in
    go 0 []
end
