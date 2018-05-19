open Core_kernel
open Async_kernel

open Dependency_tree

module Make
  (M : Monad.S)
= struct
  module Ring_buffer = Ring_buffer.Make(M)

  module State = struct
    module Job = struct
      type ('a, 'd) t =
        | Merge_up of 'a option
        | Merge of 'a option * 'a option
        | Base of 'd option
      [@@deriving sexp, bin_io]

      let gen a_gen d_gen =
        let open Quickcheck.Generator in
        let open Quickcheck.Generator.Let_syntax in
        let maybe_a = Option.gen a_gen in
        match%map
          variant3
            maybe_a
            (tuple2 maybe_a maybe_a)
            (Option.gen d_gen)
        with
        | `A a -> Merge_up a
        | `B (a1, a2) -> Merge (a1, a2)
        | `C d -> Base d

      let gen_full a_gen d_gen =
        let open Quickcheck.Generator in
        let open Quickcheck.Generator.Let_syntax in
        match%map
          variant3
            a_gen
            (tuple2 a_gen a_gen)
            d_gen
        with
        | `A a -> Merge_up (Some a)
        | `B (a1, a2) -> Merge (Some a1, Some a2)
        | `C d -> Base (Some d)
    end

    type ('a, 'b, 'd) t =
      { jobs : ('a, 'd) Job.t Ring_buffer.t
      ; data_buffer : 'd Queue.t
      ; deps : int Dep_node.t Int.Table.t sexp_opaque
      ; mutable acc : 'b
      }
    [@@deriving sexp, bin_io]

    let acc {acc} = acc
    let jobs {jobs} = jobs

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
      let deps =
        build_dependency_map ~parallelism_log_2
      in

      let jobs = Ring_buffer.create ~len:(parallelism*2) ~default:(Base None) in

      let repeat n x = List.init n ~f:(fun _ -> x) in

      let merges1 = repeat ((parallelism / 2)-1) (Merge (None, None)) in
      let bases1 = repeat (parallelism / 2) (Base None) in
      let merges2 = repeat (parallelism / 2) (Merge (None, None)) in
      let bases2 = repeat (parallelism / 2) (Base None) in
      let top = Merge_up None in
      Ring_buffer.add_many jobs
        (merges1 @ bases1 @ merges2 @ bases2 @ [top]);
      assert (jobs.Ring_buffer.position = 0);

      let data_buffer = Queue.create ~capacity:parallelism () in
      Queue.enqueue data_buffer seed;
      { jobs
      ; data_buffer
      ; deps
      ; acc = init
      }

    let parallelism {deps} =
      (List.length (Int.Table.keys deps)) / 2

    let%test_unit "parallelism derived from deps" =
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

    let jobs_string t ~sexp_a ~sexp_d =
      (Ring_buffer.sexp_of_t
        (Job.sexp_of_t sexp_a sexp_d)
        t.jobs) |> Sexp.to_string_hum

    let consume :
      type a b d.
      (a, b, d) t ->
      d list ->
      merge:(b -> a -> b M.t) ->
      assoc_op:(a -> a -> a M.t) ->
      map:(d -> a M.t) ->
      sexp_a:(a -> Sexp.t) ->
      sexp_d:(d -> Sexp.t) ->
      eq_b:(b -> b -> bool) ->
      b option M.t
  = fun t ds ~merge ~assoc_op ~map ~sexp_a ~sexp_d ~eq_b ->
      let open Job in
      let open M.Let_syntax in
      let step () =
        let fill_job dir z job =
          let open Direction in
          match dir,job with
          | _, Merge_up _ -> Merge_up (Some z)
          | Left, Merge (_, r) -> Merge (Some z, r)
          | Right, Merge (l, _) -> Merge (l, Some z)
          | _, Base _ -> failwith "impossible: we never fill base"
        in
        let rewrite (i : int) (z : a) : unit M.t =
          let {Dep_node.dep} = Int.Table.find_exn t.deps i in
          match dep with
          | None -> failwith "impossible: deps always will exist"
          | Some ({Dep_node.data=ptr},dir) ->
              Ring_buffer.direct_update t.jobs ptr ~f:(fun job -> M.return (fill_job dir z job))
        in
        let%map () =
          Ring_buffer.update t.jobs ~f:(fun i job ->
            match job with
            | Merge_up None -> M.return job
            | Merge (None, None) -> M.return job
            | Base None ->
                Base (Some (Queue.dequeue_exn t.data_buffer)) |> M.return
            | Merge_up (Some x) ->
                let%map acc' = merge t.acc x in
                t.acc <- acc';
                Merge_up None
            | Merge (Some _, None)
            | Merge (None, Some _) ->
                failwithf !"impossible: We'll always have a complete merge %s\n%!" (jobs_string t ~sexp_a ~sexp_d) ()
            | Merge (Some x, Some y) ->
                let%bind z = assoc_op x y in
                let%map () = rewrite i z in
                Merge (None, None)
            | Base (Some d) ->
                let%bind z = map d in
                let%map () = rewrite i z in
                Base (Some (Queue.dequeue_exn t.data_buffer))
          )
        in
        Ring_buffer.forwards ~n:1 t.jobs
      in
      let last_acc = t.acc in
      let%map () = List.fold ~init:(M.return ()) ds ~f:(fun acc d ->
        let%bind () = acc in
        let%bind () = step () in
        let%map () = step () in
        Queue.enqueue t.data_buffer d;
      ) in
      if not (eq_b last_acc t.acc) then
        Some t.acc
      else
        None

    let gen ~sexp_a ~init ~gen_data ~sexp_d ~merge ~assoc_op ~map ~eq_b =
      let open Quickcheck.Generator.Let_syntax in
      let%bind seed = gen_data
           and parallelism_log_2 = Int.gen_incl 2 8
      in
      let s = create ~parallelism_log_2 ~init ~seed in
      let parallelism = Int.pow 2 parallelism_log_2 in
      let%bind len = Int.gen_incl (parallelism*2) (parallelism*10) in
      let%map datas = Quickcheck.Generator.list_with_length len gen_data in
      let data_chunks =
        let rec go datas chunks =
          if List.length datas < parallelism then
            datas::chunks
          else
            let (chunk, rest) = List.split_n datas parallelism in
            go rest (chunk::chunks)
        in
        go datas []
      in
      List.fold data_chunks ~init:s ~f:(fun acc chunk ->
        let _ = consume acc chunk ~merge ~assoc_op ~map ~sexp_a ~sexp_d ~eq_b in
        acc
      )
  end

  let handle_next_state state ~data ~merge ~map ~assoc_op ~sexp_a ~sexp_d ~eq_b w =
    let parallelism = State.parallelism state in
    let rec go () =
      match%bind Linear_pipe.read' ~max_queue_length:parallelism data with
      | `Eof -> return ()
      | `Ok q ->
        let ds = Queue.to_list q in
        let maybe_b = State.consume state ds ~merge ~map ~assoc_op ~sexp_a ~sexp_d ~eq_b in
        let%bind () = Linear_pipe.write w (maybe_b, state) in
        go ()
    in
    go ()

  let scan :
    type a b d.
    init:b ->
    data:d Linear_pipe.Reader.t ->
    parallelism_log_2:int ->
    map:(d -> a M.t) ->
    assoc_op:(a -> a -> a M.t) ->
    merge:(b -> a -> b M.t) ->
    sexp_a:(a -> Sexp.t) ->
    sexp_d:(d -> Sexp.t) ->
    eq_b:(b -> b -> bool) ->
    (b option M.t * (a, b, d) State.t) Linear_pipe.Reader.t
  =
   fun ~init ~data ~parallelism_log_2 ~map ~assoc_op ~merge ~sexp_a ~sexp_d ~eq_b ->
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
        match%bind Linear_pipe.read data with
        | `Eof -> return ()
        | `Ok seed ->
          let state : (a,b,d) State.t = State.create ~parallelism_log_2 ~init ~seed in
          handle_next_state state ~data ~merge ~map ~assoc_op ~sexp_a ~sexp_d ~eq_b w)

  let scan_from :
    type a b d.
    state:(a, b, d) State.t ->
    data:d Linear_pipe.Reader.t ->
    map:(d -> a M.t) ->
    assoc_op:(a -> a -> a M.t) ->
    merge:(b -> a -> b M.t) ->
    sexp_a:(a -> Sexp.t) ->
    sexp_d:(d -> Sexp.t) ->
    eq_b:(b -> b -> bool) ->
    (b option M.t * (a, b, d) State.t) Linear_pipe.Reader.t
  = fun ~state ~data ~map ~assoc_op ~merge ~sexp_a ~sexp_d ~eq_b ->
    Linear_pipe.create_reader ~close_on_exception:true
      (handle_next_state state ~data ~merge ~map ~assoc_op ~sexp_a ~sexp_d ~eq_b)
