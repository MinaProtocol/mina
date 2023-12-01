open Core_kernel

module type S = sig
  type hash

  type elem = [ `Left of hash | `Right of hash ] [@@deriving sexp, equal]

  val elem_hash : elem -> hash

  type t = [ `Leaf_to_root of elem list ] [@@deriving sexp, equal]

  val implied_root : t -> hash -> hash

  val check_path : t -> hash -> hash -> bool
end

module Make (Hash : sig
  type t [@@deriving sexp, equal]

  val merge : height:int -> t -> t -> t

  val equal : t -> t -> bool
end) : S with type hash := Hash.t = struct
  type elem = [ `Left of Hash.t | `Right of Hash.t ] [@@deriving sexp, equal]

  let elem_hash = function `Left h | `Right h -> h

  type t = [ `Leaf_to_root of elem list ] [@@deriving sexp, equal]

  let implied_root (`Leaf_to_root path_to_root : t) leaf_hash =
    List.fold path_to_root ~init:(leaf_hash, 0) ~f:(fun (acc, height) elem ->
        let acc =
          match elem with
          | `Left h ->
              Hash.merge ~height acc h
          | `Right h ->
              Hash.merge ~height h acc
        in
        (acc, height + 1) )
    |> fst

  let check_path t leaf_hash root_hash =
    Hash.equal (implied_root t leaf_hash) root_hash
end
