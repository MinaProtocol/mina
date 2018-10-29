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
    let level_pointer =
      Array.init (parallelism_log_2 + 1) ~f:(fun i -> Int.pow 2 i - 1)
    in
    jobs.position <- 0 ;
    { jobs
    ; level_pointer
    ; capacity= parallelism
    ; acc= (0, None)
    ; current_data_length= 0
    ; base_none_pos= Some (parallelism - 1)
    ; recent_tree_data= []
    ; other_trees_data= [] }

  let next_leaf_pos p cur_pos =
    if cur_pos = (2 * p) - 2 then p - 1 else cur_pos + 1

  (*Assuming that Base Somes are picked in the same order*)
  let next_base_pos state cur_pos =
    let p = parallelism state in
    let next_pos = next_leaf_pos p cur_pos in
    match Ring_buffer.read_i state.jobs next_pos with
    | Base None -> Some next_pos
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

  let rec parent_empty (t : ('a, 'b) Job.t Ring_buffer.t) pos =
    match pos with
    | 0 -> true
    | pos -> (
      match (dir pos, Ring_buffer.read_i t ((pos - 1) / 2)) with
      | `Left, Merge (None, _) -> true
      | `Right, Merge (_, None) -> true
      | _, Merge (Some _, Some _) -> parent_empty t ((pos - 1) / 2)
      | _, Base _ -> failwith "This shouldn't have occured"
      | _ -> false )

  (*Level_pointer stores a start index for each level. These are, at first, 
  the indices of the first node on each level and get incremented when a job is 
  completed at the specific index. The tree is still traveresed breadth-first 
  but the order of nodes on each level is determined using the start index that 
  is kept track of in the level_pointer. if the cur_pos is the last node on the 
  current level then next node is the first node on the next level otherwise 
  return the next node on the same level*)

  let next_position_info parallelism level_pointer cur_pos =
    let levels = Int.floor_log2 parallelism + 1 in
    let cur_level = Int.floor_log2 (cur_pos + 1) in
    let last_node = Int.pow 2 (cur_level + 1) - 2 in
    let first_node = Int.pow 2 cur_level - 1 in
    if
      (level_pointer.(cur_level) = first_node && cur_pos = last_node)
      || cur_pos = level_pointer.(cur_level) - 1
    then `Next_level level_pointer.(Int.( % ) (cur_level + 1) levels)
    else if cur_pos = last_node then `Same_level first_node
    else `Same_level (cur_pos + 1)

  let next_position parallelism level_pointer cur_pos =
    match next_position_info parallelism level_pointer cur_pos with
    | `Same_level pos -> pos
    | `Next_level pos -> pos

  let set_next_position t level_pointer =
    (t.jobs).position
    <- next_position (parallelism t) level_pointer t.jobs.position

  (*On each level, the jobs are completed starting from a specific index that 
  is stored in levels_pointer. When a job at that index is completed, it points 
  to the next job on the same level. After the last node of the level, the 
  index is set back to first node*)
  let incr_level_pointer t cur_pos =
    let cur_level = Int.floor_log2 (cur_pos + 1) in
    if t.level_pointer.(cur_level) = cur_pos then
      let last_node = Int.pow 2 (cur_level + 1) - 2 in
      let first_node = Int.pow 2 cur_level - 1 in
      if cur_pos + 1 <= last_node then
        t.level_pointer.(cur_level) <- cur_pos + 1
      else t.level_pointer.(cur_level) <- first_node
    else ()

  let fold_chronological t ~init ~f =
    let n = Array.length t.jobs.data in
    let rec go acc i pos =
      if Int.equal i n then acc
      else
        let x = t.jobs.data.(pos) in
        go (f acc x) (i + 1)
          (next_position (parallelism t) t.level_pointer pos)
    in
    go init 0 0

  let make_jobs_ordered f empty t =
    let rec go count t =
      if count = (parallelism t * 2) - 1 then empty
      else
        let j = Ring_buffer.read t.jobs in
        let pos = t.jobs.position in
        set_next_position t t.level_pointer ;
        (* build list or sequence *)
        f (j, pos) (go (count + 1) t)
    in
    (t.jobs).position <- 0 ;
    let js = go 0 t in
    (t.jobs).position <- 0 ;
    js

  let jobs_list t =
    let cons elt elts = elt :: elts in
    make_jobs_ordered cons [] t

  let jobs_sequence t =
    let open Sequence in
    let seq_cons elt elts = append (return elt) elts in
    make_jobs_ordered seq_cons empty t

  let read_jobs t =
    List.filter (jobs_list t) ~f:(fun (_, pos) -> parent_empty t.jobs pos)

  let read_jobs_sequence t =
    Sequence.filter (jobs_sequence t) ~f:(fun (_, pos) ->
        parent_empty t.jobs pos )

  let job_ready job =
    let module J = Job in
    let module A = Available_job in
    match job with
    | J.Base (Some d) -> Some (A.Base d)
    | J.Merge (Some a, Some b) -> Some (A.Merge (a, b))
    | _ -> None

  let jobs_ready state =
    List.filter_map (read_jobs state) ~f:(fun (job, _) -> job_ready job)

  let jobs_ready_sequence state =
    Sequence.filter_map (read_jobs_sequence state) ~f:(fun (job, _) ->
        job_ready job )

  let update_new_job t z dir pos =
    let new_job (cur_job : ('a, 'd) Job.t) : ('a, 'd) Job.t Or_error.t =
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
            t.other_trees_data
            <- List.take t.other_trees_data (List.length t.other_trees_data - 1) ;
            Ok () )
          else update_new_job t z (dir cur_pos) ((cur_pos - 1) / 2)
        in
        let () = incr_level_pointer t cur_pos in
        let%map () = update_cur_job t (Merge (None, None)) cur_pos in
        Work.Work_done
    | true, Base (Some _), Lifted z ->
        let%bind () = update_new_job t z (dir cur_pos) ((cur_pos - 1) / 2) in
        let%bind () = update_cur_job t (Base None) cur_pos in
        let () = incr_level_pointer t cur_pos in
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
    let level_pointer_before_update = Array.copy t.State.level_pointer in
    match completed_jobs with
    | [] -> Ok ()
    | j :: js ->
        let%bind next =
          match%map work t j jobs_copy with
          | Work.Not_done -> j :: js
          | Work.Work_done -> js
        in
        set_next_position t level_pointer_before_update ;
        consume t next jobs_copy

  let include_one_datum state value base_pos : unit Or_error.t =
    let open Or_error.Let_syntax in
    let f (job : ('a, 'd) State.Job.t) : ('a, 'd) State.Job.t Or_error.t =
      match job with
      | Base None -> Ok (Base (Some value))
      | _ ->
          Or_error.error_string "Invalid job encountered while enqueuing data"
    in
    let%map () = Ring_buffer.direct_update (State.jobs state) base_pos ~f in
    let last_leaf_pos = Ring_buffer.length state.jobs - 1 in
    if base_pos = last_leaf_pos then (
      state.other_trees_data
      <- (value :: state.recent_tree_data) :: state.other_trees_data ;
      state.recent_tree_data <- [] )
    else state.recent_tree_data <- value :: state.recent_tree_data

  let include_many_data (state : ('a, 'd) State.t) data : unit Or_error.t =
    List.fold ~init:(Ok ()) data ~f:(fun acc a ->
        let open Or_error.Let_syntax in
        let%bind () = acc in
        match State.base_none_pos state with
        | None -> Or_error.error_string "No empty leaves"
        | Some pos ->
            let%map () = include_one_datum state a pos in
            state.base_none_pos <- next_base_pos state pos )
end

let start : type a d. parallelism_log_2:int -> (a, d) State.t = State.create

let next_jobs : state:('a, 'd) State.t -> ('a, 'd) Available_job.t list =
 fun ~state -> State.jobs_ready state

let next_jobs_sequence :
    state:('a, 'd) State.t -> ('a, 'd) Available_job.t Sequence.t =
 fun ~state -> State.jobs_ready_sequence state

let next_k_jobs :
    state:('a, 'd) State.t -> k:int -> ('a, 'd) Available_job.t list Or_error.t
    =
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

let is_valid t =
  let p = State.parallelism t in
  let validate_leaves =
    let fold_over_leaves ~f ~init =
      let rec go count pos acc =
        if count = p then acc
        else
          let job = Ring_buffer.read_i t.jobs pos in
          let acc' = f acc job in
          go (count + 1) (State.next_leaf_pos p pos) acc'
      in
      go 0 (Option.value_exn (State.base_none_pos t)) init
    in
    let empty_leaves =
      fold_over_leaves
        ~f:(fun count job ->
          match job with Base None -> count + 1 | _ -> count )
        ~init:0
    in
    let continuous_empty_leaves =
      fold_over_leaves
        ~f:(fun (continue, count) job ->
          if continue then
            match job with
            | State.Job.Base None -> (continue, count + 1)
            | _ -> (false, count)
          else (false, count) )
        ~init:(true, 0)
    in
    free_space ~state:t = empty_leaves
    && empty_leaves = snd continuous_empty_leaves
  in
  let validate_levels =
    let fold_over_a_level ~f ~init level_start =
      let rec go pos acc =
        let job = Ring_buffer.read_i t.jobs pos in
        let acc' = f acc job in
        match State.next_position_info p t.level_pointer pos with
        | `Same_level pos' -> go pos' acc'
        | `Next_level _ -> acc'
      in
      go level_start init
    in
    let if_start_empty_all_empty level_start =
      let is_empty = function
        | State.Job.Base None -> true
        | Merge (None, None) -> true
        | _ -> false
      in
      let first_job = Ring_buffer.read_i t.jobs level_start in
      if is_empty first_job then
        fold_over_a_level
          ~f:(fun acc job -> acc && is_empty job)
          ~init:true level_start
      else true
    in
    let at_most_one_partial_job level_start =
      let is_partial = function
        | State.Job.Merge (Some _, None) -> 1
        | _ -> 0
      in
      let count =
        fold_over_a_level ~init:0
          ~f:(fun acc job -> acc + is_partial job)
          level_start
      in
      count < 2
    in
    Array.fold t.level_pointer ~init:true ~f:(fun acc level_start ->
        acc
        && if_start_empty_all_empty level_start
        && at_most_one_partial_job level_start )
  in
  let has_valid_merge_jobs =
    State.fold_chronological t ~init:true ~f:(fun acc job ->
        acc && match job with Merge (None, Some _) -> false | _ -> acc )
  in
  let non_empty_tree =
    State.fold_chronological t ~init:false ~f:(fun acc job ->
        acc
        ||
        match job with
        | Base (Some _) -> true
        | Merge (Some _, _) -> true
        | _ -> false )
  in
  Option.is_some (State.base_none_pos t)
  && free_space ~state:t > 0
  && has_valid_merge_jobs && non_empty_tree && validate_leaves
  && validate_levels

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

let last_emitted_value (state : ('a, 'd) State.t) = snd state.acc

let current_data (state : ('a, 'd) State.t) =
  state.recent_tree_data @ List.concat state.other_trees_data

let parallelism : state:('a, 'd) State.t -> int =
 fun ~state -> State.parallelism state

(*if the transaction queue does not have at least max_slots number of slots 
before continuing onto the next queue, split max_slots = (x,y) 
such that x = number of slots till the end of the current queue and y = max_slots - x (starts from the begining of the next queue)  *)
let partition_if_overflowing ~max_slots state =
  let n = min (free_space ~state) max_slots in
  let parallelism = State.parallelism state in
  let offset = parallelism - 1 in
  match State.base_none_pos state with
  | None -> `One 0
  | Some start ->
      let start_0 = start - offset in
      if n <= parallelism - start_0 then `One n
      else `Two (parallelism - start_0, n - (parallelism - start_0))

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
      assert (is_valid s) ;
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
            assert (is_valid state) ;
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
        let f_merge_up (state : int * int64 option) x =
          let open Option.Let_syntax in
          let%map acc = snd state in
          Int64.( + ) acc x

        let job_done (job : (Int64.t, Int64.t) Available_job.t) :
            Int64.t State.Completed_job.t =
          match job with
          | Base x -> Lifted x
          | Merge (x, y) -> Merged (Int64.( + ) x y)

        let%test_unit "Split only if enqueuing onto the next queue" =
          let p = 3 in
          let max_slots = Int.pow 2 (p - 1) in
          let leaves = max_slots * 2 in
          let offset = leaves - 1 in
          let last_index = (2 * leaves) - 2 in
          let g = Int.gen_incl 1 max_slots in
          let state = State.create ~parallelism_log_2:p in
          Quickcheck.test g ~trials:1000 ~f:(fun i ->
              let data = List.init i ~f:Int64.of_int in
              let partition = partition_if_overflowing ~max_slots:i state in
              let curr_head = Option.value_exn state.base_none_pos in
              let jobs = next_jobs ~state in
              let jobs_done = List.map jobs ~f:job_done in
              let _ =
                Or_error.ok_exn
                @@ fill_in_completed_jobs ~state ~completed_jobs:jobs_done
              in
              let () = Or_error.ok_exn @@ enqueue_data ~state ~data in
              match partition with
              | `One x ->
                  let expected_base_pos =
                    if curr_head + x = last_index + 1 then offset
                    else curr_head + x
                  in
                  assert (
                    Option.value_exn state.base_none_pos = expected_base_pos )
              | `Two (x, y) ->
                  assert (x + y = i) ;
                  assert (Option.value_exn state.base_none_pos = y + offset) )

        let%test_unit "non-emitted data tracking" =
          (* After a random number of steps, check if acc = current_state - data list*)
          let cur_value = ref 0 in
          let parallelism_log_2 = 4 in
          let one = Int64.of_int 1 in
          let state = State.create ~parallelism_log_2 in
          (*List.fold
            (List.init 20 ~f:(fun _ -> ()))
            ~init:()
            ~f:( *)
          let g = Int.gen_incl 1 (Int.pow 2 parallelism_log_2 / 2) in
          Quickcheck.test g ~trials:1000 ~f:(fun i ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  (*let i = free_space ~state - 1 in*)
                  let data = List.init i ~f:(fun _ -> one) in
                  let jobs = next_jobs ~state in
                  let jobs_done = List.map jobs ~f:job_done in
                  let old_tuple = state.acc in
                  let _ =
                    Option.bind
                      ( Or_error.ok_exn
                      @@ fill_in_completed_jobs ~state
                           ~completed_jobs:jobs_done )
                      ~f:(fun x ->
                        let merged =
                          if Option.is_some (snd old_tuple) then
                            f_merge_up old_tuple x
                          else snd state.acc
                        in
                        state.acc <- (fst state.acc, merged) ;
                        merged )
                  in
                  let _ = Or_error.ok_exn @@ enqueue_data ~state ~data in
                  cur_value := !cur_value + i ;
                  let acc_data =
                    List.sum (module Int64) (current_data state) ~f:Fn.id
                  in
                  let acc =
                    Option.value_map (snd state.acc) ~default:0
                      ~f:Int64.to_int_exn
                  in
                  let expected = !cur_value - Int64.to_int_exn acc_data in
                  (*Core.printf !"state: %{sexp: (Int64.t, Int64.t) State.t} \n %!" state;*)
                  assert (acc = expected) ;
                  assert (
                    List.length state.other_trees_data < parallelism_log_2 ) ;
                  return () ) )

        let%test_unit "scan can be initialized from intermediate state" =
          Backtrace.elide := false ;
          let g =
            gen
              ~gen_data:
                Quickcheck.Generator.Let_syntax.(Int.gen >>| Int64.of_int)
              ~f_job_done:job_done ~f_acc:f_merge_up
          in
          Quickcheck.test g ~sexp_of:[%sexp_of: (int64, int64) State.t]
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
        let f_merge_up (tuple : int * int64 option) x =
          let open Option.Let_syntax in
          let%map acc = snd tuple in
          Int64.( + ) acc x

        let job_done (job : (Int64.t, string) Available_job.t) :
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
        let f_merge_up (tuple : int * string option) x =
          let open Option.Let_syntax in
          let%map acc = snd tuple in
          String.( ^ ) acc x

        let job_done (job : (string, string) Available_job.t) :
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

    let%test_unit "Test for invalid states" =
      let exp = 3 in
      let not_valid = Fn.compose not is_valid in
      let ok = Or_error.ok_exn in
      let create_job (s : ('a, 'd) State.t) pos job =
        Ring_buffer.direct_update s.jobs pos ~f:(fun _ -> Ok job) |> ok
      in
      let empty_tree = State.create ~parallelism_log_2:exp in
      let p = State.parallelism empty_tree in
      assert (not_valid empty_tree) ;
      let level_i = Int.pow 2 (exp - 1) in
      let empty_leaves = empty_tree in
      let partial_jobs = State.copy empty_leaves in
      let () =
        List.fold ~init:() [level_i - 1; level_i + 1] ~f:(fun _ pos ->
            create_job partial_jobs pos (State.Job.Merge (Some 1, None)) )
      in
      assert (not_valid partial_jobs) ;
      let invalid_job = State.copy empty_leaves in
      let () =
        create_job invalid_job (level_i - 1) (State.Job.Merge (None, Some 1))
      in
      assert (not_valid invalid_job) ;
      let empty_jobs = State.copy empty_tree in
      let _ =
        List.fold ~init:() [p - 1; p] ~f:(fun _ pos ->
            create_job empty_jobs pos (Base (Some 1)) )
      in
      let _ = create_job empty_jobs level_i (Merge (Some 1, Some 1)) in
      assert (not_valid empty_jobs) ;
      let incorrect_data_length = State.copy empty_leaves in
      let incorrect_data_length =
        {incorrect_data_length with State.current_data_length= 4}
      in
      let _ =
        List.fold ~init:() [p - 1; p] ~f:(fun _ pos ->
            create_job incorrect_data_length pos (Base (Some 1)) )
      in
      assert (not_valid incorrect_data_length) ;
      let interspersed_data = State.copy incorrect_data_length in
      let _ =
        List.fold ~init:() [p + 2; p + 4] ~f:(fun _ pos ->
            create_job interspersed_data pos (Base (Some 1)) )
      in
      assert (not_valid interspersed_data)
  end )
