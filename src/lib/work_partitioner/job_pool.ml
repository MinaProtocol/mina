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

  let remove_exn ~id ~message t =
    match remove ~id t with Some _ -> () | None -> failwith message

  let find ~id t = Hashtbl.find t.index id

  let change_inplace ~id ~f t = Hashtbl.change t.index id ~f

  let rec remove_until_reschedule ~f t =
    let%bind.Option job_id = Deque.dequeue_front t.timeline in
    match Hashtbl.find t.index job_id with
    | Some job -> (
        match f job with
        | `Remove ->
            remove_until_reschedule ~f t
        | `Stop_keep ->
            Deque.enqueue_front t.timeline job_id ;
            None
        | `Stop_reschedule rescheduled_job ->
            Hashtbl.set t.index ~key:job_id ~data:rescheduled_job ;
            Deque.enqueue_back t.timeline job_id ;
            Some rescheduled_job )
    | _ ->
        remove_until_reschedule ~f t

  (* TODO: this seems unused, except in [add] we might want simplify it *)
  let iter_until ~f t =
    let rec loop preserved_jobs =
      match Deque.dequeue_front t.timeline with
      | None ->
          (None, preserved_jobs)
      | Some job_id -> (
          match Hashtbl.find t.index job_id with
          | None ->
              loop preserved_jobs
          | Some job -> (
              match f job with
              | Some _ as result ->
                  (result, job_id :: preserved_jobs)
              | None ->
                  loop (job_id :: preserved_jobs) ) )
    in
    let result, preserved_jobs = loop [] in
    List.iter ~f:(Deque.enqueue_front t.timeline) preserved_jobs ;
    result

  let add ~id ~job t =
    match Hashtbl.add ~key:id ~data:job t.index with
    | `Ok ->
        Deque.enqueue_back t.timeline id ;
        (* NOTE: when removal of jobs from the [t.timeline] happens much less
           frequently than removal from [t.index], we iterate through the
           [t.timeline] to remove IDs that are no longer present in the
           [t.index] *)
        if Deque.length t.timeline > 4 * Hashtbl.length t.index then
          (* ignoring the result because it will be [None] *)
          ignore (iter_until ~f:(const None) t) ;
        `Ok
    | `Duplicate ->
        `Duplicate

  let add_exn ~id ~job ~message t =
    match add ~id ~job t with `Ok -> () | `Duplicate -> failwith message
end