end

let%test_module "identity monad" = (module struct
  include Make(Monad.Ident)

  let%test_unit "scan can be initialized from intermediate state" =
    Quickcheck.test ~trials:10 ~sexp_of:[%sexp_of: (Int64.t, Int64.t, Int64.t) State.t]
      (State.gen
        ~sexp_a:Int64.sexp_of_t
        ~init:(Int64.of_int 0)
        ~gen_data:(
          let open Quickcheck.Generator.Let_syntax in
          Int.gen >>| Int64.of_int)
        ~sexp_d:Int64.sexp_of_t
        ~merge:Int64.(+)
        ~assoc_op:Int64.(+)
        ~map:Fn.id
        ~eq_b:Int64.equal) ~f:(fun s ->
          let do_one_next = ref false in
          (* For any arbitrary intermediate state *)
          let parallelism = State.parallelism s in
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
          Async.Thread_safe.block_on_async_exn (fun () ->
            let pipe =
              scan_from
                ~state:s
                ~data:one_then_zeros
                ~map:Fn.id
                ~assoc_op:Int64.(+)
                ~merge:Int64.(+)
                ~sexp_a:Int64.sexp_of_t
                ~sexp_d:Int64.sexp_of_t
                ~eq_b:Int64.equal
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
            let old_acc = State.acc s in
            let%bind (v, s) = fill_some_zeros Int64.zero s in
            do_one_next := true;
            let acc = State.acc s in
            assert (acc <> old_acc);
            (* eventually we'll emit the acc+1 element *)
            let%map (acc_plus_one, s') = fill_some_zeros v s in
            assert (acc_plus_one = Int64.(+) acc Int64.one)
          )
        )
  let%test_unit "scan behaves like a fold long-term" =
    let a_bunch_of_ones_then_zeros x =
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
        let rec go count =
          let next = if count <= 0 then "0" else "1" in
          let%bind () = Pipe.write w next in
          go (count-1)
        in
        go x)
    in
    let result =
      scan ~init:0
        ~data:(a_bunch_of_ones_then_zeros 100)
        ~parallelism_log_2:5
        ~map:Int.of_string
        ~assoc_op:Int.(+)
        ~merge:Int.(+)
        ~sexp_a:Int.sexp_of_t
        ~sexp_d:String.sexp_of_t
        ~eq_b:Int.equal
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
      let%map after_300 =
        List.init 300 ~f:(fun _ -> ()) |>
          Deferred.List.foldi ~init:0 ~f:(fun i acc _ ->
              match%map Linear_pipe.read result with
              | `Eof -> acc
              | `Ok (Some v, s) -> v
              | `Ok (None, _) -> acc)
      in
      let expected = List.fold (List.init 100 ~f:(fun _ -> 1)) ~init:0 ~f:Int.(+) in
      assert (after_300 = expected)
    )
end)
