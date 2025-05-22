open Core_kernel

type ('accum, 'final) fold_action =
  { action : [ `Continue of 'accum | `Stop of 'final ]; slashed : bool }

module Make (ID : Hashtbl.Key) (Spec : T) : sig
  type job = (Spec.t, ID.t) Snark_work_lib.With_job_meta.t

  type job_item = job option ref

  type t

  val create : unit -> t

  val peek : t -> job option

  val fold_until :
       init:'accum
    -> f:('accum -> job -> ('accum, 'a option) fold_action)
    -> finish:('accum -> 'a option)
    -> t
    -> 'a option

  val attempt_add : key:ID.t -> job:job -> t -> [> `Duplicate | `Ok ]

  val slash : t -> ID.t -> job option

  val change : id:ID.t -> f:(job option -> job option) -> t -> unit

  val replace : id:ID.t -> job:job -> t -> unit

  val find : t -> ID.t -> job option

  val reissue_if_old :
    t -> reassignment_timeout:Core_kernel_private.Span_float.t -> job option
end
