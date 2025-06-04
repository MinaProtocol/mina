open Core_kernel

type ('accum, 'final) fold_action =
  | Continue of 'accum
  | Continue_remove of 'accum
  | Stop of 'final
  | Stop_remove of 'final

module Make (Id : Map.Key) (Spec : T) : sig
  type job = (Spec.t, Id.t) Snark_work_lib.With_job_meta.t

  (** [t] is a immutable job pool, it differs from a normal Map in that jobs
      could be canceled with [fold_until]. *)
  type t

  (** [first_job t] gives the job with smalled ID in the pool. *)
  val first_job : t -> job option

  (** [fold_until ~init ~f ~finish t] will fold all jobs in the pool in
      monotonically increasing order with repsect to ID. In addition, user may
      instruct this function to delete the items along the process. *)
  val fold_until :
       init:'acc
    -> f:('acc -> job -> ('acc, 'final) fold_action)
    -> finish:('acc -> 'final)
    -> t
    -> 'final * t

  (** [add ~id ~job t] attempts to add a job [job] with id [id] to [t]. It
      returns [`Ok t'] on successful with the new data structure, and
      [`Duplicate] if the key [id] is already occupied in the pool. *)
  val add : id:Id.t -> job:job -> t -> t Map_intf.Or_duplicate.t

  (** [change ~id ~f t] attempts to find an item with id [id] in the pool, and apply
      [f] on it. *)
  val change : id:Id.t -> f:(job option -> job option) -> t -> t

  (** [set ~id ~job t] sets the index [id] to [job] in [t] no matter if [id] is
      occupied or not. *)
  val set : id:Id.t -> job:job -> t -> t

  (** [find ~id t] finds the job corresponding to id [id] in [t]. *)
  val find : id:Id.t -> t -> job option
end
