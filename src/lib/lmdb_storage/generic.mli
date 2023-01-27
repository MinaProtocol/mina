module type Db = sig
  module T : sig
    type ('k, 'v) t
  end

  include module type of Intf.Db (T)
end

type config =
  { initial_mmap_size : int
  ; mmap_growth_factor : float
  ; mmap_growth_max_step : int
  }

val default_config : config

module type F = functor (Db : Db) -> sig
  type holder

  val mk_maps : Db.creator -> holder

  val config : config
end

module Read_only : functor (F_func : F) -> sig
  type t

  module Db : Db

  type holder = F_func(Db).holder

  val create : string -> t * holder

  val get : env:t -> ('k, 'v) Db.t -> 'k -> 'v option

  val with_txn : f:(Db.getter -> 'r) -> t -> 'r option
end

module Read_write : functor (F_func : F) -> sig
  type t

  module Db : Db

  type holder = F_func(Db).holder

  val create : string -> t * holder

  val get : env:t -> ('k, 'v) Db.t -> 'k -> 'v option

  val set : env:t -> ('k, 'v) Db.t -> 'k -> 'v -> unit

  val with_txn :
       ?perm:[ `Read | `Write ] Lmdb.perm
    -> f:(Db.getter -> Db.setter -> 'r)
    -> t
    -> 'r option
end
