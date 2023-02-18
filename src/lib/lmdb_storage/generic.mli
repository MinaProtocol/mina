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

  val iter :
    env:t -> ('k, 'v) Db.t -> f:('k -> 'v -> [< `Continue | `Stop ]) -> unit
end

module Read_write : functor (F_func : F) -> sig
  type t

  module Db : Db

  type holder = F_func(Db).holder

  val create : string -> t * holder

  val get : env:t -> ('k, 'v) Db.t -> 'k -> 'v option

  val set : env:t -> ('k, 'v) Db.t -> 'k -> 'v -> unit

  val remove : env:t -> ('k, 'v) Db.t -> 'k -> unit

  val with_txn :
       ?perm:[ `Read | `Write ] Lmdb.perm
    -> f:(Db.getter -> Db.setter -> 'r)
    -> t
    -> 'r option

  val iter_ro :
    env:t -> ('k, 'v) Db.t -> f:('k -> 'v -> [< `Continue | `Stop ]) -> unit

  val iter :
       env:t
    -> ('k, 'v) Db.t
    -> f:
         (   'k
          -> 'v
          -> [< `Continue
             | `Remove_continue
             | `Remove_stop
             | `Stop
             | `Update_continue of 'v
             | `Update_stop of 'v ] )
    -> unit
end
