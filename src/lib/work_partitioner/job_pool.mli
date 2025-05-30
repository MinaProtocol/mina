open Core

type ('accum, 'final) fold_action =
  | Continue of 'accum
  | Continue_remove of 'accum
  | Stop of 'final
  | Stop_remove of 'final

module Make (Id : Map.Key) (Spec : T) : sig
  type job = (Spec.t, Id.t) Snark_work_lib.With_job_meta.t

  module IdMap : module type of Map.Make (Id)

  type t = job IdMap.t

  val peek : job IdMap.t -> job option

  val fold_until :
       init:'a
    -> f:('a -> 'b -> ('a, 'c) fold_action)
    -> finish:('a -> 'c)
    -> 'b IdMap.t
    -> 'c * 'b IdMap.t

  val attempt_add :
    id:Id.t -> job:'a -> 'a IdMap.t -> 'a IdMap.t Map_intf.Or_duplicate.t

  val change : id:Id.t -> f:('a option -> 'a option) -> 'a IdMap.t -> 'a IdMap.t

  val set : id:Id.t -> job:'a -> 'a IdMap.t -> 'a IdMap.t

  val find : id:Id.t -> 'a IdMap.t -> 'a option
end
