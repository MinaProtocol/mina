open Core_kernel

module Make (Id : Hashtbl.Key) (Spec : T) = struct
  type job = (Spec.t, Id.t) Snark_work_lib.With_job_meta.t

  type t =
    { timeline : Id.t Deque.t (* For iteration *)
    ; index : (Id.t, job) Hashtbl.t (* For marking job as done *)
    }

  let create () =
    { timeline = Deque.create (); index = Hashtbl.create (module Id) }

  let remove ~id t = Hashtbl.find_and_remove t.index id

  let find ~id t = Hashtbl.find t.index id

  let change_inplace ~id ~f t = Hashtbl.change t.index id ~f

  let rec remove_until_reschedule ~keep_condition ~should_reschedule t =
    let%bind.Option job_id = Deque.dequeue_front t.timeline in
    match Hashtbl.find t.index job_id with
    | Some job when keep_condition job -> (
        match should_reschedule job with
        | Some rescheduled_job ->
            Hashtbl.set t.index ~key:job_id ~data:rescheduled_job ;
            Deque.enqueue_back t.timeline job_id ;
            Some rescheduled_job
        | None ->
            Deque.enqueue_front t.timeline job_id ;
            None )
    | _ ->
        remove_until_reschedule ~keep_condition ~should_reschedule t

  let iter_until ~f t =
    let rec loop preserved_jobs =
      match Deque.dequeue_front t.timeline with
      | None ->
          (None, preserved_jobs)
      | Some job_id -> (
          match Hashtbl.find t.index job_id with
          | None ->
              loop preserved_jobs
          | Some job ->
              if f job then (Some job, job_id :: preserved_jobs)
              else loop (job_id :: preserved_jobs) )
    in
    let job_found, preserved_jobs = loop [] in
    List.iter ~f:(Deque.enqueue_front t.timeline) preserved_jobs ;
    job_found

  let add ~id ~job t =
    match Hashtbl.add ~key:id ~data:job t.index with
    | `Ok ->
        Deque.enqueue_back t.timeline id ;
        (* NOTE: removal of jobs from the [t.timeline] happens much less
           frequently than removal from [t.index], we iterate through the
           [t.timeline] to remove IDs that are no longer present in the
           [t.index] *)
        if Deque.length t.timeline > 4 * Hashtbl.length t.index then
          (* ignoring the result because it will be [None] *)
          ignore (iter_until ~f:(const false) t) ;
        `Ok
    | `Duplicate ->
        `Duplicate
end
