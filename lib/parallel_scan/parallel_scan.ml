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
  let create : type a d. parallelism_log_2:int -> (a, d) t =
   fun ~parallelism_log_2 ->
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
    ; capacity= parallelism
    ; acc= (0, None)
    ; current_data_length= 0
    ; base_none_pos= Some (parallelism / 2)
    ; enough_steps= false }

  (* TODO Initial count cannot be zero, what should it be then?*)

  let parallelism {jobs} = Ring_buffer.length jobs / 2

  (*leaves are in two different chunks on the buffer*)
  let next_pos p cur_pos =   
    let first_start = p/2 in
    let first_end = p-1 in
    let sec_start = 3*p/2 in 
    let sec_end = 2*p-1 in
    if cur_pos = first_end then sec_start
      else if cur_pos = sec_end then first_start
      else cur_pos + 1

  let next_base_none_pos state cur_pos = 
    let p = parallelism state in
    let new_pos = next_pos p cur_pos in
    match Ring_buffer.read_i state.jobs new_pos with
    | Base None -> Some new_pos
    | _         -> None (*Assuming that Base Somes are picked in the same order*)

    
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

  let read_all (t: ('a, 'd) State.t) =
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

  let step_once : type a d.
      (a, d) t -> a State.Completed_job.t Queue.t -> bool Or_error.t =
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
        | Base None, _ ->
              Or_error.error_string 
                (sprintf "Parallel scan: Not enough data to proceed. Buffer index %d" i)
        | Merge_up (Some x), _ ->
            t.acc <- (fst t.acc |> Int.( + ) 1, Some x) ;
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
            let _ = Queue.dequeue completed_jobs_q in
            work_done := true ;
            if Option.is_none t.base_none_pos then
            begin t.base_none_pos <- Some i end;
            t.current_data_length <- t.current_data_length - 1 ;
            Ok (Base None))
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

  let consume : type a d.
      (a, d) t -> a State.Completed_job.t list -> a option Or_error.t =
   fun t completed_jobs ->
    let open Or_error.Let_syntax in
    let open Job in
    let open Completed_job in
    let completed_jobs_q = Queue.of_list completed_jobs in
    let last_acc = t.acc in
    let%map enough_steps =
      List.fold ~init:(return ()) completed_jobs ~f:(fun acc cj ->
          let%bind () = acc in
          let%map work_done = step_once t completed_jobs_q in
          () )
    in
    if not (fst last_acc = fst t.acc) then snd t.acc else None



  let include_one state value base_pos : unit Or_error.t=
    let f (job: ('a, 'd) State.Job.t) : ('a, 'd) State.Job.t Or_error.t= match job with
      | Base None -> Ok (Base (Some value));
      | _         -> Or_error.error_string "Invalid job encountered while enqueuing data"
    in
    Ring_buffer.direct_update (State.jobs state) base_pos ~f
  
  let include_many (state :('a, 'd) State.t) data : unit Or_error.t= 
    List.fold ~init:(Ok ()) data ~f: (fun b a ->
      let open Or_error.Let_syntax in
      let base_pos = State.base_none_pos state in
      match base_pos with
      | None     -> Or_error.error_string "No empty leaves"
      | Some pos -> let%bind () = include_one state a pos in
        state.base_none_pos <- next_base_none_pos state pos;
        Ok ()
      )
end

module Available_job = struct
  type ('a, 'd) t = Base of 'd | Merge of 'a * 'a [@@deriving sexp]
end

let start : type a d. parallelism_log_2:int -> (a, d) State.t = State1.create

let next_jobs : state:('a, 'd) State1.t -> ('a, 'd) Available_job.t list =
 fun ~state ->
  let max = State1.parallelism state in
  List.filter_map (State1.read_all state) ~f:(fun job ->
      let module J = State1.Job in
      let module A = Available_job in
      match job with
      | J.Base (Some d) -> Some (A.Base d)
      | J.Base None -> None
      | J.Merge (None, _) -> None
      | J.Merge (_, None) -> None
      | J.Merge (Some a, Some b) -> Some (A.Merge (a, b))
      | J.Merge_up _ -> None )
  |> Fn.flip List.take max

let next_k_jobs :
       state:('a, 'd) State1.t
    -> k:int
    -> ('a, 'd) Available_job.t list Or_error.t =
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

let free_space : state:('a, 'd) State1.t -> int =
 fun ~state -> state.State1.capacity - State.current_data_length state

let enqueue_data : state:('a, 'd) State1.t -> data:'d list -> unit Or_error.t =
 fun ~state ~data ->
 let open Or_error.Let_syntax in
  if free_space state < List.length data then
    Or_error.error_string
      (sprintf
         "Data list too large. Max available is %d, current list length is %d"
         (free_space state) (List.length data))
  else (
    state.current_data_length <- state.current_data_length + List.length data ;
    State1.include_many state data
    )

let fill_in_completed_jobs :
       state:('a, 'd) State1.t
    -> jobs:'a State1.Completed_job.t list
    -> 'b option Or_error.t =
 fun ~state ~jobs -> State1.consume state jobs

