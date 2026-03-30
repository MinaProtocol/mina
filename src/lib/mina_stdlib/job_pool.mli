open Core_kernel

type 'a scheduled = { job : 'a; scheduled : Time.t }

module Make
    (Id : Hashtbl.Key) (Job : sig
      type t

      val id : t -> Id.t
    end) : sig
  (** [t] is a structure based on a hashmap that also keeps a queue of elements
      in the order they were added to the pool and allows to iterate in that
      order using [iter_until] and [remove_until_reschedule] functions. *)
  type t

  (** [create ()] creates an empty job pool *)
  val create : unit -> t

  (** [remove ~id t] removes job corresponding to [id] in [t] and returns it if
      it does exist. It's assumed that such ID would never be reused again,
      because the underlying queue is not cleaned for that [id]. *)
  val remove : id:Id.t -> t -> Job.t scheduled option

  (** [find ~id t] finds the job corresponding to id [id] in [t]. *)
  val find : id:Id.t -> t -> Job.t scheduled option

  (** [remove_until_reschedule ~f t] iterates through the timeline, for each
      encountered job [j], pattern match on [f j]:
      - If it's [`Remove], remove [j] and continue iteration;
      - If it's [`Stop_keep], stop the iteration and return [None];
      - If it's [`Stop_reschedule j'], reschedule [j'] at the end of timeline,
        and returns j' with scheduling metadata. *)
  val remove_until_reschedule :
       f:
         (   Job.t scheduled
          -> [< `Remove | `Stop_keep | `Stop_reschedule of Job.t ] )
    -> t
    -> Job.t scheduled option

  (** [add_now ~job t] attempts to add a job [job] to [t], 
      marking scheduled timestamp as the current instant. It returns [`Ok time]
      on successful with the scheduled time, and [`Duplicate] if the job's id is
      already occupied in the pool. *)
  val add_now : job:Job.t -> t -> [> `Duplicate | `Ok of Time.t ]

  (** [add_now_exn ~job ~message t] works just like [add_now] excepts it 
      fails with [message] if the job is already in pool *)
  val add_now_exn : job:Job.t -> message:string -> t -> Time.t

  (** [replace_now ~job t] adds a job to the pool, and if it exsits, remove it 
      and replacing it with now as the new time, and returning the time. *)
  val replace_now : job:Job.t -> t -> Time.t

  (** [fold ~init ~f t] fold through all scheduled jobs ordered by time scheduled *)
  val fold : init:'a -> f:('a -> Job.t scheduled -> 'a) -> t -> 'a

  (** [to_list t] get a list of all jobs in scheduled jobs ordered time scheduled *)
  val to_list : t -> Job.t scheduled list
end
