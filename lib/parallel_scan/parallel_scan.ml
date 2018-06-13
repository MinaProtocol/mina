open Core_kernel
open Async_kernel

module Direction = struct
  type t =
    | Left
    | Right
  [@@deriving sexp, eq, bin_io]
end

module Ring_buffer = Ring_buffer
module State = State

module type Spec_intf = sig
  module Data : sig
    type t [@@deriving sexp_of]
  end

  module Accum : sig
    type t [@@deriving sexp_of]
    (* Semigroup+deferred *)
    val ( + ) : t -> t -> t Deferred.t
  end

  module Output : sig
    type t [@@deriving sexp_of, eq]
  end

  val map : Data.t -> Accum.t Deferred.t
  val merge : Output.t -> Accum.t -> Output.t Deferred.t
end

module State1 = struct
  include State

  (* Creates state that placeholders-out all the right jobs in the right spot
   * also we need to seed the buffer with exactly one piece of work
   *)
  let create :
    type a b d.
    parallelism_log_2:int ->
    init:b ->
    seed:d ->
    (a, b, d) t
= fun ~parallelism_log_2 ~init ~seed ->
    let open Job in
    let parallelism = Int.pow 2 parallelism_log_2 in
    let jobs = Ring_buffer.create ~len:(parallelism*2) ~default:(Base None) in
    let repeat n x = List.init n ~f:(fun _ -> x) in
    let merges1 = repeat ((parallelism / 2)-1) (Merge (None, None)) in
    let bases1 = repeat (parallelism / 2) (Base None) in
    let merges2 = repeat (parallelism / 2) (Merge (None, None)) in
    let bases2 = repeat (parallelism / 2) (Base None) in
    let top = Merge_up None in
    List.iter
      [ merges1; bases1; merges2; bases2; [top] ]
      ~f:(Ring_buffer.add_many jobs);
    assert (jobs.Ring_buffer.position = 0);

    let data_buffer = Queue.create ~capacity:parallelism () in
    Queue.enqueue data_buffer seed;
    { jobs
    ; data_buffer
    ; acc = (0, init)
    }

  let parallelism {jobs} =
    (Ring_buffer.length jobs) / 2

  let%test_unit "parallelism derived from jobs" =
    let of_parallelism_log_2 x =
      let s = create ~parallelism_log_2:x ~init:0 ~seed:0 in
      assert(parallelism s = Int.pow 2 x)
    in
    of_parallelism_log_2 1;
    of_parallelism_log_2 2;
    of_parallelism_log_2 3;
    of_parallelism_log_2 4;
    of_parallelism_log_2 5;
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
    | x when x = n+1 -> (n, Left)
    | _ ->
      let x = i % n in
      let offset = if i >= n then 0 else n in
      (x/2 + offset, if x%2 = 0 then Left else Right)

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
    assert (p 8 = (0, Left));
    assert (p 9 = (8, Left));
    assert (p 1 = (8, Right));
    assert (p 2 = (9, Left));
    assert (p 3 = (9, Right));
    assert (p 10 = (1, Left));
    assert (p 11 = (1, Right));
    assert (p 12 = (2, Left));
    assert (p 13 = (2, Right));
    assert (p 14 = (3, Left));
    assert (p 15 = (3, Right));
    assert (p 4 = (10, Left));
    assert (p 5 = (10, Right));
    assert (p 6 = (11, Left));
    assert (p 7 = (11, Right))

  let consume :
    type a b d.
    (a, b, d) t ->
    spec:(module Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) ->
    d list ->
    b option Deferred.t
