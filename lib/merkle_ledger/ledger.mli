open Core

module type S =
  functor (Hash : sig 
       type hash [@@deriving sexp]
       type account [@@deriving sexp]
       val hash_account : account -> hash 
       val hash_unit : unit -> hash
       val merge : hash -> hash -> hash
     end)
    (Key : sig 
        type key [@@deriving sexp]
        include Hashable.S with type t = key
     end) -> sig

  type entry = 
    { merkle_index : int
    ; account : Hash.account }

  type key = Key.t

  type accounts = (key, entry) Hashtbl.t

  type leafs = key array

  type nodes = Hash.hash array list

  type tree = 
    { mutable leafs : leafs
    ; mutable nodes : nodes
    ; mutable dirty_indices : int list }

  type t = 
    { accounts : accounts
    ; tree : tree 
    } 
  [@@deriving sexp]

  type path_elem = 
    | Left of Hash.hash
    | Right of Hash.hash

  type path = path_elem list [@@deriving sexp]

  val create : unit -> t

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
