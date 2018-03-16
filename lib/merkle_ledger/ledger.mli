open Core

module type S =
  functor (Hash : sig 
       type hash [@@deriving sexp]
       type account [@@deriving sexp]
       val hash_account : account -> hash 
       val hash_unit : hash
       val hash_unit_tree_depth : int -> hash
       val merge : hash -> hash -> hash
     end)
    (Key : sig 
        type t [@@deriving sexp]
        include Hashable.S with type t := t
     end) -> sig

  type entry = 
    { merkle_index : int
    ; account : Hash.account }

  type key = Key.t

  type accounts = (key, entry) Hashtbl.t
                 
  module DynArray : sig
    type 'a t
  end

  type leafs = key DynArray.t [@@deriving sexp]

  type nodes = Hash.hash DynArray.t list [@@deriving sexp]

  type tree = 
    { leafs : leafs
    ; mutable nodes : nodes
    ; mutable dirty_indices : int list }
  [@@deriving sexp]

  type t = 
    { accounts : accounts
    ; tree : tree 
    ; depth : int
    } 
  [@@deriving sexp]

  type path_elem = 
    | Left of Hash.hash
    | Right of Hash.hash

  type path = path_elem list [@@deriving sexp]

  val create : int -> t

  val length : t -> int

  val get
    : t
    -> key
    -> Hash.account option

  val update
    : t
    -> key
    -> Hash.account
    -> unit

  val merkle_root
    : t
    -> Hash.hash

  val merkle_path
    : t
    -> key
    -> path option
end

module Make : S
