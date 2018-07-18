open Core_kernel
open Async_kernel

module Direction = struct
  type t = Left | Right [@@deriving sexp, eq, bin_io]
end

module Ring_buffer = Ring_buffer
module State = State
module Queue = Queue

module type Spec_intf = sig
  type data [@@deriving sexp_of]

  type accum [@@deriving sexp_of]

  type output [@@deriving sexp_of]
end

module State1 = struct
  include State

  (* Creates state that placeholders-out all the right jobs in the right spot
   * also we need to seed the buffer with exactly one piece of work
   *)
  let create : type a b d. parallelism_log_2:int -> init:b -> (a, b, d) t =
   fun ~parallelism_log_2 ~init ->
    let open Job in
    let parallelism = Int.pow 2 parallelism_log_2 in
    let jobs =
      Ring_buffer.create ~len:(parallelism * 2) ~default:(Base None)
    in
    let repeat n x = List.init n ~f:(fun _ -> x) in
    let merges1 = repeat ((parallelism / 2) - 1) (Merge (None, None)) in
    let bases1 = repeat (parallelism / 2) (Base None) in
    let merges2 = repeat (parallelism / 2) (Merge (None, None)) in
    let bases2 = repeat (parallelism / 2) (Base None) in
    let top = Merge_up None in
    List.iter [merges1; bases1; merges2; bases2; [top]]
      ~f:(Ring_buffer.add_many jobs) ;
    assert (jobs.Ring_buffer.position = 0) ;
    let data_buffer = Queue.create ~capacity:parallelism () in
    { jobs
    ; data_buffer
    ; was_seeded= false
    ; acc= (0, init)
    ; current_data_length= 1
    ; enough_steps= false }

  (* TODO Initial count cannot be zero, what should it be then?*)

  let parallelism {jobs} = Ring_buffer.length jobs / 2

  let%test_unit "parallelism derived from jobs" =
    let of_parallelism_log_2 x =
      let s = create ~parallelism_log_2:x ~init:0 in
      assert (parallelism s = Int.pow 2 x)
    in
    of_parallelism_log_2 1 ;
    of_parallelism_log_2 2 ;
    of_parallelism_log_2 3 ;
    of_parallelism_log_2 4 ;
    of_parallelism_log_2 5 ;
    of_parallelism_log_2 10

  (** Compute the ptr to update inside the ring buffer with the work completed
   * at position i. Assume size of buffer is exactly 2*n.
   *
   * Why does this work?
   *
   * Think of the ring buffer's 2*n elements as holding two steps of execution
   * at parallelism of size n. Assume we're always working on the second step,
   * and can refer to the work done at the prior step
   *
   * Example trace: (where n=8), U = Merge_up, M = Merge, T = Base
   *      0        1          2         3        4    5    6    7
   *  1. M_{1-8}  M_{9-12}  M_{13,14} M_{15,16} T_17 T_18 T_19 T_20
   *  2. U_{1-8}  M_{13-16} M_{17,18} M_{19,20} T_21 T_22 T_23 T_24
   *  3. M_{9-16} M_{17-20} M_{21,22} M_{23,24} T_25 T_26 T_27 T_28
   *
   * Start on line (2) above assuming line (1) has been completed.
   *
   * Notice that col (0) updates nothing as this is merge up
   * col (1) updates from (2) (left) and (3) (right)
   * col (2) updates from (4) (left) and (5) (right)
   * Moreover, for i!=0, i is updated by i/2 and direction is given by i%2
   * This is very similar to how the Heap datastructure is built. Children
   * nodes for a node i are located at index 2*i and 2*i+1.
   *
   * On line (3), col (0) updates the col (0) on even lines (the merge_up)
   * and col (1) of the prior two lines feeds col (0). We can just special
   * case this behavior.
   *
   * However, the ringbuffer packs 2*n elements in and reuses the same memory
   * for future lines:
   *   0         1        2          3        4    5    6   7
   * U_{1-8}  M_{13-16} M_{17,18} M_{19,20} T_21 T_22 T_23 T_24
   *   8         9         10        11       12  13   14   15
   * M_{9-16} M_{17-20} M_{21,22} M_{23,24} T_25 T_26 T_27 T_28
   *
   * So we need to adjust by n sometimes. Specifically we flip between the
   * lines, so if we start on the top row we need to update the bottom and
   * vice versa. For example, index 1 is actually updated by 10 and 11 not 2
   * and 3. Similarly, 9 is updated by 2 and 3. We can conditionally add offset
   * after mod-ing by n to oscillate between the two lines.
   *)
  let ptr n i =
    let open Direction in
    match i with
    | 0 -> failwith "Undefined, nothing to rewrite"
    | 1 -> (n, Right)
    | x when x = n -> (0, Left)
    | x when x = n + 1 -> (n, Left)
    | _ ->
        let x = i % n in
        let offset = if i >= n then 0 else n in
        ((x / 2) + offset, if x % 2 = 0 then Left else Right)

  let%test_unit "ptr points properly" =
    (*              0
     *             [8]
     *  ;    [9      ;      1]
     *  ;  [2 ;   3  ;  10   ;   11]
     *  ;[12 ;13;14;15;4 ; 5; 6 ;  7]
     *
     *)
    let open Direction in
    let p = ptr 8 in
    assert (p 8 = (0, Left)) ;
    assert (p 9 = (8, Left)) ;
    assert (p 1 = (8, Right)) ;
    assert (p 2 = (9, Left)) ;
    assert (p 3 = (9, Right)) ;
    assert (p 10 = (1, Left)) ;
    assert (p 11 = (1, Right)) ;
    assert (p 12 = (2, Left)) ;
    assert (p 13 = (2, Right)) ;
    assert (p 14 = (3, Left)) ;
    assert (p 15 = (3, Right)) ;
    assert (p 4 = (10, Left)) ;
    assert (p 5 = (10, Right)) ;
    assert (p 6 = (11, Left)) ;
    assert (p 7 = (11, Right))

  let the_special_condition t index =
    if index = parallelism t + 1 then
      match
        (Ring_buffer.read_i t.jobs index, Ring_buffer.read_i t.jobs (index - 1))
      with
      | Merge (Some _, Some _), Merge (None, None)
       |Merge (Some _, Some _), Merge (None, Some _) ->
          true
      | _ -> false
    else false

  let read_all (t: ('a, 'b, 'd) State.t) =
    let curr_position_neg_one =
      Ring_buffer.mod_ (t.jobs.position - 1) (Ring_buffer.length t.jobs)
    in
    Sequence.unfold ~init:(`More t.jobs.position) ~f:(fun pos ->
        match pos with
        | `Stop -> None
        | `More pos ->
            if the_special_condition t pos || pos = curr_position_neg_one then
              Some ((t.jobs.data).(pos), `Stop)
            else
              Some
                ( (t.jobs.data).(pos)
                , `More
                    (Ring_buffer.mod_ (pos + 1) (Ring_buffer.length t.jobs)) )
    )
    |> Sequence.to_list

  let is_ready (job: ('a, 'd) Job.t) =
    match job with
    | Base None -> false
    | Merge (None, _) -> false
    | Merge (_, None) -> false
    | Merge_up None -> false
    | _ -> true

  let step_once : type a b d.
      (a, b, d) t -> (a, b) State.Completed_job.t Queue.t -> bool Or_error.t =
   fun t completed_jobs_q ->
    let open Or_error.Let_syntax in
    let open Job in
    let open Completed_job in
    let fill_job dir z job : (a, d) Job.t Or_error.t =
      let open Direction in
      match (dir, job) with
      | _, Merge_up None -> Ok (Merge_up (Some z))
      | Left, Merge (None, r) -> Ok (Merge (Some z, r))
      | Right, Merge (l, None) -> Ok (Merge (l, Some z))
      | Left, Merge_up (Some _) | Right, Merge_up (Some _) ->
          Error (Error.of_string "impossible: Merge_ups should be empty")
      | Left, Merge (Some _, _) | Right, Merge (_, Some _) ->
          failwith
            "impossible: the side of merge we want will be empty TODO show sexp"
      | _, Base _ -> Error (Error.of_string "impossible: we never fill base")
    in
    (* Returns the ptr rewritten *)
    let rewrite (i: int) (z: a) : unit Or_error.t =
      let ptr, dir = ptr (parallelism t) i in
      let js : (a, d) Job.t Ring_buffer.t = t.jobs in
      Ring_buffer.direct_update js ptr ~f:(fun job -> fill_job dir z job)
    in
    let move_backward = the_special_condition t t.jobs.position in
    let%bind work =
      (* Note: We don't have to worry about position overflow because
         * we always have an even number of elems in the ring buffer *)
      let work_done = ref false in
      let work i job : (a, d) Job.t Or_error.t =
        match (job, Queue.peek completed_jobs_q) with
        | Merge_up None, _ -> Ok job
        | Merge (None, None), _ -> Ok job
        | Merge (None, Some _), _ -> Ok job
        | Base None, _ -> (
          match Queue.dequeue t.data_buffer with
          | None ->
              Or_error.error_string
                (sprintf "Data buffer empty. Cannot proceed. %d" i)
          | Some x ->
              t.current_data_length <- t.current_data_length - 1 ;
              work_done := true ;
              Ok (Base (Some x)) )
        | Merge_up (Some x), Some (Merged_up acc') ->
            t.acc <- (fst t.acc |> Int.( + ) 1, acc') ;
            let _ = Queue.dequeue completed_jobs_q in
            work_done := true ;
            Ok (Merge_up None)
        | Merge (Some _, None), _ -> Ok job
        | Merge (Some x, Some x'), Some (Merged z) ->
            let%bind () = rewrite i z in
            work_done := true ;
            let _ = Queue.dequeue completed_jobs_q in
            Ok (Merge (None, None))
        | Base (Some d), Some (Lifted z) -> (
            let%bind () = rewrite i z in
            work_done := true ;
            match Queue.dequeue t.data_buffer with
            | None -> Ok (Base None)
            | Some x ->
                t.current_data_length <- t.current_data_length - 1 ;
                let _ = Queue.dequeue completed_jobs_q in
                Ok (Base (Some x)) )
        | Merge (Some x, Some x'), _ -> Ok job
        | x, y -> failwith @@ "Doesn't happen\n"
        (*( Job.sexp_of_t (*Spec.Accum.sexp_of_t Spec.Data.sexp_of_t x*)
                |> Sexp.to_string_hum )
                ()*)
      in
      let i1 = t.jobs.position in
      let%bind () = Ring_buffer.direct_update t.jobs i1 ~f:(work i1) in
      let wd = !work_done in
      work_done := false ;
      return wd
    in
    let () =
      if move_backward then Ring_buffer.back ~n:1 t.jobs
      else Ring_buffer.forwards ~n:1 t.jobs
    in
    return work

  let consume : type a b d.
      (a, b, d) t -> (a, b) State.Completed_job.t list -> b option Or_error.t =
   fun t completed_jobs ->
    let open Or_error.Let_syntax in
    let open Job in
    let open Completed_job in
    let completed_jobs_q = Queue.of_list completed_jobs in
    let last_acc = t.acc in
    let data_list = Queue.to_list t.data_buffer in
    (* TODO: Why is this here? *)
    let iter_list =
      if List.length completed_jobs = 0 then
        List.init (List.length data_list) ident
      else
        List.init
          (Int.min (List.length data_list) (List.length completed_jobs))
          ident
    in
    let%map enough_steps =
      List.fold ~init:(return ()) iter_list ~f:(fun acc cj ->
          let%bind () = acc in
          let%map work_done = step_once t completed_jobs_q in
          () )
    in
    if not (fst last_acc = fst t.acc) then Some (snd t.acc) else None
end

let start : type a b d. parallelism_log_2:int -> init:b -> (a, b, d) State.t =
  State1.create

let next_jobs : state:('a, 'b, 'd) State1.t -> ('a, 'd) State1.Job.t list =
 fun ~state ->
  let max = State1.parallelism state in
  List.filter (List.take (State1.read_all state) max) ~f:State1.is_ready

let next_k_jobs :
       state:('a, 'b, 'd) State1.t
    -> k:int
    -> ('a, 'd) State1.Job.t list Or_error.t =
 fun ~state ~k ->
  if k > State1.parallelism state then
    Or_error.errorf "You asked for %d jobs, but it's only safe to ask for %d" k
      (State1.parallelism state)
  else
    let possible_jobs = List.take (next_jobs state) k in
    let len = List.length possible_jobs in
    if Int.equal len k then Or_error.return possible_jobs
    else
      Or_error.errorf "You asked for %d jobs, but I only have %d available" k
        len

let free_space : state:('a, 'b, 'd) State1.t -> int =
 fun ~state ->
  let buff = State1.data_buffer state in
  Queue.capacity buff
  - State.current_data_length state
  + if State1.was_seeded state then 0 else 1

let enqueue_data :
    state:('a, 'b, 'd) State1.t -> data:'d list -> unit Or_error.t =
 fun ~state ~data ->
  if free_space state < List.length data then
    Or_error.error_string
      (sprintf
         "Data list too large. Max available is %d, current list length is %d"
         (free_space state) (List.length data))
  else (
    state.current_data_length <- state.current_data_length + List.length data ;
    Ok
      (List.fold ~init:() data ~f:(fun () d ->
           Queue.enqueue state.data_buffer d )) )

let fill_in_completed_jobs :
       state:('a, 'b, 'd) State1.t
    -> jobs:('a, 'b) State1.Completed_job.t list
    -> 'b option Or_error.t =
 fun ~state ~jobs -> State1.consume state jobs

let gen :
       init:'b
    -> gen_data:'d Quickcheck.Generator.t
    -> parallelism_log_2:int
    -> f_job_done:(   ('a, 'b, 'd) State.t
                   -> ('a, 'd) State.Job.t
                   -> ('a, 'b) State.Completed_job.t)
    -> ('a, 'b, 'd) State.t Quickcheck.Generator.t =
 fun ~init ~gen_data ~parallelism_log_2 ~f_job_done ->
  let open Quickcheck.Generator.Let_syntax in
  let%bind seed = gen_data in
  let s = State1.create ~parallelism_log_2 ~init in
  Or_error.ok_exn @@ enqueue_data ~state:s ~data:[seed] ;
  let parallelism = Int.pow 2 parallelism_log_2 in
  let free_space = free_space s in
  let%map datas = Quickcheck.Generator.list_with_length free_space gen_data in
  let data_chunks =
    let rec go datas chunks =
      if List.length datas < parallelism then List.rev (datas :: chunks)
      else
        let chunk, rest = List.split_n datas parallelism in
        go rest (chunk :: chunks)
    in
    go datas []
  in
  List.fold data_chunks ~init:s ~f:(fun acc chunk ->
      let jobs = next_jobs ~state:acc in
      let jobs_done = List.map jobs (f_job_done acc) in
      let _ = Or_error.ok_exn @@ enqueue_data acc chunk in
      let _ = Or_error.ok_exn @@ State1.consume acc jobs_done in
      acc )

let%test_module "scans" =
  ( module struct
    let enqueue state ds =
      let free_space = free_space state in
      if free_space > List.length ds then (
        Or_error.ok_exn @@ enqueue_data state ds ;
        [] )
      else (
        Or_error.ok_exn @@ enqueue_data state (List.take ds free_space) ;
        List.drop ds free_space )

    let rec step_on_free_space state w ds f =
      let rem_ds =
        if List.length ds > 0 then
          let new_ds = enqueue state ds in
          new_ds
        else []
      in
      let jobs = next_jobs ~state in
      let works = List.map jobs (f state) in
      let x = Or_error.ok_exn @@ State1.consume state works in
      let%bind () = Linear_pipe.write w x in
      if List.length rem_ds > 0 then step_on_free_space state w rem_ds f
      else return ()

    let do_steps ~state ~data ~f w =
      let rec go () =
        match%bind Linear_pipe.read' data with
        | `Eof -> return ()
        | `Ok q ->
            let ds = Queue.to_list q in
            let%bind () = step_on_free_space state w ds f in
            go ()
      in
      go ()

    let scan ~init ~data ~parallelism_log_2 ~f =
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
          match%bind Linear_pipe.read data with
          | `Eof -> return ()
          | `Ok seed ->
              let s = start ~init ~parallelism_log_2 in
              Or_error.ok_exn @@ enqueue_data ~state:s ~data:[seed] ;
              do_steps ~state:s ~data ~f w )

    let step_repeatedly ~state ~data ~f =
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
          do_steps ~state ~data ~f w )

    let%test_module "scan (+) over ints" =
      ( module struct
        let job_done (state: ('a, 'b, 'd) State1.t)
            (job: (Int64.t, Int64.t) State.Job.t) :
            (Int64.t, Int64.t) State.Completed_job.t =
          match job with
          | Base (Some x) -> Lifted x
          | Merge (Some x, Some y) -> Merged (Int64.( + ) x y)
          | Merge_up (Some x) -> Merged_up (Int64.( + ) (snd state.acc) x)
          | _ -> Lifted Int64.zero

        let%test_unit "scan can be initialized from intermediate state" =
          let g =
            gen ~init:Int64.zero ~parallelism_log_2:7
              ~gen_data:
                Quickcheck.Generator.Let_syntax.(Int.gen >>| Int64.of_int)
              ~f_job_done:job_done
          in
          Quickcheck.test g ~sexp_of:[%sexp_of : (int64, int64, int64) State.t]
            ~trials:10 ~f:(fun s ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  let do_one_next = ref false in
                  (* For any arbitrary intermediate state *)
                  let parallelism = State1.parallelism s in
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
                  in
                  let fill_some_zeros v s =
                    List.init (parallelism * parallelism) ~f:(fun _ -> ())
                    |> Deferred.List.foldi ~init:v ~f:(fun i v _ ->
                           match%map Linear_pipe.read (pipe s) with
                           | `Eof -> v
                           | `Ok (Some v') -> v'
                           | `Ok None -> v )
                  in
                  (* after we flush intermediate work *)
                  let old_acc = State1.acc s in
                  let%bind v = fill_some_zeros Int64.zero s in
                  do_one_next := true ;
                  let acc = State1.acc s in
                  assert (acc <> old_acc) ;
                  (* eventually we'll emit the acc+1 element *)
                  let%map acc_plus_one = fill_some_zeros v s in
                  assert (Int64.(equal acc_plus_one (acc + one))) ) )
      end )

    let%test_module "scan (+) over ints, map from string" =
      ( module struct
        let job_done (state: ('a, 'b, 'd) State1.t)
            (job: (Int64.t, string) State.Job.t) :
            (Int64.t, Int64.t) State.Completed_job.t =
          match job with
          | Base (Some x) -> Lifted (Int64.of_string x)
          | Merge (Some x, Some y) -> Merged (Int64.( + ) x y)
          | Merge_up (Some x) -> Merged_up (Int64.( + ) (snd state.acc) x)
          | _ -> Lifted Int64.zero

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
          let n = 30 in
          let result =
            scan ~init:Int64.zero
              ~data:(a_bunch_of_ones_then_zeros n)
              ~parallelism_log_2:3 ~f:job_done
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%map after_3n =
                List.init (3 * n) ~f:(fun _ -> ())
                |> Deferred.List.foldi ~init:Int64.zero ~f:(fun i acc _ ->
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
        let job_done (state: ('a, 'b, 'd) State1.t)
            (job: (string, string) State.Job.t) :
            (string, string) State.Completed_job.t =
          match job with
          | Base (Some x) -> Lifted x
          | Merge (Some x, Some y) -> Merged (String.( ^ ) x y)
          | Merge_up (Some x) -> Merged_up (String.( ^ ) (snd state.acc) x)
          | _ -> Lifted "X"

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
          let n = 40 in
          let result =
            scan ~init:""
              ~data:(a_bunch_of_nums_then_empties n)
              ~parallelism_log_2:4 ~f:job_done
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%map after_3n =
                List.init (3 * n) ~f:(fun _ -> ())
                |> Deferred.List.foldi ~init:"" ~f:(fun i acc _ ->
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
              assert (after_3n = expected) )
      end )
  end )
