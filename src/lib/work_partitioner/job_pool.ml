open Core_kernel

(* NOTE: Maybe this is reusable with Work Selector as they also have reissue mechanism *)
module Make (ID : Hashtbl.Key) (Job : T) = struct
  type job_item = Job.t option ref

  type t =
    { timeline : (ID.t * job_item) Deque.t (* For iteration  *)
    ; index : (ID.t, job_item) Hashtbl.t (* For marking job as done *)
    }

  let create () =
    { timeline = Deque.create (); index = Hashtbl.create (module ID) }

  let rec peek (t : t) =
    match Deque.dequeue_front t.timeline with
    | None ->
        None
    | Some (_, { contents = None }) ->
        peek t
    | Some ((id, { contents = Some pending }) as item) ->
        Deque.enqueue_front t.timeline item ;
        Some (id, pending)

  let rec take_first_ready ~(pred : Job.t -> bool) (t : t) =
    match Deque.dequeue_front t.timeline with
    | None ->
        None
    | Some (_, { contents = None }) ->
        (* Job done *)
        take_first_ready ~pred t
    | Some ((id, { contents = Some pending }) as item) ->
        if pred pending then Some (id, pending)
        else (
          Deque.enqueue_front t.timeline item ;
          None )

  let attempt_add ~(key : ID.t) ~(job : Job.t) (t : t) =
    let data = ref (Some job) in
    match Hashtbl.add ~key ~data t.index with
    | `Ok ->
        Deque.enqueue_back t.timeline (key, data) ;
        `Ok
    | `Duplicate ->
        `Duplicate

  let slash (t : t) (id : ID.t) =
    match Hashtbl.find_and_remove t.index id with
    | None ->
        None
    | Some job_item ->
        let result = !job_item in
        job_item := None ;
        result

  let replace ~(id : ID.t) ~(job : Job.t) (t : t) =
    let data = ref (Some job) in
    Hashtbl.change t.index id ~f:(function
      | None ->
          Some data
      | Some job_already ->
          job_already := None ;
          Some data ) ;
    Deque.enqueue_back t.timeline (id, data)

  let find (t : t) (id : ID.t) =
    match Hashtbl.find t.index id with
    | Some { contents = Some job } ->
        Some job
    | _ ->
        None
end
