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

  let set_inplace ~id ~job t = Hashtbl.change t.index id ~f:(const (Some job))

  let rec remove_until_first ~pred t =
    let%bind.Option job_id = Deque.dequeue_front t.timeline in
    match Hashtbl.find t.index job_id with
    | Some job when pred job ->
        Some job
    | _ ->
        remove_until_first ~pred t

  let first ~pred t =
    let preserved = ref [] in
    let rec loop () =
      let%bind.Option job_id = Deque.dequeue_front t.timeline in
      match Hashtbl.find t.index job_id with
      | None ->
          loop ()
      | Some job ->
          preserved := job_id :: !preserved ;
          if pred job then Some job else loop ()
    in
    let result = loop () in
    List.iter ~f:(fun item -> Deque.enqueue_front t.timeline item) !preserved ;
    result

  let add ~id ~job t =
    match Hashtbl.add ~key:id ~data:job t.index with
    | `Ok ->
        Deque.enqueue_back t.timeline id ;
        (* NOTE: to ensure there's no memleak where removal of job happens much
           more frequently than insertion, we iterates through the pool to clean
           up removed IDs whenever there's too many of them *)
        if Deque.length t.timeline > 4 * Hashtbl.length t.index then
          ignore (first ~pred:(const false) t) ;
        `Ok
    | `Duplicate ->
        `Duplicate
end
