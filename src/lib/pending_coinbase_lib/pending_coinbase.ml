(*open Core_kernel

type ('hash, 'coinbase_list) tree =
  | Leaf of 'hash * 'coinbase_list
  | Node of 'hash * ('hash, 'coinbase_list) tree * ('hash, 'coinbase_list) tree
[@@deriving bin_io, eq, sexp]

type index = int [@@deriving bin_io, sexp]

type ('hash, 'coinbase_list) t =
  { (*indexes: ('key, index) List.Assoc.t*)
    depth: int
  ; tree: ('hash, 'coinbase_list) tree }
[@@deriving bin_io, sexp] *)

(*let of_hash ~depth h = {depth; tree= Hash h}*)

(*module Ordered_collection : sig
  type 'a t

  val update : 'a t -> ('a -> 'a) -> 'a t

  val delete : 'a t -> ('a -> 'a) -> 'a t

  (*create*)
end = struct
  type 'a t = {data: 'a tree
  ;delete_at: Index.t (* set empty here and *)
  ;update_at: Index.t}

  let update _ _ = failwith ""

  let delete _ _ = failwith ""
end

module Stack = struct
  type 'a t = Pedersen.Digest.t

  let equal = Pedersen.Digest.equal

  let hash _ = failwith ""

  let to_bits _ = failwith ""

  let push t x = hash (to_bits t @ to_bits x)
end

module T : sig
  type t
  (* semantics: multiset of (Public_key.t * Amount.t) *)

  module Singleton : sig
    type t
  end

  val add
    : t -> Coinbase.t -> t
  (* semantics: multiset add *)

  val subtract
    : t -> t -> t
  (* semantics:
    multiset subtraction, failing if the second argument is not a subset of
    the first. *)

  val to_bits
    : t -> bool list
  (* This is just for hashing. The only semantics are that this function should
     be semantically injective *)

end = struct
  type t =  Coinbase.t Ordered_collection.t

  module Singleton = struct
    type t = Coinbase.t Stack.t
  end

  let to_bits _ = failwith ""

  let subtract t singleton_t = Ordered_collection.delete t (Stack.hash singleton_t)

  let add (t:t) (elt: Coinbase.t) =
    (* Actually, the index can also be computed correctly. *)
    let _index = exists Index.typ in
    Ordered_collection.update t (fun s -> Stack.push s elt)


  (* This is more complicated and dependent on the implementation of Ordered_collection *)
  (*let subtract = ...*)
end

*)

(*module Stack = struct
  type 'a t = 'a list

  let create () = []

  let add_coinbase t a = a :: t

end

module Make (Hash : sig
  type t [@@deriving bin_io, eq, sexp]

  val merge : height:int -> t -> t -> t
end)  (Coinbase : sig
  type t [@@deriving bin_io, eq, sexp]

  val hash : t -> Hash.t
end) =
struct
  type t_tmp = (Hash.t, Coinbase.t list) t [@@deriving bin_io, sexp]

  type t = t_tmp [@@deriving bin_io, sexp] *)

(*let of_hash = of_hash*)

(*let hash = function
    | Leaf (h, _) -> h
    | Node (h, _, _) -> h

  type index = int [@@deriving bin_io, sexp]

  let merkle_root {tree; _} = hash tree*)

(*let create ~depth = 
    let empty_lists  = List.init depth (fun _ -> [])
    in
    let 

end*)
