open Core_kernel

type 'a scheduled = { job : 'a; scheduled : Time.t }

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
  val remove : id:Id.t -> t -> job scheduled option

  (** [find ~id t] finds the job corresponding to id [id] in [t]. *)
  val find : id:Id.t -> t -> job scheduled option

  (** [remove_until_reschedule ~f t] iterates through the timeline, for each
      encountered job [j], pattern match on [f j]:
      - If it's [`Remove], remove [j] and continue iteration;
      - If it's [`Stop_keep], stop the iteration and return [None];
      - If it's [`Stop_reschedule j'], reschedule [j'] at the end of timeline,
        and returns j' with scheduling metadata. *)
  val remove_until_reschedule :
       f:(job scheduled -> [< `Remove | `Stop_keep | `Stop_reschedule of job ])
    -> t
    -> job scheduled option

  (** [add_now ~id ~job t] attempts to add a job [job] with id [id] to [t], 
      marking scheduled timestamp as the current instant. It returns [`Ok] on 
      successful, and [`Duplicate] if the key [id] is already occupied in the 
      pool. *)
  val add_now : id:Id.t -> job:job -> t -> [> `Duplicate | `Ok ]

  (** [add_now_exn ~id ~job ~message t] works just like [add_now] excepts it 
      fails with [message] if the job is already in pool *)
  val add_now_exn : id:Id.t -> job:job -> message:string -> t -> unit
end
