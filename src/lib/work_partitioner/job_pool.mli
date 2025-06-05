open Core_kernel

module Make (Id : Hashtbl.Key) (Spec : T) : sig
  type job = (Spec.t, Id.t) Snark_work_lib.With_job_meta.t

  (** [t] is a structure based on a hashmap that also keeps a queue of elements
      in the order they were added to the pool and allows to iterate in that
      order using iter_until and remove_until functions. *)
  type t

  (** [create ()] creates an empty job pool *)
  val create : unit -> t

  (** [remove ~id t] removes job corresponding to [id] in [t] and returns it if
      it does exist *)
  val remove : id:Id.t -> t -> job option

  (** [find ~id t] finds the job corresponding to id [id] in [t]. *)
  val find : id:Id.t -> t -> job option

  (** [change_inplace ~id ~f t] attempts to find an item with id [id] in the
      pool, and apply [f] on it. The order of this item in the timeline is
      unchanged (hence "inplace" in the name). *)
  val change_inplace : id:Id.t -> f:(job option -> job option) -> t -> unit

  (** [set_inplace ~id ~job t] sets the index [id] to [job] in [t] no matter if [id] is
      occupied or not. The order of this item in the timeline is unchanged (hence
      "inplace" in the name). *)
  val set_inplace : id:Id.t -> job:job -> t -> unit

  (** [remove_until ~f t] iterates through the timeline, remove all jobs
      unsatisfying [f], and returns first job satisfying [f] if it does exit. *)
  val remove_until : f:(job -> bool) -> t -> job option

  (** [iter_until ~f t] iterates through the timeline, and returns first job
      satisfying [f] if it does exist. *)
  val iter_until : f:(job -> bool) -> t -> job option

  (** [add ~id ~job t] attempts to add a job [job] with id [id] to [t]. It
      returns [`Ok] on successful, and [`Duplicate] if the key [id] is already
      occupied in the pool. *)
  val add : id:Id.t -> job:job -> t -> [> `Duplicate | `Ok ]
end
