open Core_kernel
open Async_kernel

module Direction = struct
  type t = Left | Right [@@deriving sexp, bin_io]
end

module Ring_buffer = Ring_buffer
module Queue = Queue

module Available_job = struct
  type ('a, 'd) t = Base of 'd | Merge of 'a * 'a [@@deriving sexp]
end

module type Spec_intf = sig
  type data [@@deriving sexp_of]

  type accum [@@deriving sexp_of]

  type output [@@deriving sexp_of]
end

module State = struct
  include State

  (* Creates state that placeholders-out all the right jobs in the right spot
   * also we need to seed the buffer with exactly one piece of work
   *)
  let create : type a d. parallelism_log_2:int -> (a, d) t =
   fun ~parallelism_log_2 ->
    let open Job in
    let parallelism = Int.pow 2 parallelism_log_2 in
    let jobs =
      Ring_buffer.create ~len:((parallelism * 2) - 1) ~default:(Base None)
    in
    let repeat n x = List.init n ~f:(fun _ -> x) in
    let merges1 = repeat (parallelism - 1) (Merge (None, None)) in
    let bases1 = repeat parallelism (Base None) in
    jobs.position <- -1 ;
    List.iter [merges1; bases1] ~f:(Ring_buffer.add_many jobs) ;
    jobs.position <- 0 ;
    { jobs
    ; capacity= parallelism
    ; acc= (0, None)
    ; current_data_length= 0
    ; base_none_pos= Some (parallelism - 1) }

  let next_pos p cur_pos = if cur_pos = (2 * p) - 2 then p - 1 else cur_pos + 1

  (*Assuming that Base Somes are picked in the same order*)
  let next_base_none_pos state cur_pos =
    let p = parallelism state in
    let new_pos = next_pos p cur_pos in
    match Ring_buffer.read_i state.jobs new_pos with
    | Base None -> Some new_pos
    | _ -> None

  let%test_unit "parallelism derived from jobs" =
    let of_parallelism_log_2 x =
      let s = create ~parallelism_log_2:x in
      assert (parallelism s = Int.pow 2 x)
    in
    of_parallelism_log_2 1 ;
    of_parallelism_log_2 2 ;
    of_parallelism_log_2 3 ;
    of_parallelism_log_2 4 ;
    of_parallelism_log_2 5 ;
    of_parallelism_log_2 10

  (**  A parallel scan state holds a sequence of jobs that needs to be completed.
  *  A job can be a base job (Base d) or a merge job (Merge (a, a)).
  *
  *  The jobs are stored using a ring buffer impl of a breadth-first order
  *  binary tree where the root node is at 0, it's left child is at 1, right
  *  child at 2 and so on.
  *
  *  The leaves are at indices p-1 to 2p - 2 and the parent of each node is at
  *  (node_index-1)/2. For example, with parallelism of size 8 (p=8) the tree
  *  looks like this: (M = Merge, B = Base)
  *
  *                      0
  *                      M
  *             1                 2
  *             M                 M
  *         3        4        5        6
  *         M        M        M        M
  *      7    8   9    10  11   12  13   14
  *      B    B   B    B   B    B   B    B
  *
  * When a job (base or merge) is completed, its result is put into a new merge
  * job at it's parent index and a vacancy is created at the current job's
  * position. New base jobs are added separately (by enqueue_data).
  * Parallel scan starts at the root, traverses in the breadth-first order, and
  * completes the jobs as and when they are available.
  * When the merge job at the root node is completed, the result is returned.
  *
  * Think of the ring buffer's 2*n-1 elements as holding (almost) two steps of
  * execution at parallelism of size n. Assume we're always working on the
  * second step, and can refer to the work done at the prior step.
  *
  * 
  * Example trace: Jobs buffer at some state t
  *                      0
  *                   M(1,8)
  *
  *             1                 2
  *           M(9,12)           M(13,16)
  *
  *         3        4        5        6
  *     M(17,18)  M(19,20) M(21,22)  M(23,24)
  *
  *      7    8   9    10  11   12  13   14
  *     B25  B26 B27   B28 B29  B30 B31  B32
  *
  * After one iteration (assuming all the available jobs from state t are
  * completed):
  *                      0
  *                   M(9,16)
  *
  *             1                 2
  *         M(17,20)           M(21,24)
  *
  *        3         4        5        6
  *     M(25,26)  M(27,28) M(29,30)  M(31,32)
  *
  *      7    8   9    10  11   12  13   14
  *    B()   B() B()   B() B()  B() B()  B()
  *
  *)
  module Work = struct
    type t = Work_done | Not_done
  end

  let dir c = if c mod 2 = 1 then `Left else `Right

  let rec parent_empty (t: ('a, 'b) Job.t Ring_buffer.t) pos =
    match pos with
    | 0 -> true
    | pos ->
      match (dir pos, Ring_buffer.read_i t ((pos - 1) / 2)) with
      | `Left, Merge (None, _) -> true
      | `Right, Merge (_, None) -> true
      | _, Merge (Some _, Some _) -> parent_empty t ((pos - 1) / 2)
      | _, Base _ -> failwith "This shouldn't have occured"
      | _ -> false

  let next_position t position =
    let p = parallelism t in
    if position = p - 2 then
      let base_pos =
        match t.base_none_pos with None -> p - 1 | Some pos -> pos
      in
      base_pos
    else if position >= p - 1 then next_pos p position
    else Int.( % ) (position + 1) (Array.length t.jobs.data)

  let set_next_position t =
    (t.jobs).position <- next_position t t.jobs.position

  let fold_chronological t ~init ~f =
    let n = Array.length t.jobs.data in
    let rec go acc i pos =
      if Int.equal i n then acc
      else
        let x = (t.jobs.data).(pos) in
        go (f acc x) (i + 1) (next_position t pos)
    in
    go init 0 0

  let jobs_list t =
    let rec go count t =
      if count = (parallelism t * 2) - 1 then []
      else
        let j = Ring_buffer.read t.jobs in
        let pos = t.jobs.position in
        set_next_position t ;
        (j, pos) :: go (count + 1) t
    in
    (t.jobs).position <- 0 ;
    let js = go 0 t in
    (t.jobs).position <- 0 ;
    js

  let read_jobs t =
    List.filter (jobs_list t) ~f:(fun (_, pos) -> parent_empty t.jobs pos)

  let job_ready job =
    let module J = Job in
    let module A = Available_job in
    match job with
    | J.Base (Some d) -> Some (A.Base d)
    | J.Merge (Some a, Some b) -> Some (A.Merge (a, b))
    | _ -> None

  let jobs_ready state =
    List.filter_map (read_jobs state) ~f:(fun (job, _) -> job_ready job)

  let update_new_job t z dir pos =
    let new_job (cur_job: ('a, 'd) Job.t) : ('a, 'd) Job.t Or_error.t =
      match (dir, cur_job) with
      | `Left, Merge (None, r) -> Ok (Merge (Some z, r))
      | `Right, Merge (l, None) -> Ok (Merge (l, Some z))
      | `Left, Merge (Some _, _) | `Right, Merge (_, Some _) ->
          (*TODO: punish the sender*)
          Or_error.error_string
            "Impossible: the side of merge we want is not empty"
      | _, Base _ -> Error (Error.of_string "impossible: we never fill base")
    in
    Ring_buffer.direct_update t.jobs pos ~f:new_job

  let update_cur_job t job pos : unit Or_error.t =
    Ring_buffer.direct_update t.jobs pos ~f:(fun _ -> Ok job)

  let work :
         ('a, 'd) t
      -> 'a Completed_job.t
      -> ('a, 'b) Job.t Ring_buffer.t
      -> Work.t Or_error.t =
   fun t completed_job old_jobs ->
    let open Or_error.Let_syntax in
    let cur_job = Ring_buffer.read t.jobs in
    let cur_pos = t.jobs.position in
    match (parent_empty old_jobs cur_pos, cur_job, completed_job) with
    | true, Merge (Some _, Some _), Merged z ->
        let%bind () =
          if cur_pos = 0 then (
            t.acc <- (fst t.acc |> Int.( + ) 1, Some z) ;
            Ok () )
          else update_new_job t z (dir cur_pos) ((cur_pos - 1) / 2)
        in
        let%map () = update_cur_job t (Merge (None, None)) cur_pos in
        Work.Work_done
    | true, Base (Some _), Lifted z ->
        let%bind () = update_new_job t z (dir cur_pos) ((cur_pos - 1) / 2) in
        let%bind () = update_cur_job t (Base None) cur_pos in
        t.base_none_pos <- Some (Option.value t.base_none_pos ~default:cur_pos) ;
        t.current_data_length <- t.current_data_length - 1 ;
        Ok Work.Work_done
    | _ -> Ok Not_done

  let rec consume : type a d.
         (a, d) t
      -> a State.Completed_job.t list
      -> (a, d) Job.t Ring_buffer.t
      -> unit Or_error.t =
   fun t completed_jobs jobs_copy ->
    let open Or_error.Let_syntax in
    match completed_jobs with
    | [] -> Ok ()
    | j :: js ->
        let%bind next =
          match%map work t j jobs_copy with
          | Work.Not_done -> j :: js
          | Work.Work_done -> js
        in
        set_next_position t ; consume t next jobs_copy

  let include_one_datum state value base_pos : unit Or_error.t =
    let f (job: ('a, 'd) State.Job.t) : ('a, 'd) State.Job.t Or_error.t =
      match job with
      | Base None -> Ok (Base (Some value))
      | _ ->
          Or_error.error_string "Invalid job encountered while enqueuing data"
    in
    Ring_buffer.direct_update (State.jobs state) base_pos ~f

  let include_many_data (state: ('a, 'd) State.t) data : unit Or_error.t =
    List.fold ~init:(Ok ()) data ~f:(fun acc a ->
        let open Or_error.Let_syntax in
        let%bind () = acc in
        match State.base_none_pos state with
        | None -> Or_error.error_string "No empty leaves"
        | Some pos ->
            let%map () = include_one_datum state a pos in
            state.base_none_pos <- next_base_none_pos state pos )
