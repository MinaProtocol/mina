open Core

module type S =
  functor (Hash : sig 
       type hash [@@deriving sexp]
       type account [@@deriving sexp]
       val hash_account : account -> hash 
       val empty_hash : hash
       val merge : hash -> hash -> hash
     end)
    (Max_depth : sig val max_depth : int end)
    (Key : sig 
        type t [@@deriving sexp]
        include Hashable.S with type t := t
     end) -> sig

  type t
  [@@deriving sexp]

  type path_elem = 
    | Left of Hash.hash
    | Right of Hash.hash

  type path = path_elem list [@@deriving sexp]

  val create : int -> t

  val length : t -> int

  val get
    : t
    -> Key.t
    -> Hash.account option

  val update
    : t
    -> Key.t
    -> Hash.account
    -> unit

  val merkle_root
    : t
    -> Hash.hash

  val merkle_path
    : t
    -> Key.t
    -> path option
end

module Make : S
