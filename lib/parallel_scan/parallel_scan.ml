open Core_kernel
open Async_kernel

open Dependency_tree

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

  let consume :
    type a b d.
    (a, b, d) t ->
    spec:(module Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) ->
    d list ->
    b option Deferred.t
= fun t ~spec ds ->
    let open Job in
    let module Spec = (val spec : Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) in
    let jobs_string t =
      (Ring_buffer.sexp_of_t
        (Job.sexp_of_t Spec.Accum.sexp_of_t Spec.Data.sexp_of_t)
        t.jobs) |> Sexp.to_string_hum
    in
    let data_buffer_string t =
      Queue.sexp_of_t Spec.Data.sexp_of_t t.data_buffer |> Sexp.to_string_hum
    in
    let step () =
      let fill_job dir z job =
        let open Direction in
        match dir,job with
        | _, Merge_up _ -> Merge_up (Some z)
        | Left, Merge (_, r) -> Merge (Some z, r)
        | Right, Merge (l, _) -> Merge (l, Some z)
        | _, Base _ -> failwith "impossible: we never fill base"
      in
      let rewrite (i : int) (z : a) : unit Deferred.t =
        let {Dep_node.dep} = Int.Table.find_exn t.deps i in
        match dep with
        | None -> failwith "impossible: deps always will exist"
        | Some ({Dep_node.data=ptr},dir) ->
            Ring_buffer.direct_update t.jobs ptr ~f:(fun job -> fill_job dir z job |> return)
      in
      let%map () =
        Ring_buffer.update t.jobs ~f:(fun i job ->
          match job with
          | Merge_up None -> return job
          | Merge (None, None) -> return job
          | Base None ->
              Base (Some (Queue.dequeue_exn t.data_buffer)) |> return
          | Merge_up (Some x) ->
              let%map acc' = Spec.merge t.acc x in
              t.acc <- acc';
              Merge_up None
          | Merge (Some _, None)
          | Merge (None, Some _) -> (* only happens in the beginning *) return job
          | Merge (Some x, Some y) ->
              let%bind z = Spec.Accum.(+) x y in
              let%map () = rewrite i z in
              Merge (None, None)
          | Base (Some d) ->
              let%bind z = Spec.map d in
              let%map () = rewrite i z in
              Base (Some (Queue.dequeue_exn t.data_buffer))
        )
      in
      Ring_buffer.forwards ~n:1 t.jobs
    in
    let last_acc = t.acc in
    let%map () = List.fold ~init:(return ()) ds ~f:(fun acc d ->
      let%bind () = acc in
      printf !"BEFORE: %s;; %s\n%!" (jobs_string t) (data_buffer_string t);
      let%bind () = step () in
      printf !"AFTER1: %s;; %s\n%!" (jobs_string t) (data_buffer_string t);
      let%map () = step () in
      printf !"AFTER2: %s;; %s\n%!" (jobs_string t) (data_buffer_string t);
      Queue.enqueue t.data_buffer d;
    ) in
    if not (Spec.Output.equal last_acc t.acc) then
      Some t.acc
    else
      None

  let gen :
    type a b d.
    init:b ->
    gen_data:d Quickcheck.Generator.t ->
    spec:(module Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) ->
    (a, b, d) t Quickcheck.Generator.t
  = fun ~init ~gen_data ~spec ->
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
      let _ = consume acc chunk ~spec in
      acc
    )
end

let handle_next_state state ~data ~spec w =
  let parallelism = State1.parallelism state in
  let rec go () =
    match%bind Linear_pipe.read' ~max_queue_length:parallelism data with
    | `Eof -> return ()
    | `Ok q ->
      let ds = Queue.to_list q in
      let%bind maybe_b = State1.consume state ds ~spec in
      let%bind () = Linear_pipe.write w (maybe_b, state) in
      go ()
  in
  go ()

let scan :
  type a b d.
  init:b ->
  data:d Linear_pipe.Reader.t ->
  parallelism_log_2:int ->
  spec:(module Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) ->
  (b option * (a, b, d) State.t) Linear_pipe.Reader.t
=
 fun ~init ~data ~parallelism_log_2 ~spec ->
    Linear_pipe.create_reader ~close_on_exception:true (fun w ->
      match%bind Linear_pipe.read data with
      | `Eof -> return ()
      | `Ok seed ->
        let state : (a,b,d) State.t = State1.create ~parallelism_log_2 ~init ~seed in
        handle_next_state state ~data ~spec w)

let scan_from :
  type a b d.
  state:(a, b, d) State.t ->
  data:d Linear_pipe.Reader.t ->
  spec:(module Spec_intf with type Data.t = d and type Accum.t = a and type Output.t = b) ->
  (b option * (a, b, d) State.t) Linear_pipe.Reader.t
= fun ~state ~data ~spec ->
  Linear_pipe.create_reader ~close_on_exception:true
    (handle_next_state state ~data ~spec)

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

  (*
  let%test_unit "scan can be initialized from intermediate state" =
    Quickcheck.test ~trials:10 ~sexp_of:[%sexp_of: (Int64.t, Int64.t, Int64.t) State.t]
      (State1.gen
        ~init:(Int64.zero)
        ~gen_data:(
          let open Quickcheck.Generator.Let_syntax in
          Int.gen >>| Int64.of_int)
        ~spec) ~f:(fun s ->
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
          Async.Thread_safe.block_on_async_exn (fun () ->
            let pipe =
              scan_from
                ~state:s
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
        )
*)
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
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
        let rec go count =
          let next = if count <= 0 then "0" else "1" in
          let%bind () = Pipe.write w next in
          go (count-1)
        in
        go x)
    in
    let n = 20 in
    let result =
      scan ~init:Int64.zero
        ~data:(a_bunch_of_ones_then_zeros n)
        ~spec
        ~parallelism_log_2:3
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
      let%map after_300 =
        List.init (3*n) ~f:(fun _ -> ()) |>
          Deferred.List.foldi ~init:Int64.zero ~f:(fun i acc _ ->
              match%map Linear_pipe.read result with
              | `Eof -> acc
              | `Ok (Some v, s) -> v
              | `Ok (None, _) -> acc)
      in
      let expected = List.fold (List.init n ~f:(fun _ -> Int64.one)) ~init:Int64.zero ~f:Int64.(+) in
      printf !"\nExpected: %{sexp: Int64.t}\nButFound: %{sexp: Int64.t}\n\n%!" expected after_300;
      assert (after_300 = expected)
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
    let a_bunch_of_ones_then_empties x =
      Linear_pipe.create_reader ~close_on_exception:true (fun w ->
        let rec go count max =
          let next = if count <= 0 then "" else Int.to_string (max - count) ^ "," in
          let%bind () = Pipe.write w next in
          go (count-1) max
        in
        go x x)
    in
    let n = 40 in
    let result =
      scan ~init:""
        ~data:(a_bunch_of_ones_then_empties n)
        ~spec
        ~parallelism_log_2:4
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
      let%map after_300 =
        List.init (3*n) ~f:(fun _ -> ()) |>
          Deferred.List.foldi ~init:"" ~f:(fun i acc _ ->
              match%map Linear_pipe.read result with
              | `Eof -> acc
              | `Ok (Some v, s) -> v
              | `Ok (None, _) -> acc)
      in
      let expected = List.fold (List.init n ~f:(fun i -> Int.to_string i ^ ",")) ~init:"" ~f:String.(^) in
      printf "\nExpected %s\nButFound %s\n\n" expected after_300;
      assert (after_300 = expected)
    )
end)