end

let start : type a d. parallelism_log_2:int -> (a, d) State.t = State.create

let next_jobs : state:('a, 'd) State.t -> ('a, 'd) Available_job.t list =
 fun ~state -> State.jobs_ready state

let next_k_jobs :
    state:('a, 'd) State.t -> k:int -> ('a, 'd) Available_job.t list Or_error.t =
 fun ~state ~k ->
  if k > State.parallelism state then
    Or_error.errorf "You asked for %d jobs, but it's only safe to ask for %d" k
      (State.parallelism state)
  else
    let possible_jobs = List.take (next_jobs ~state) k in
    let len = List.length possible_jobs in
    if Int.equal len k then Or_error.return possible_jobs
    else
      Or_error.errorf "You asked for %d jobs, but I only have %d available" k
        len

let free_space : state:('a, 'd) State.t -> int =
 fun ~state -> state.State.capacity - State.current_data_length state

let enqueue_data : state:('a, 'd) State.t -> data:'d list -> unit Or_error.t =
 fun ~state ~data ->
  if free_space ~state < List.length data then
    Or_error.error_string
      (sprintf
         "Data list too large. Max available is %d, current list length is %d"
         (free_space ~state) (List.length data))
  else (
    state.current_data_length <- state.current_data_length + List.length data ;
    State.include_many_data state data )