let gen :
       gen_data:'d Quickcheck.Generator.t
    -> parallelism_log_2:int
    -> f_job_done:(   ('a, 'd) State.t
                   -> ('a, 'd) Available_job.t
                   -> 'a State.Completed_job.t)
    -> f_acc:(int * 'a option -> 'a -> 'a option)
    -> ('a, 'd) State.t Quickcheck.Generator.t =
 fun ~gen_data ~parallelism_log_2 ~f_job_done ~f_acc ->
  let open Quickcheck.Generator.Let_syntax in
  let%bind seed = gen_data in
  let s = State1.create ~parallelism_log_2 in
  (*Printf.printf !"1. State before enqueuing %{sexp: (Int64.t, Int64.t) State1.t}\n" s;*)
  Or_error.ok_exn @@ enqueue_data ~state:s ~data:[seed] ;
  (*Printf.printf !"2. State after enqueuing %{sexp: (Int64.t, Int64.t) State1.t}\n" s;*)
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
  List.fold data_chunks ~init:s ~f:(fun s chunk ->
      let jobs = next_jobs ~state:s in
      let jobs_done = List.map jobs (f_job_done s) in
      let old_tuple = s.acc in
      (*Printf.printf !"3. State before enqueuing %{sexp: (Int64.t, Int64.t) State1.t}\nData: %{sexp: Int64.t list}\n" s chunk;*)
      let _ = Or_error.ok_exn @@ enqueue_data s chunk in
      (*Printf.printf !"4. State after enqueuing %{sexp: (Int64.t, Int64.t) State1.t}\nJobs: %{sexp: Int64.t  State1.Completed_job.t list}\n" s jobs_done;*)
      Option.iter
        (Or_error.ok_exn @@ State1.consume s jobs_done)
        ~f:(fun x ->
          let tuple =
            if Option.is_some (snd old_tuple) then old_tuple else s.acc
          in
          s.acc <- (fst s.acc, f_acc tuple x) ) ;
      (*Printf.printf !"5. State after consume %{sexp: (Int64.t, Int64.t) State1.t}\n" s;*)
      s )

let%test_module "scans" =
  ( module struct
    let enqueue state ds =
      let free_space = free_space state in
      if free_space >= List.length ds then (
        Or_error.ok_exn @@ enqueue_data state ds ;
        [] )
      else (
        Or_error.ok_exn @@ enqueue_data state (List.take ds free_space) ;
        List.drop ds free_space )
        

    let rec step_on_free_space state w ds f f_acc =
      let rem_ds =
        if List.length ds > 0 then
          let new_ds = enqueue state ds in
          new_ds
        else []
      in
      let jobs = List.take (next_jobs ~state) 2 in
      let works = List.map jobs (f state) in
      let old_tuple = state.acc in
      let x' =
        Option.bind
          (Or_error.ok_exn @@ State1.consume state works)
          ~f:(fun x ->
            let merged =
              if Option.is_some (snd old_tuple) then f_acc old_tuple x
              else snd state.acc
            in
            state.acc <- (fst state.acc, merged) ;
            merged )
      in
      let%bind () = Linear_pipe.write w x' in
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
          match%bind Linear_pipe.read data with
          | `Eof -> return ()
          | `Ok seed ->
              let s = start ~parallelism_log_2 in
              Or_error.ok_exn @@ enqueue_data ~state:s ~data:[seed] ;
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

        let job_done (state: ('a, 'd) State1.t)
            (job: (Int64.t, Int64.t) Available_job.t) :
            Int64.t State.Completed_job.t =
          match job with
          | Base x -> Lifted x
          | Merge (x, y) -> Merged (Int64.( + ) x y)

        let%test_unit "scan can be initialized from intermediate state" =
          Backtrace.elide := false ;
          let g =
            gen ~parallelism_log_2:3
              ~gen_data:
                Quickcheck.Generator.Let_syntax.(Int.gen >>| Int64.of_int)
              ~f_job_done:job_done ~f_acc:f_merge_up
          in
          Quickcheck.test g ~sexp_of:[%sexp_of : (int64, int64) State.t]
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
                      ~f_acc:f_merge_up
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
                  let old_acc =
                    State1.acc s |> Option.value ~default:Int64.zero
                  in
                  let%bind v = fill_some_zeros Int64.zero s in
                  do_one_next := true ;
                  let acc = State1.acc s |> Option.value_exn in
                  assert (acc <> old_acc) ;
                  (* eventually we'll emit the acc+1 element *)
                  let%bind v' = fill_some_zeros v s in
                  let acc_plus_one = State1.acc s |> Option.value_exn in
                  return @@ assert (Int64.(equal acc_plus_one (acc + one))) ) )
      end )

    let%test_module "scan (+) over ints, map from string" =
      ( module struct
        let f_merge_up (tuple: int * int64 option) x =
          let open Option.Let_syntax in
          let%map acc = snd tuple in
          Int64.( + ) acc x

        let job_done (state: ('a, 'd) State1.t)
            (job: (Int64.t, string) Available_job.t) :
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
          let n = 30 in
          let result =
            scan
              ~data:(a_bunch_of_ones_then_zeros n)
              ~parallelism_log_2:3 ~f:job_done ~f_acc:f_merge_up
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
        let f_merge_up (tuple: int * string option) x =
          let open Option.Let_syntax in
          let%map acc = snd tuple in
          String.( ^ ) acc x

        let job_done (state: ('a, 'd) State1.t)
            (job: (string, string) Available_job.t) :
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
          let n = 40 in
          let result =
            scan
              ~data:(a_bunch_of_nums_then_empties n)
              ~parallelism_log_2:4 ~f:job_done ~f_acc:f_merge_up
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