= fun t ~spec ds ->
    let open Job in
    let module Spec = (val spec : Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) in
    (* This breaks down if we ever step an odd number of times *)
    (* step_twice ensures we always step twice *)
    let step_twice () =
      let fill_job dir z job =
        let open Direction in
        match dir,job with
        | _, Merge_up None -> Merge_up (Some z)
        | Left, Merge (None, r) -> Merge (Some z, r)
        | Right, Merge (l, None) -> Merge (l, Some z)
        | Left, Merge_up (Some _) | Right, Merge_up (Some _) ->
            failwith "impossible: Merge_ups should be empty"
        | Left, Merge (Some _, _) | Right, Merge (_, Some _) -> failwithf !"impossible: the side of merge we want will be empty but we have %{sexp: Direction.t} and job %s" dir ((Job.sexp_of_t Spec.Accum.sexp_of_t Spec.Data.sexp_of_t job) |> Sexp.to_string_hum) ()
        | _, Base _ -> failwith "impossible: we never fill base"
      in
      (* Returns the ptr rewritten *)
      let rewrite (i : int) (z : a) : unit Deferred.t =
        let (ptr, dir) = ptr (parallelism t) i in
        Ring_buffer.direct_update t.jobs ptr ~f:(fun job -> fill_job dir z job |> return)
      in
      let%map () =
        (* Note: We don't have to worry about position overflow because
         * we always have an even number of elems in the ring buffer *)
        let (i1, i2) =
          match Ring_buffer.read t.jobs with
          (* SPECIAL CASE: When the merge is empty at this exact position
           * we have to flip the order. *)
          | Merge (None, Some _) | Merge (None, None) ->
            if t.jobs.position = parallelism t then
              (t.jobs.position+1, t.jobs.position)
            else
              (t.jobs.position, t.jobs.position+1)
          | _ -> (t.jobs.position, t.jobs.position+1)
        in
        let work i job =
          match job with
          | Merge_up None -> return job
          | Merge (None, None) -> return job
          | Base None ->
              return (Base (Some (Queue.dequeue_exn t.data_buffer)))
          | Merge_up (Some x) ->
              let%map acc' = Spec.merge (snd t.acc) x in
              t.acc <- (fst t.acc |> Int.(+) 1, acc');
              Merge_up None
          | Merge (Some _, None) ->
              return job
          | Merge (Some x, Some x') ->
              let%bind z = Spec.Accum.(+) x x' in
              let%map () = rewrite i z in
              Merge (None, None)
          | Base (Some d) ->
              let%bind z = Spec.map d in
              let%map () = rewrite i z in
              Base (Some (Queue.dequeue_exn t.data_buffer))
          | x -> failwithf !"Doesn't happen x:%s\n"
            ((Job.sexp_of_t Spec.Accum.sexp_of_t Spec.Data.sexp_of_t x) |> Sexp.to_string_hum) ()
        in
        let%bind () = Ring_buffer.direct_update t.jobs i1 ~f:(work i1) in
        Ring_buffer.direct_update t.jobs i2 ~f:(work i2)
      in
      Ring_buffer.forwards ~n:2 t.jobs
    in
    let last_acc = t.acc in
    let%map () = List.fold ~init:(return ()) ds ~f:(fun acc d ->
      let%bind () = acc in
      let%bind _ = after (Time_ns.Span.of_ms 5.) in
      let%bind () = step_twice () in
      let%map _ = after (Time_ns.Span.of_ms 5.) in
      Queue.enqueue t.data_buffer d;
    ) in
    if not (fst last_acc = fst t.acc) then
      Some (snd t.acc)
    else
      None

  let gen :
    type a b d.
    init:b ->
    gen_data:d Quickcheck.Generator.t ->
    spec:(module Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) ->
    (a, b, d) t Deferred.t Quickcheck.Generator.t
  = fun ~init ~gen_data ~spec ->
    let open Quickcheck.Generator.Let_syntax in
    let%bind seed = gen_data
         and parallelism_log_2 = Int.gen_incl 2 6
    in
    let s = create ~parallelism_log_2 ~init ~seed in
    let parallelism = Int.pow 2 parallelism_log_2 in
    let len = parallelism*2 in
    let%map datas = Quickcheck.Generator.list_with_length len gen_data in
    let data_chunks =
      let rec go datas chunks =
        if List.length datas < parallelism then
          List.rev (datas::chunks)
        else
          let (chunk, rest) = List.split_n datas parallelism in
          go rest (chunk::chunks)
      in
      go datas []
    in
    Deferred.List.fold data_chunks ~init:s ~f:(fun acc chunk ->
      let module Spec = (val spec : Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) in
      let open Deferred.Let_syntax in
      let%map _ = consume acc chunk ~spec in
      acc
    )
end

let handle_next_state state ~data ~spec =
  let parallelism = State1.parallelism state in
  match%bind Linear_pipe.read' ~max_queue_length:parallelism data with
  | `Eof -> Deferred.Or_error.error_string "No more data!"
  | `Ok q ->
    let ds = Queue.to_list q in
    let%map maybe_b = State1.consume state ds ~spec in
    Or_error.return (maybe_b, state)

let start :
  type a b d.
  init:b ->
  data:d Linear_pipe.Reader.t ->
  parallelism_log_2:int ->
  spec:(module Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) ->
  (b option * (a, b, d) State.t) Deferred.Or_error.t
=
 fun ~init ~data ~parallelism_log_2 ~spec ->
    match%bind Linear_pipe.read data with
    | `Eof -> Deferred.Or_error.error_string "No more data!"
    | `Ok seed ->
      let state : (a,b,d) State.t = State1.create ~parallelism_log_2 ~init ~seed in
      handle_next_state state ~data ~spec

let step :
  type a b d.
  state:(a, b, d) State.t ->
  data:d Linear_pipe.Reader.t ->
  spec:(module Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) ->
  (b option * (a, b, d) State.t) Deferred.Or_error.t
= fun ~state ~data ~spec ->
    handle_next_state state ~data ~spec

let%test_module "scans" = (module struct

  let do_steps ~state ~data ~spec w =
    let rec go () =
      match%bind step ~state ~data ~spec with
      | Ok v ->
          let%bind () = Linear_pipe.write w v in
          go ()
      | Error _ -> return ()
    in
    go ()

  let scan ~init ~data ~spec ~parallelism_log_2 =
    Linear_pipe.create_reader ~close_on_exception:true (fun w ->
      match%bind start ~init ~data ~spec ~parallelism_log_2 with
      | Error _ -> return ()
      | Ok (_, s) -> do_steps ~state:s ~data ~spec w
    )

  let step_repeatedly ~state ~data ~spec =
    Linear_pipe.create_reader ~close_on_exception:true (fun w ->
      do_steps ~state ~data ~spec w
    )

  let%test_module "scan (+) over ints" = (module struct
    module Spec = struct
      module Data = struct
        type t = Int64.t [@@deriving sexp_of]
      end

      module Accum = struct
        type t = Int64.t [@@deriving sexp_of]
        (* Semigroup+deferred *)
        let ( + ) t t' = Int64.(+) t t' |> return
      end

      module Output = struct
        type t = Int64.t [@@deriving sexp_of, eq]
      end

      let map x = return x
      let merge t t' = Int64.(+) t t' |> return
    end

    let spec = (module Spec : Spec_intf with type Data.t = Int64.t and type Accum.t = Int64.t and type Output.t = Int64.t)

    (* Once again Quickcheck is foiled by slow CPUs :( *)
    let%test_unit "scan can be initialized from intermediate state" =
      let g =
        State1.gen
          ~init:(Int64.zero)
          ~gen_data:(
            let open Quickcheck.Generator.Let_syntax in
            Int.gen >>| Int64.of_int)
          ~spec
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
                  if !do_one_next then begin
                    do_one_next := false;
                    Int64.one
                  end else Int64.zero
              in
              let%bind () = Pipe.write w next in
              go ()
            in
            go ())
        in

        let pipe =
          step_repeatedly ~state:s
            ~data:one_then_zeros
            ~spec
        in
        let fill_some_zeros v s =
          List.init (parallelism*parallelism) ~f:(fun _ -> ()) |>
            Deferred.List.foldi ~init:(v, s) ~f:(fun i (v, s) _ ->
                match%map Linear_pipe.read pipe with
                | `Eof -> v, s
                | `Ok (Some v', s') -> v', s'
                | `Ok (None, s') -> v, s')
        in
        (* after we flush intermediate work *)
        let old_acc = State1.acc s in
        let%bind (v, s) = fill_some_zeros Int64.zero s in
        do_one_next := true;
        let acc = State1.acc s in
        assert (acc <> old_acc);
        (* eventually we'll emit the acc+1 element *)
        let%map (acc_plus_one, s') = fill_some_zeros v s in
        assert (acc_plus_one = Int64.(+) acc Int64.one)
      )
  end)

  let%test_module "scan (+) over ints, map from string" = (module struct
    module Spec = struct
      module Data = struct
        type t = string [@@deriving sexp_of]
      end

      module Accum = struct
        type t = Int64.t [@@deriving sexp_of]
        (* Semigroup+deferred *)
        let ( + ) t t' = Int64.(+) t t' |> return
      end

      module Output = struct
        type t = Int64.t [@@deriving sexp_of, eq]
      end

      let map x = return (Int64.of_string x)
      let merge t t' = Int64.(+) t t' |> return
    end

    let spec = (module Spec : Spec_intf with type Data.t = string and type Accum.t = Int64.t and type Output.t = Int64.t)

    let%test_unit "scan behaves like a fold long-term" =
      let a_bunch_of_ones_then_zeros x =
        {Linear_pipe.Reader.pipe =
          Pipe.unfold ~init:x ~f:(fun count ->
            let next = if count <= 0 then "0" else (Int.to_string (x-count)) in
            return (Some (next, count-1))
          )
        ; has_reader = false
        }
      in
      let n = 20 in
      let result =
        scan ~init:Int64.zero
          ~data:(a_bunch_of_ones_then_zeros n)
          ~spec
          ~parallelism_log_2:3
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
        let%map after_3n =
          List.init (3*n) ~f:(fun _ -> ()) |>
            Deferred.List.foldi ~init:Int64.zero ~f:(fun i acc _ ->
                match%map Linear_pipe.read result with
                | `Eof -> acc
                | `Ok (Some v, s) -> v
                | `Ok (None, _) -> acc)
        in
        let expected = List.fold (List.init n ~f:(fun i -> Int64.of_int i)) ~init:Int64.zero ~f:Int64.(+) in
        assert (after_3n = expected)
      )
  end)

  let%test_module "scan (concat) over strings" = (module struct
    module Spec = struct
      module Data = struct
        type t = string [@@deriving sexp_of]
      end

      module Accum = struct
        type t = string [@@deriving sexp_of]
        (* Semigroup+deferred *)
        let ( + ) t t' = String.(^) t t' |> return
      end

      module Output = struct
        type t = string [@@deriving sexp_of, eq]
      end

      let map x = return x
      let merge t t' = String.(^) t t' |> return
    end

    let spec = (module Spec : Spec_intf with type Data.t = string and type Accum.t = string and type Output.t = string)

    let%test_unit "scan performs operation in correct order with non-commutative semigroup" =
      let a_bunch_of_nums_then_empties x =
        {Linear_pipe.Reader.pipe =
          Pipe.unfold ~init:x ~f:(fun count ->
            let next = if count <= 0 then "" else (Int.to_string (x-count)) ^ "," in
            return (Some (next, count-1))
          )
        ; has_reader = false
        }
      in
      let n = 40 in
      let result =
        scan ~init:""
          ~data:(a_bunch_of_nums_then_empties n)
          ~spec
          ~parallelism_log_2:4
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
        let%map after_3n =
          List.init (3*n) ~f:(fun _ -> ()) |>
            Deferred.List.foldi ~init:"" ~f:(fun i acc _ ->
                match%map Linear_pipe.read result with
                | `Eof -> acc
                | `Ok (Some v, s) -> v
                | `Ok (None, _) -> acc)
        in
        let expected = List.fold (List.init n ~f:(fun i -> Int.to_string i ^ ",")) ~init:"" ~f:String.(^) in
        assert (after_3n = expected)
      )
  end)
end)