let fill_in_completed_jobs :
       state:('a, 'd) State.t
    -> completed_jobs:'a State.Completed_job.t list
    -> 'b option Or_error.t =
 fun ~state ~completed_jobs ->
  let open Or_error.Let_syntax in
  let old_jobs = Ring_buffer.copy state.jobs in
  let last_acc = state.acc in
  let%map () = State.consume state completed_jobs old_jobs in
  (state.jobs).position <- 0 ;
  if not (fst last_acc = fst state.acc) then snd state.acc else None

let last_emitted_value (state: ('a, 'd) State.t) = snd state.acc

let gen :
       gen_data:'d Quickcheck.Generator.t
    -> f_job_done:(('a, 'd) Available_job.t -> 'a State.Completed_job.t)
    -> f_acc:(int * 'a option -> 'a -> 'a option)
    -> ('a, 'd) State.t Quickcheck.Generator.t =
 fun ~gen_data ~f_job_done ~f_acc ->
  let open Quickcheck.Generator.Let_syntax in
  let%bind parallelism_log_2 = Int.gen_incl 2 7 in
  let s = State.create ~parallelism_log_2 in
  let parallelism = State.parallelism s in
  let%bind data_chunk_size =
    Int.gen_incl ((parallelism / 2) - 1) (parallelism / 2)
  in
  let%map datas =
    Quickcheck.Generator.list_with_length ((parallelism * 2) + 3) gen_data
  in
  let data_chunks =
    let rec go datas chunks =
      if List.length datas <= data_chunk_size then List.rev (datas :: chunks)
      else
        let chunk, rest = List.split_n datas data_chunk_size in
        go rest (chunk :: chunks)
    in
    go datas []
  in
  List.fold data_chunks ~init:s ~f:(fun s chunk ->
      let jobs = next_jobs ~state:s in
      let jobs_done = List.map jobs ~f:f_job_done in
      let old_tuple = s.acc in
      Option.iter
        ( Or_error.ok_exn
        @@ fill_in_completed_jobs ~state:s ~completed_jobs:jobs_done )
        ~f:(fun x ->
          let tuple =
            if Option.is_some (snd old_tuple) then old_tuple else s.acc
          in
          s.acc <- (fst s.acc, f_acc tuple x) ) ;
      Or_error.ok_exn @@ enqueue_data ~state:s ~data:chunk ;
      s )

let%test_module "scans" =
  ( module struct
    let enqueue state ds =
      let free_space = free_space ~state in
      match free_space >= List.length ds with
      | true ->
          Or_error.ok_exn @@ enqueue_data ~state ~data:ds ;
          []
      | false ->
          Or_error.ok_exn
          @@ enqueue_data ~state ~data:(List.take ds free_space) ;
          List.drop ds free_space

    let rec step_on_free_space state w ds f f_acc =
      let enq ds' =
        if List.length ds' > 0 then
          let rem_ds = enqueue state ds' in
          rem_ds
        else []
      in
      let jobs = next_jobs ~state in
      let jobs_done = List.map jobs ~f in
      let old_tuple = state.acc in
      let x' =
        Option.bind
          ( Or_error.ok_exn
          @@ fill_in_completed_jobs ~state ~completed_jobs:jobs_done )
          ~f:(fun x ->
            let merged =
              if Option.is_some (snd old_tuple) then f_acc old_tuple x
              else snd state.acc
            in
            state.acc <- (fst state.acc, merged) ;
            merged )
      in
      let%bind () = Linear_pipe.write w x' in
      let rem_ds = enq ds in
      if List.length rem_ds > 0 then step_on_free_space state w rem_ds f f_acc
      else return ()

    let do_steps ~state ~data ~f ~f_acc w =
      let rec go () =
        match%bind Linear_pipe.read' data with
        | `Eof -> return ()
        | `Ok q ->
            let ds = Queue.to_list q in
            let%bind () = step_on_free_space state w ds f f_acc in
            go ()
      in
      go ()

    let scan ~data ~parallelism_log_2 ~f ~f_acc =
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
          let s = start ~parallelism_log_2 in
          do_steps ~state:s ~data ~f w ~f_acc )

    let step_repeatedly ~state ~data ~f ~f_acc =
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
          do_steps ~state ~data ~f w ~f_acc )

    let%test_module "scan (+) over ints" =
      ( module struct
        let f_merge_up (state: int * int64 option) x =
          let open Option.Let_syntax in
          let%map acc = snd state in
          Int64.( + ) acc x

        let job_done (job: (Int64.t, Int64.t) Available_job.t) :
            Int64.t State.Completed_job.t =
          match job with
          | Base x -> Lifted x
          | Merge (x, y) -> Merged (Int64.( + ) x y)

        let%test_unit "scan can be initialized from intermediate state" =
          Backtrace.elide := false ;
          let g =
            gen
              ~gen_data:
                Quickcheck.Generator.Let_syntax.(Int.gen >>| Int64.of_int)
              ~f_job_done:job_done ~f_acc:f_merge_up
          in
          Quickcheck.test g ~sexp_of:[%sexp_of : (int64, int64) State.t]
            ~trials:10 ~f:(fun s ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let do_one_next = ref false in
                  (* For any arbitrary intermediate state *)
                  let parallelism = State.parallelism s in
                  (* if we then add 1 and a bunch of zeros *)
                  let one_then_zeros =
                    Linear_pipe.create_reader ~close_on_exception:true
                      (fun w ->
                        let rec go () =
                          let next =
                            if !do_one_next then (
                              do_one_next := false ;
                              Int64.one )
                            else Int64.zero
                          in
                          let%bind () = Pipe.write w next in
                          go ()
                        in
                        go () )
                  in
                  let pipe s =
                    step_repeatedly ~state:s ~data:one_then_zeros ~f:job_done
                      ~f_acc:f_merge_up
                  in
                  let fill_some_zeros v s =
                    List.init (parallelism * parallelism) ~f:(fun _ -> ())
                    |> Deferred.List.fold ~init:v ~f:(fun v _ ->
                           match%map Linear_pipe.read (pipe s) with
                           | `Eof -> v
                           | `Ok (Some v') -> v'
                           | `Ok None -> v )
                  in
                  (* after we flush intermediate work *)
                  let old_acc =
                    State.acc s |> Option.value ~default:Int64.zero
                  in
                  let%bind v = fill_some_zeros Int64.zero s in
                  do_one_next := true ;
                  let acc = State.acc s |> Option.value_exn in
                  assert (acc <> old_acc) ;
                  (* eventually we'll emit the acc+1 element *)
                  let%map _ = fill_some_zeros v s in
                  let acc_plus_one = State.acc s |> Option.value_exn in
                  assert (Int64.(equal acc_plus_one (acc + one))) ) )
      end )

    let%test_module "scan (+) over ints, map from string" =
      ( module struct
        let f_merge_up (tuple: int * int64 option) x =
          let open Option.Let_syntax in
          let%map acc = snd tuple in
          Int64.( + ) acc x

        let job_done (job: (Int64.t, string) Available_job.t) :
            Int64.t State.Completed_job.t =
          match job with
          | Base x -> Lifted (Int64.of_string x)
          | Merge (x, y) -> Merged (Int64.( + ) x y)

        let%test_unit "scan behaves like a fold long-term" =
          let a_bunch_of_ones_then_zeros x =
            { Linear_pipe.Reader.pipe=
                Pipe.unfold ~init:x ~f:(fun count ->
                    let next =
                      if count <= 0 then "0" else Int.to_string (x - count)
                    in
                    return (Some (next, count - 1)) )
            ; has_reader= false }
          in
          let parallelism = 7 in
          let n = 1000 in
          let result =
            scan
              ~data:(a_bunch_of_ones_then_zeros n)
              ~parallelism_log_2:parallelism ~f:job_done ~f_acc:f_merge_up
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%map after_3n =
                List.init (3 * n) ~f:(fun _ -> ())
                |> Deferred.List.fold ~init:Int64.zero ~f:(fun acc _ ->
                       match%map Linear_pipe.read result with
                       | `Eof -> acc
                       | `Ok (Some v) -> v
                       | `Ok None -> acc )
              in
              let expected =
                List.fold
                  (List.init n ~f:(fun i -> Int64.of_int i))
                  ~init:Int64.zero ~f:Int64.( + )
              in
              assert (after_3n = expected) )
      end )

    let%test_module "scan (concat) over strings" =
      ( module struct
        let f_merge_up (tuple: int * string option) x =
          let open Option.Let_syntax in
          let%map acc = snd tuple in
          String.( ^ ) acc x

        let job_done (job: (string, string) Available_job.t) :
            string State.Completed_job.t =
          match job with
          | Base x -> Lifted x
          | Merge (x, y) -> Merged (String.( ^ ) x y)

        let%test_unit "scan performs operation in correct order with \
                       non-commutative semigroup" =
          Backtrace.elide := false ;
          let a_bunch_of_nums_then_empties x =
            { Linear_pipe.Reader.pipe=
                Pipe.unfold ~init:x ~f:(fun count ->
                    let next =
                      if count <= 0 then ""
                      else Int.to_string (x - count) ^ ","
                    in
                    return (Some (next, count - 1)) )
            ; has_reader= false }
          in
          let n = 100 in
          let result =
            scan
              ~data:(a_bunch_of_nums_then_empties n)
              ~parallelism_log_2:12 ~f:job_done ~f_acc:f_merge_up
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%map after_42n =
                List.init (42 * n) ~f:(fun _ -> ())
                |> Deferred.List.fold ~init:"" ~f:(fun acc _ ->
                       match%map Linear_pipe.read result with
                       | `Eof -> acc
                       | `Ok (Some v) -> v
                       | `Ok None -> acc )
              in
              let expected =
                List.fold
                  (List.init n ~f:(fun i -> Int.to_string i ^ ","))
                  ~init:"" ~f:String.( ^ )
              in
              assert (after_42n = expected) )
      end )
  end )
