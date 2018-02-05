open Core

module type S =
  functor (Hash : sig 
       val hash_account : 'account -> 'hash 
       val hash_unit : unit -> 'hash
       val merge : 'hash -> 'hash -> 'hash
     end) -> sig

  type 'account entry = 
    { merkle_index : int
    ; account : 'account }

  type ('key, 'account) accounts = ('key, 'account entry) Hashtbl.t

  type 'key leafs = 'key array

  type 'hash nodes = 'hash array list

  type ('key, 'hash) tree = 
    { mutable leafs : 'key leafs
    ; mutable nodes : 'hash nodes
    ; mutable dirty_indices : int list }

  type ('hash, 'key, 'account) t = 
    { accounts : ('key, 'account) accounts
    ; tree : ('key, 'hash) tree 
    }

  type 'hash path_elem = 
    | Left of 'hash
    | Right of 'hash

  type 'hash path = 'hash path_elem list

  val get
    : ('hash, 'key, 'account) t
    -> 'key
    -> 'account option

  val update
    : ('hash, 'key, 'account) t
    -> 'key
    -> 'account
    -> unit

  val merkle_root
    : ('hash, 'key, 'account) t
    -> 'hash

  val merkle_path
    : ('hash, 'key, 'account) t
    -> 'key
    -> 'hash path option
end

module Make : S
