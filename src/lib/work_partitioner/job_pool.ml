open Core_kernel

type 'a scheduled = { job : 'a; scheduled : Time.t }

module Make (Id : Hashtbl.Key) (Spec : T) = struct
  type job = (Spec.t, Id.t) Snark_work_lib.With_job_meta.t

  type t =
    { mutable timeline : Id.t Deque.t (* For iteration *)
    ; index : (Id.t, job scheduled) Hashtbl.t (* For marking job as done *)
    }

  let create () =
    { timeline = Deque.create (); index = Hashtbl.create (module Id) }

  let remove ~id t = Hashtbl.find_and_remove t.index id

  let find ~id t = Hashtbl.find t.index id

  let rec remove_until_reschedule ~f t =
    let%bind.Option job_id = Deque.dequeue_front t.timeline in
    match Hashtbl.find t.index job_id with
    | Some scheduled_job -> (
        match f scheduled_job with
        | `Remove ->
            remove_until_reschedule ~f t
        | `Stop_keep ->
            Deque.enqueue_front t.timeline job_id ;
            None
        | `Stop_reschedule (job : job) ->
            assert (Id.compare job.job_id job_id = 0) ;
            let job_rescheduled = { job; scheduled = Time.now () } in
            Hashtbl.set t.index ~key:job_id ~data:job_rescheduled ;
            Deque.enqueue_back t.timeline job_id ;
            Some job_rescheduled )
    | _ ->
        remove_until_reschedule ~f t

  let add_now ~id ~job t =
    match
      Hashtbl.add ~key:id ~data:{ job; scheduled = Time.now () } t.index
    with
    | `Ok ->
        Deque.enqueue_back t.timeline id ;
        (* NOTE: when removal of jobs from the [t.timeline] happens much less
           frequently than removal from [t.index], we iterate through the
           [t.timeline] to remove IDs that are no longer present in the
           [t.index] *)
        if Deque.length t.timeline > 4 * Hashtbl.length t.index then
          t.timeline <-
            Deque.to_array t.timeline
            |> Array.filter
                 ~f:(Fn.compose Option.is_some @@ Hashtbl.find t.index)
            |> Deque.of_array ;
        `Ok
    | `Duplicate ->
        `Duplicate

  let add_now_exn ~id ~job ~message t =
    match add_now ~id ~job t with `Ok -> () | `Duplicate -> failwith message
end
