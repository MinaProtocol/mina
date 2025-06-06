open Core_kernel

module Make (Id : Hashtbl.Key) (Spec : T) : sig
  type job = (Spec.t, Id.t) Snark_work_lib.With_job_meta.t

  (** [t] is a structure based on a hashmap that also keeps a queue of elements
      in the order they were added to the pool and allows to iterate in that
      order using [iter_until] and [remove_until_reschedule] functions. *)
  type t

  (** [create ()] creates an empty job pool *)
  val create : unit -> t

  (** [remove ~id t] removes job corresponding to [id] in [t] and returns it if
      it does exist. It's assumed that such ID would never be reused again,
      because the underlying queue is not cleaned for that [id]. *)
  val remove : id:Id.t -> t -> job option

  (** [find ~id t] finds the job corresponding to id [id] in [t]. *)
  val find : id:Id.t -> t -> job option

  (** [change_inplace ~id ~f t] attempts to find an item with id [id] in the
      pool, and apply [f] on it. The order of this item in the timeline is
      unchanged (hence "inplace" in the name). *)
  val change_inplace : id:Id.t -> f:(job option -> job option) -> t -> unit

  (** [remove_until_reschedule ~keep_condition ~should_reschedule t] iterates
      through the timeline, remove all jobs unsatisfying [keep_condition], and
      reschedule satisfying [should_reschedule j], where [j] is the first job
      satisfying [keep_condition], if it does exit. If [should_reschedule j]
      returns [Some _], that job is rescheduled at the end of the queue,
      otherwise the job is left unchanged at queue head. *)
  val remove_until_reschedule :
       keep_condition:(job -> bool)
    -> should_reschedule:(job -> job option)
    -> t
    -> job option

  (** [iter_until ~f t] iterates through the timeline, and returns first job
      satisfying [f] if it does exist. *)
  val iter_until : f:(job -> bool) -> t -> job option

  (** [add ~id ~job t] attempts to add a job [job] with id [id] to [t]. It
      returns [`Ok] on successful, and [`Duplicate] if the key [id] is already
      occupied in the pool. *)
  val add : id:Id.t -> job:job -> t -> [> `Duplicate | `Ok ]
end
