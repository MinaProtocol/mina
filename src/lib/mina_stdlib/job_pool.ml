open Core_kernel

type 'a scheduled = { job : 'a; scheduled : Time.t }

module Make
    (Id : Hashtbl.Key) (Job : sig
      type t

      val id : t -> Id.t
    end) =
struct
  open struct
    type scheduled_ref = Job.t scheduled option ref
  end

  type t =
    { mutable timeline : scheduled_ref Deque.t (* For iteration *)
    ; index : (Id.t, scheduled_ref) Hashtbl.t (* For marking job as done *)
    }

  let create () =
    { timeline = Deque.create (); index = Hashtbl.create (module Id) }

  let remove ~id t =
    let%bind.Option ref = Hashtbl.find_and_remove t.index id in
    let%map.Option scheudled = !ref in
    ref := None ;
    scheudled

  let find ~id t =
    let%bind.Option ref = Hashtbl.find t.index id in
    let%map.Option scheudled = !ref in
    scheudled

  let add_now ~job t =
    let id = Job.id job in
    let when_scheduled = Time.now () in
    let job_ref = ref (Some { job; scheduled = when_scheduled }) in
    match Hashtbl.add ~key:id ~data:job_ref t.index with
    | `Ok ->
        Deque.enqueue_back t.timeline job_ref ;
        (* NOTE: when removal of jobs from the [t.timeline] happens much less
           frequently than removal from [t.index], we iterate through the
           [t.timeline] to remove IDs that are no longer present in the
           [t.index] *)
        if Deque.length t.timeline > 4 * Hashtbl.length t.index then (
          let new_timeline = Deque.create () in
          Deque.iter t.timeline ~f:(fun job_ref ->
              if Option.is_some !job_ref then
                Deque.enqueue_back new_timeline job_ref ) ;
          t.timeline <- new_timeline ) ;
        `Ok when_scheduled
    | `Duplicate ->
        `Duplicate

  let add_now_exn ~job ~message t =
    match add_now ~job t with
    | `Ok when_scheduled ->
        when_scheduled
    | `Duplicate ->
        failwith message

  let rec remove_until_reschedule ~f t =
    let%bind.Option job = Deque.dequeue_front t.timeline in
    match !job with
    | Some original_job -> (
        match f original_job with
        | `Remove ->
            remove_until_reschedule ~f t
        | `Stop_keep ->
            Deque.enqueue_front t.timeline job ;
            None
        | `Stop_reschedule (replacing_job : Job.t) ->
            assert (
              Id.compare (Job.id replacing_job) (Job.id original_job.job) = 0 ) ;
            let when_scheduled =
              add_now_exn ~job:replacing_job
                ~message:"Impossible: same ID appearing in job pool twice!" t
            in
            Some { job = replacing_job; scheduled = when_scheduled } )
    | _ ->
        remove_until_reschedule ~f t

  let replace_now ~job t =
    ignore @@ remove ~id:(Job.id job) t ;
    add_now_exn ~job ~message:"Impossible: job just removed still in job pool" t

  let fold ~init ~f t =
    Deque.fold ~init
      ~f:(fun acc job -> match !job with None -> acc | Some job -> f acc job)
      t.timeline

  let to_list t = fold ~init:[] ~f:(fun l j -> j :: l) t |> List.rev
end
