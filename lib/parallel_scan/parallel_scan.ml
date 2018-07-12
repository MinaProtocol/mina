open Core_kernel
open Async_kernel

module Direction = struct
  type t = Left | Right [@@deriving sexp, eq, bin_io]
end

module Ring_buffer = Ring_buffer
module State = State
module Queue = Queue

module type Spec_intf = sig
  module Data : sig
    type t [@@deriving sexp_of]
  end

  module Accum : sig
    type t [@@deriving sexp_of]

    (* Semigroup+deferred *)

    val ( + ) : t -> t -> t
  end

  module Output : sig
    type t [@@deriving sexp_of]
  end

  val map : Data.t -> Accum.t

  val merge : Output.t -> Accum.t -> Output.t
end

module State1 = struct
  include State

  (* Creates state that placeholders-out all the right jobs in the right spot
   * also we need to seed the buffer with exactly one piece of work
   *)
  let create : type a b d.
      parallelism_log_2:int -> init:b -> seed:d -> (a, b, d) t =
   fun ~parallelism_log_2 ~init ~seed ->
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
    Queue.enqueue data_buffer seed ;
    {jobs; data_buffer; acc= (0, init); current_data_length= 1}

  (* TODO Initial count cannot be zero, what should it be then?*)

  let parallelism {jobs} = Ring_buffer.length jobs / 2

  let%test_unit "parallelism derived from jobs" =
    let of_parallelism_log_2 x =
      let s = create ~parallelism_log_2:x ~init:0 ~seed:0 in
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

  let show_option opt = match opt with None -> "None" | Some x -> "Some x"

  let show_job (job: ('a, 'b) State.Job.t) : string =
    match job with
    | Base x -> "Base " ^ show_option x
    | Merge (x, y) -> "Merge " ^ show_option x ^ show_option y
    | Merge_up x -> "Merge_up " ^ show_option x

  let show_com_job (job: ('a, 'b) State.Completed_job.t) : string =
    match job with
    | Lifted x -> "Lifted "
    | Merged x -> "Merged "
    | Merged_up x -> "Merged_up "

  let consume : type a b d.
         (a, b, d) t
      -> (a, b) State.Completed_job.t list
      -> sexpa:(a -> Sexp.t)
      -> sexpb:(b -> Sexp.t)
      -> sexpd:(d -> Sexp.t (*-> ~sexp_a:('a -> Sexp.t)*))
      -> b option Or_error.t =
   fun t completed_jobs ~sexpa ~sexpb ~sexpd ->
    let open Or_error.Let_syntax in
    let open Job in
    let open Completed_job in
    let completed_jobs_q = Queue.of_list completed_jobs in
    (* This breaks down if we ever step an odd number of times *)
    (* step_twice ensures we always step twice *)
    let step_twice =
      let fill_job dir z job : (a, d) Job.t Or_error.t =
        let open Direction in
        match (dir, job) with
        | _, Merge_up None -> Ok (Merge_up (Some z))
        | Left, Merge (None, r) -> Ok (Merge (Some z, r))
        | Right, Merge (l, None) -> Ok (Merge (l, Some z))
        | Left, Merge_up (Some _) | Right, Merge_up (Some _) ->
            Error (Error.of_string "impossible: Merge_ups should be empty")
        | Left, Merge (Some _, _) | Right, Merge (_, Some _) ->
            failwithf
              !"impossible: the side of merge we want will be empty but we\n            \
                have %{sexp: Direction.t},job %s, completed job: %s"
              dir
              (Job.sexp_of_t sexpa sexpd job |> Sexp.to_string_hum)
              (sexpa z |> Sexp.to_string_hum)
              ()
        (*!"impossible: the side of merge we want will be empty but we \
                have %{sexp: Direction.t}" 
              dir
              ()*)
        | _, Base _ ->
            Error (Error.of_string "impossible: we never fill base")
      in
      (* Returns the ptr rewritten *)
      let rewrite (i: int) (z: a) : unit Or_error.t =
        let ptr, dir = ptr (parallelism t) i in
        let js : (a, d) Job.t Ring_buffer.t = t.jobs in
        Ring_buffer.direct_update js ptr ~f:(fun job -> fill_job dir z job)
      in
      let%bind () =
        (* Note: We don't have to worry about position overflow because
         * we always have an even number of elems in the ring buffer *)
        let i1, i2 =
          match Ring_buffer.read t.jobs with
          (* SPECIAL CASE: When the merge is empty at this exact position
           * we have to flip the order. *)
          | Merge (None, Some _)
           |Merge (None, None) ->
              if t.jobs.position = parallelism t then
                (t.jobs.position + 1, t.jobs.position)
              else (t.jobs.position, t.jobs.position + 1)
          | _ -> (t.jobs.position, t.jobs.position + 1)
        in
        let work i job : (a, d) Job.t Or_error.t =
          Printf.printf "In Work: Job: %s Completed Job %s \n"
            (Job.sexp_of_t sexpa sexpd job |> Sexp.to_string_hum)
            ( Option.sexp_of_t
                (Completed_job.sexp_of_t sexpa sexpb)
                (Queue.peek completed_jobs_q)
            |> Sexp.to_string_hum ) ;
          match (job, Queue.peek completed_jobs_q) with
          | Merge_up None, _ -> (*Printf.printf "Merge_up None";*) Ok job
          | Merge (None, None), _ ->
              Ok (*Printf.printf "Merge None None";*) job
          | Merge (None, Some _), _ ->
              Ok (*Printf.printf "Merge None None";*) job
          | Base None, _ -> (
            match
              (*Printf.printf "Base None";*)
              Queue.dequeue t.data_buffer
            with
            | None ->
                Printf.printf "queue empty" ;
                Or_error.error_string
                  (sprintf "Data buffer empty. Cannot proceed. %d" i)
            | Some x ->
                t.current_data_length <- t.current_data_length - 1 ;
                (*Printf.printf "Creating base job";*)
                Ok (Base (Some x)) )
          | Merge_up (Some x), Some (Merged_up acc') ->
              (*Printf.printf "Merge_up Some x";*)
              t.acc <- (fst t.acc |> Int.( + ) 1, acc') ;
              let _ = Queue.dequeue completed_jobs_q in
              Ok (Merge_up None)
          | Merge (Some _, None), _ ->
              (*Printf.printf "Merge Some None";*) Ok job
          | Merge (Some x, Some x'), Some (Merged z) ->
              (*Printf.printf "Merge Some Some";*)
              let%bind () = rewrite i z in
              let _ = Queue.dequeue completed_jobs_q in
              Ok (Merge (None, None))
          | Base (Some d), Some (Lifted z) -> (
              (*Printf.printf "Base Some";*)
              let%bind () = rewrite i z in
              match Queue.dequeue t.data_buffer with
              | None -> Ok (Base None)
              | Some x ->
                  t.current_data_length <- t.current_data_length - 1 ;
                  let _ = Queue.dequeue completed_jobs_q in
                  Ok (Base (Some x)) )
          | x, y ->
              failwith @@ "Doesn't happen x:\n" ^ show_job x
              ^ " Completed job: " ^ show_option y
          (*( Job.sexp_of_t (*Spec.Accum.sexp_of_t Spec.Data.sexp_of_t x*)
                |> Sexp.to_string_hum )
                ()*)
        in
        let%bind () = Ring_buffer.direct_update t.jobs i1 ~f:(work i1) in
        Ring_buffer.direct_update t.jobs i2 ~f:(work i2)
      in
      return (Ring_buffer.forwards ~n:2 t.jobs)
    in
    let last_acc = t.acc in
    let data_list = Queue.to_list t.data_buffer in
    let%map () =
      (*Printf.printf "Consume data buffer length:%d \n" (List.length data_list);*)
      List.fold ~init:(return ()) data_list ~f:(fun acc cj ->
          let%bind () = acc in
          let%map () = step_twice in
          () )
    in
    Printf.printf "last_int: %d last_acc: %s acc_int: %d acc: %s \n"
      (fst last_acc)
      (sexpb (snd last_acc) |> Sexp.to_string_hum)
      (fst t.acc)
      (sexpb (snd t.acc) |> Sexp.to_string_hum) ;
    if not (fst last_acc = fst t.acc) then Some (snd t.acc) else None
end

let start : type a b d.
    parallelism_log_2:int -> init:b -> seed:d -> (a, b, d) State.t =
  State1.create

let step : type a b d.
       state:(a, b, d) State.t
    -> data:(a, b) State1.Completed_job.t list
    -> sexpa:(a -> Sexp.t)
    -> sexpb:(b -> Sexp.t)
    -> sexpd:(d -> Sexp.t)
    -> b option Or_error.t =
 fun ~state ~data ~sexpa ~sexpb ~sexpd ->
  State1.consume state data ~sexpa ~sexpb ~sexpd

let next_job : state:('a, 'b, 'd) State1.t -> ('a, 'd) State1.Job.t option =
 fun ~state -> Some (Ring_buffer.read state.jobs)

let next_k_jobs :
       state:('a, 'b, 'd) State1.t
    -> k:int
    -> ('a, 'd) State1.Job.t list Or_error.t =
 fun ~state ~k -> Ok (Ring_buffer.read_k state.jobs k)

let next_jobs :
    state:('a, 'b, 'd) State1.t -> ('a, 'd) State1.Job.t list Or_error.t =
 fun ~state -> Ok (Ring_buffer.read_all state.jobs)

let is_not_none (job: ('a, 'd) State1.Job.t) =
  match job with
  | Base None -> false
  | Merge (None, _) -> false
  | Merge (_, None) -> false
  | Merge_up None -> false
  | _ -> true

let next_jobs_to_be_done :
    state:('a, 'b, 'd) State1.t -> ('a, 'd) State1.Job.t list Or_error.t =
 fun ~state -> Ok (List.filter (Ring_buffer.read_all state.jobs) is_not_none)

let free_space : state:('a, 'b, 'd) State1.t -> int =
 fun ~state ->
  let buff = State1.data_buffer state in
  Queue.capacity buff - State.current_data_length state

let enqueue_data :
    state:('a, 'b, 'd) State1.t -> data:'d list -> unit Or_error.t =
 fun ~state ~data ->
  if free_space state < List.length data then
    Or_error.error_string
      (sprintf
         "data list larger than allowed. Current number of items allowed to \
          be enqueued = %d, current list length:%d"
         (free_space state) (List.length data))
  else (
    state.current_data_length <- state.current_data_length + List.length data ;
    Ok
      (List.fold ~init:() data ~f:(fun () d ->
           Queue.enqueue state.data_buffer d )) )

let min_jobs = 2

let rec pairs lst =
  match lst with x :: y :: xs -> (x, y) :: pairs xs | _ -> []

let fill_in_completed_jobs :
       state:('a, 'b, 'd) State1.t
    -> jobs:('a, 'b) State1.Completed_job.t list
    -> 'b option Or_error.t =
 fun ~state ~jobs ->
  failwith
    (*if List.length jobs mod min_jobs <> 0 then
    (Printf.printf ( "Insufficient/incorrect number of completed jobs");
    step state jobs)
  else *)
    "TODO"

(*step ~state:state ~data:jobs ~sexpa ~sexpb ~sexpd*)

let incomplete_jobs (jobs: ('a, 'b) State.Job.t list) =
  List.filter_map jobs ~f:(fun job ->
      match job with
      | Base None -> Some None
      | Merge (None, _) -> Some None
      | Merge (_, None) -> Some None
      | Merge_up None -> Some None
      | _ -> None )
  |> List.length

(*let gen : 
         init:'b
      -> gen_data:'d Quickcheck.Generator.t
      -> f_job_done: (('a, 'b, 'd) State.t -> ('a,'d)State.Job.t -> ('a,'b) State.Completed_job.t)
      -> ('a, 'b, 'd) State.t Deferred.t Quickcheck.Generator.t =
   fun ~init ~gen_data ~f_job_done ->
    let open Quickcheck.Generator.Let_syntax in
    let%bind seed = gen_data and parallelism_log_2 = Int.gen_incl 2 3 in
    let s = State1.create ~parallelism_log_2 ~init ~seed in
    let parallelism = 
      Printf.printf "Initial data buffer length: %d, initial value: %d \n" (Queue.length @@ State.data_buffer s) (Option.value (Int64.to_int (Option.value (Queue.peek @@ State.data_buffer s) ~default: (Int64.of_int (-999))) )~default: (-999) );
      Int.pow 2 parallelism_log_2 in
    let len = (parallelism * 2) - 1  in
    let%map datas = Quickcheck.Generator.list_with_length len gen_data in
    let data_chunks =
      let rec go datas chunks =
        if List.length datas < parallelism then List.rev (datas :: chunks)
        else
          let chunk, rest = List.split_n datas parallelism in
          go rest (chunk :: chunks)
      in
      go datas []
    in
    Printf.printf "Gen: Data buffers length: %d \n" (List.length data_chunks);
    Deferred.List.fold data_chunks ~init:s ~f:(fun acc chunk ->
        let open Deferred.Let_syntax in
        let jobs = Or_error.ok_exn (next_jobs_to_be_done ~state:acc) in
        let jobs_done = 
          let () = Printf.printf "Gen: Jobs to be done: %d, data length: %d\n" (List.length jobs) (List.length chunk)
          in List.map jobs (f_job_done acc) 
        in
        let new_state = Or_error.ok_exn @@ enqueue_data acc chunk in
        let _ = 
          Printf.printf "Gen: Enqueued_data:%d " (Queue.length acc.data_buffer);
          Or_error.ok_exn @@ fill_in_completed_jobs ~state:new_state ~jobs:jobs_done
        in
        Printf.printf "Gen: Jobs to be done: %d \n" (List.length (Or_error.ok_exn @@ next_jobs_to_be_done new_state));
        return  new_state)
*)
let%test_module "scans" =
  ( module struct
    let do_steps ~state ~data ~f w ~showa ~showb ~showd =
      let rec go () =
        match%bind Linear_pipe.read' data with
        | `Eof -> return ()
        | `Ok q ->
            let show = State.sexp_of_t showa showb showd in
            let show_job = State1.Job.sexp_of_t showa showd in
            let show_comp_job = State1.Completed_job.sexp_of_t showa showb in
            let ds = Queue.to_list q in
            let jobs = Or_error.ok_exn (next_jobs_to_be_done ~state) in
            let works = List.map jobs (f state) in
            let _ =
              Printf.printf "1. Current State:%s\n"
                (show state |> Sexp.to_string_hum) ;
              Or_error.ok_exn (enqueue_data state ds)
            in
            let x =
              Printf.printf "2. After enqueuing data:%s\n"
                (show state |> Sexp.to_string_hum) ;
              Printf.printf "Jobs to be done: %s \n Jobs done:%s\n"
                ( String.concat
                @@ List.map jobs (fun job -> show_job job |> Sexp.to_string_hum)
                )
                ( String.concat
                @@ List.map works (fun job ->
                       show_comp_job job |> Sexp.to_string_hum ) ) ;
              match
                step ~state ~data:works ~sexpa:showa ~sexpb:showb ~sexpd:showd
              with
              | Ok y ->
                  Printf.printf "y: %s\n"
                    (Option.sexp_of_t showb y |> Sexp.to_string_hum) ;
                  y
              | Error e -> failwith (Error.to_string_hum e)
            in
            let%bind () =
              Printf.printf "3. After filling in the jobs:%s\n\n"
                (show state |> Sexp.to_string_hum) ;
              Linear_pipe.write w x
            in
            go ()
      in
      go ()

    let scan ~init ~data ~parallelism_log_2 ~f ~showa ~showb ~showd =
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
          match%bind Linear_pipe.read data with
          | `Eof -> return ()
          | `Ok seed ->
              let s = start ~init ~seed ~parallelism_log_2 in
              do_steps ~state:s ~data ~f w ~showa ~showb ~showd )

    let step_repeatedly ~state ~data ~f ~showa ~showb ~showd =
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
          do_steps ~state ~data ~f w ~showa ~showb ~showd )

    (*let%test_module "scan (+) over ints" =
      ( module struct
        (*module Spec = struct
          module Data = struct
            type t = Int64.t [@@deriving sexp_of]
          end

          module Accum = struct
            type t = Int64.t [@@deriving sexp_of]

            (* Semigroup+deferred *)
            let ( + ) t t' = Int64.( + ) t t'
          end

          module Output = struct
            type t = Int64.t [@@deriving sexp_of, eq]
          end

          let map x =  x

          let merge t t' = Int64.( + ) t t' 
        end

        let spec =
          ( module Spec
          : Spec_intf with type Data.t = Int64.t and type Accum.t = Int64.t and type 
            Output.t = Int64.t )*)

        let job_done (state:('a,'b,'d)State1.t) (job: (Int64.t, Int64.t )State.Job.t) : (Int64.t, Int64.t )State.Completed_job.t = match job with 
        | Base (Some x) -> Lifted x
        | Merge (Some x, Some y) -> Merged (Int64.( + ) x y)
        | Merge_up (Some x)      -> Merged_up (Int64.( + ) (snd state.acc) x)
        | _                      -> Lifted Int64.zero (*Dummy*)  

        let show_state (state : (Int64.t, Int64.t, Int64.t) State1.t) : Sexp.t =
          State1.sexp_of_t Int64.sexp_of_t (Int64.sexp_of_t) (Int64.sexp_of_t) state

        (* Once again Quickcheck is foiled by slow CPUs :( *)
        let%test_unit "scan can be initialized from intermediate state" =
          let g =
            gen ~init:Int64.zero
              ~gen_data:
                Quickcheck.Generator.Let_syntax.(Int.gen >>| Int64.of_int)
                ~f_job_done:job_done
          in
          let s = Quickcheck.random_value ~seed:Quickcheck.default_seed g in
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%bind s = s in
              let do_one_next = ref false in
              (* For any arbitrary intermediate state *)
              let parallelism = State1.parallelism s in
              (* if we then add 1 and a bunch of zeros *)
              let one_then_zeros =
                Linear_pipe.create_reader ~close_on_exception:true (fun w ->
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
              let pipe = step_repeatedly ~state:s ~data:one_then_zeros ~f:job_done ~show:show_state in
              let fill_some_zeros v s =
                List.init (parallelism * parallelism) ~f:(fun _ -> ())
                |> Deferred.List.foldi ~init:v ~f:(fun i v _ ->
                       match%map Linear_pipe.read pipe with
                       | `Eof -> v
                       | `Ok (Some v') -> v'
                       | `Ok None -> v )
              in
              (* after we flush intermediate work *)
              let old_acc = State1.acc s in
              let%bind v = fill_some_zeros Int64.zero s in
              do_one_next := true ;
              let acc = State1.acc s in
              Printf.printf "acc: %d, old_acc: %d \n" (Option.value (Int64.to_int acc) ~default: (-999)) (Option.value (Int64.to_int @@ old_acc) ~default: (-999)) ;
              assert (acc <> old_acc) ;
              (* eventually we'll emit the acc+1 element *)
              let%map acc_plus_one = fill_some_zeros v s in
              Printf.printf "Acc_plus_one: %d, From state: %d\n" (Option.value (Int64.to_int acc_plus_one) ~default: (-999)) (Option.value (Int64.to_int @@ Int64.( + ) acc Int64.one) ~default: (-999)) ;
              assert (acc_plus_one = Int64.( + ) acc Int64.one) )
      end )

*)
    let%test_module "scan (+) over ints, map from string" =
      ( module struct
        (*module Spec = struct
          module Data = struct
            type t = string [@@deriving sexp_of]
          end

          module Accum = struct
            type t = Int64.t [@@deriving sexp_of]

            (* Semigroup+deferred *)
            let ( + ) t t' = Int64.( + ) t t'
          end

          module Output = struct
            type t = Int64.t [@@deriving sexp_of, eq]
          end

          let map x = Int64.of_string x

          let merge t t' = Int64.( + ) t t' 
        end

        let spec =
          ( module Spec
          : Spec_intf with type Data.t = string and type Accum.t = Int64.t and type 
            Output.t = Int64.t )*)

        let job_done (state: ('a, 'b, 'd) State1.t)
            (job: (Int64.t, string) State.Job.t) :
            (Int64.t, Int64.t) State.Completed_job.t =
          match job with
          | Base (Some x) -> Lifted (Int64.of_string x)
          | Merge (Some x, Some y) -> Merged (Int64.( + ) x y)
          | Merge_up (Some x) -> Merged_up (Int64.( + ) (snd state.acc) x)
          | _ -> Lifted Int64.zero

        (*Dummy*)

        let show_state (state: (Int64.t, Int64.t, string) State1.t) : Sexp.t =
          State1.sexp_of_t Int64.sexp_of_t Int64.sexp_of_t Sexp.of_string state

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
          let n = 10 in
          let result =
            scan ~init:Int64.zero
              ~data:(a_bunch_of_ones_then_zeros n)
              ~parallelism_log_2:3 ~f:job_done ~showa:Int64.sexp_of_t
              ~showb:Int64.sexp_of_t ~showd:Sexp.of_string
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
              Printf.printf "after_3n: %d, expected: %d\n"
                (Option.value (Int64.to_int after_3n) ~default:(-999))
                (Option.value (Int64.to_int @@ expected) ~default:(-999)) ;
              assert (after_3n = expected) )
      end )

    let%test_module "scan (concat) over strings" =
      ( module struct
        (*module Spec = struct
          module Data = struct
            type t = string [@@deriving sexp_of]
          end

          module Accum = struct
            type t = string [@@deriving sexp_of]

            (* Semigroup+deferred *)
            let ( + ) t t' = String.( ^ ) t t'
          end

          module Output = struct
            type t = string [@@deriving sexp_of, eq]
          end

          let map x = x

          let merge t t' = String.( ^ ) t t'
        end

        let spec =
          ( module Spec
          : Spec_intf with type Data.t = string and type Accum.t = string and type 
            Output.t = string )*)

        let job_done (state: ('a, 'b, 'd) State1.t)
            (job: (string, string) State.Job.t) :
            (string, string) State.Completed_job.t =
          match job with
          | Base (Some x) -> Lifted x
          | Merge (Some x, Some y) -> Merged (String.( ^ ) x y)
          | Merge_up (Some x) -> Merged_up (String.( ^ ) (snd state.acc) x)
          | _ -> Lifted "X"

        (*Dummy*)

        let show_state (state: (string, string, string) State1.t) : Sexp.t =
          State1.sexp_of_t Sexp.of_string Sexp.of_string Sexp.of_string state

        let%test_unit "scan performs operation in correct order with \
                       non-commutative semigroup" =
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
              ~parallelism_log_2:4 ~f:job_done ~showa:Sexp.of_string
              ~showb:Sexp.of_string ~showd:Sexp.of_string
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
              Printf.printf "after_3n: %s, expected: %s \n" after_3n expected ;
              assert (after_3n = expected) )
      end )
  end )
