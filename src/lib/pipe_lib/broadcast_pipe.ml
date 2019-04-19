open Core_kernel
open Async_kernel

type 'a t =
  { root_pipe: 'a Pipe.Writer.t
  ; mutable cache: 'a
  ; mutable reader_id: int
  ; pipes: 'a writer_pipe Int.Table.t }
and 'b writer_pipe =
  | Leaf : 'b Pipe.Writer.t -> 'b writer_pipe
  | Node : ('b, 'child) descendant -> 'b writer_pipe
and ('b, 'descendant_type) descendant =
  { write: 'b -> unit Deferred.t
  ; (* Callback for how a descendant should handle a write *)
    child_pipe: 'descendant_type t Ivar.t
  (* HACK: this makes it easy to link pipes that do not have the same type *)
  }


exception Already_closed

let guard_already_closed t k =
  if Pipe.is_closed t.root_pipe then raise Already_closed else k ()

module Reader0 = struct
  type nonrec 'a t = 'a t

  let peek t = guard_already_closed t (fun () -> t.cache)

  let fresh_reader_id t =
    t.reader_id <- t.reader_id + 1 ;
    t.reader_id

  let prepare_pipe t ~f =
    guard_already_closed t (fun () ->
        let r, w = Pipe.create () in
        Pipe.write_without_pushback w (peek t) ;
        let reader_id = fresh_reader_id t in
        Int.Table.add_exn t.pipes ~key:reader_id ~data:(Leaf w) ;
        let d =
          let%map b = f r in
          Int.Table.remove t.pipes reader_id ;
          b
        in
        d )

  (* The sub-pipes have no downstream consumer, so the downstream flushed should
     always be determined and return `Ok. *)
  let add_trivial_consumer p =
    Pipe.add_consumer p ~downstream_flushed:(fun () -> Deferred.return `Ok)

  let fold t ~init ~f =
    prepare_pipe t ~f:(fun r ->
        let consumer = add_trivial_consumer r in
        Pipe.fold r ~init ~f:(fun acc v ->
            let%map res = f acc v in
            Pipe.Consumer.values_sent_downstream consumer ;
            res ) )

  let iter t ~f =
    prepare_pipe t ~f:(fun r ->
        let consumer = add_trivial_consumer r in
        Pipe.iter ~flushed:(Consumer consumer) r ~f:(fun v ->
            let%map () = f v in
            Pipe.Consumer.values_sent_downstream consumer ) )

  let to_jane_street_pipe t =
    guard_already_closed t (fun () ->
        let r, w = Pipe.create () in
        Pipe.write_without_pushback w (peek t) ;
        let reader_id = fresh_reader_id t in
        Int.Table.add_exn t.pipes ~key:reader_id ~data:(Leaf w) ;
        r )

  let is_closed t = Pipe.is_closed t.root_pipe
end

module Writer = struct
  type nonrec 'a t = 'a t

  let write t x =
    guard_already_closed t (fun () ->
        let%bind () = Pipe.write t.root_pipe x in
        let%bind _ = Pipe.downstream_flushed t.root_pipe in
        Deferred.unit )

  let rec close : type a. a t -> unit =
   fun t ->
    guard_already_closed t (fun () ->
        Pipe.close t.root_pipe ;
        Int.Table.iter t.pipes ~f:(function
          | Leaf writer -> Pipe.close writer
          | Node {child_pipe; _} -> Option.iter (Ivar.peek child_pipe) ~f:close ) ;
        Int.Table.clear t.pipes )
end

let create a =
  let root_r, root_w = Pipe.create () in
  let t =
    {root_pipe= root_w; cache= a; reader_id= 0; pipes= Int.Table.create ()}
  in
  let downstream_flushed_v : unit Ivar.t ref = ref @@ Ivar.create () in
  let consumer =
    Pipe.add_consumer root_r ~downstream_flushed:(fun () ->
        let%map () = Ivar.read !downstream_flushed_v in
        (* Sub-pipes are never closed without closing the master pipe. *)
        `Ok )
  in
  don't_wait_for
    (Pipe.iter ~flushed:(Consumer consumer) root_r ~f:(fun v ->
         t.cache <- v ;
         downstream_flushed_v := Ivar.create () ;
         let inner_pipes = Int.Table.data t.pipes in
         let%bind () =
           Deferred.List.iter ~how:`Parallel inner_pipes
             ~f:(function
             | Leaf writer -> Pipe.write writer v
             | Node {write; _} -> write v )
         in
         Pipe.Consumer.values_sent_downstream consumer ;
         let%bind () =
           Deferred.List.iter ~how:`Parallel inner_pipes
             ~f:(function
             | Leaf writer -> Deferred.ignore @@ Pipe.downstream_flushed writer
             | Node _ ->
                 Deferred.unit
                 (* A Broadcast pipe would get it's write determined after all of it's readers are consumed *) )
         in
         Ivar.fill !downstream_flushed_v () ;
         Deferred.unit )) ;
  (t, t)

module Reader = struct
  include Reader0

  (* The only reason for a descendant pipe to get removed from it's parent if it closes.
      The only way to do that right now is to close the pipe from the parent.
      Therefore, we do not have to be concerned about removing a mapped pipe. *)
  let map (t : 'a t) ~(f : 'a -> 'b) =
    guard_already_closed t (fun () ->
        let child_reader, child_writer = create @@ f (peek t) in
        let reader_id = fresh_reader_id t in
        let map_write a = Writer.write child_writer @@ f a in
        let child_pipe = Ivar.create_full child_writer in
        Int.Table.add_exn t.pipes ~key:reader_id
          ~data:(Node {write= map_write; child_pipe}) ;
        child_reader )

  let filter : type a. a t -> f:(a -> bool) -> a t Ivar.t =
   fun t ~f ->
    guard_already_closed t (fun () ->
        let (filter_pipe_ivar : a t Ivar.t) = Ivar.create () in
        let reader_id = fresh_reader_id t in
        let filter_write a =
          if f a then
            if Ivar.is_empty filter_pipe_ivar then (
              let pipe, _ = create a in
              Ivar.fill filter_pipe_ivar pipe ;
              Deferred.unit )
            else
              let%bind pipe = Ivar.read filter_pipe_ivar in
              Writer.write pipe a
          else Deferred.unit
        in
        Int.Table.add_exn t.pipes ~key:reader_id
          ~data:(Node {write= filter_write; child_pipe= filter_pipe_ivar}) ;
        filter_pipe_ivar )

  let merge readers =
    let merged_reader, merged_writer =
      create (Non_empty_list.head readers |> peek)
    in
    Non_empty_list.iter readers ~f:(fun reader ->
        guard_already_closed reader (fun () ->
            let merged_reader_id = fresh_reader_id reader in
            let merge_write a = Writer.write merged_writer a in
            Int.Table.add_exn reader.pipes ~key:merged_reader_id
              ~data:
                (Node
                   { write= merge_write
                   ; child_pipe= Ivar.create_full merged_writer }) ) ) ;
    merged_reader
end

module type Testable = sig
  include Sexpable.S

  include Equal.S with type t := t

  include Comparable.S with type t := t
end

let expect_pipe (type t) (module M : Testable with type t = t) t expected =
  let got_rev =
    Reader.fold t ~init:[] ~f:(fun acc a1 -> return @@ (a1 :: acc))
  in
  let%map got = got_rev >>| List.rev in
  [%test_result: M.t list]
    ~message:"Expected the following values from the pipe" ~expect:expected got

let expect_int_pipe = expect_pipe (module Int)

(*
 * 1. Cached value is keeping peek working
 * 2. Multiple listeners receive the first mvar value
 * 3. Multiple listeners receive updates after changes
 * 4. Peek sees the latest value
 * 5. If we close the broadcast pipe, all listeners stop
*)
let%test_unit "listeners properly receive updates" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let initial = 0 in
      let r, w = create initial in
      (*1*)
      [%test_result: int] ~message:"Initial value not observed when peeking"
        ~expect:initial (Reader.peek r) ;
      (* 2-3 *)
      let d1 = expect_int_pipe r [0; 1; 2] in
      let d2 = expect_int_pipe r [0; 1; 2] in
      don't_wait_for d1 ;
      don't_wait_for d2 ;
      let next_value = 1 in
      (*3*)
      let%bind () = Writer.write w next_value in
      (*4*)
      let next_value = 2 in
      let%bind () = Writer.write w next_value in
      (*5*)
      [%test_result: int] ~message:"Latest value is observed when peeking"
        ~expect:next_value (Reader.peek r) ;
      (*6*)
      Writer.close w ;
      Deferred.both d1 d2 >>| Fn.ignore )

let is_not_determined = Fn.compose not Deferred.is_determined

let%test_unit "Parent pipe of a descendant reader will get its pushback \
               determine when the descendant finishes consuming the \
               propagated value from  the pushback" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let initial_value = 0 in
      let reader, writer = create initial_value in
      let map_ivar = Ivar.create () in
      (* Mapped_reader will not get determined after all of it's children pipes consume the value it's propogating *)
      let mapped_reader = Reader.map reader ~f:Int.to_string in
      Reader.iter mapped_reader ~f:(fun value ->
          if value <> Int.to_string initial_value then Ivar.read map_ivar
          else Deferred.unit )
      |> don't_wait_for ;
      let new_value = initial_value + 1 in
      let all_consumers_read_value_pushback = Writer.write writer new_value in
      let%bind () = Async.after @@ Time.Span.of_sec 0.1 in
      [%test_pred: unit Deferred.t]
        ~message:"map pipe should not have been consumed" is_not_determined
        all_consumers_read_value_pushback ;
      Ivar.fill map_ivar () ;
      let%map () = all_consumers_read_value_pushback in
      Writer.close writer ;
      [%test_pred: string t sexp_opaque]
        ~message:"Mapped pipe should be closed" Reader.is_closed mapped_reader
  )

let%test_unit "Map maps values from parent pipe" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let initial_value = 0 in
      let reader, writer = create initial_value in
      let values_to_write = [1; 2; 3; 4] in
      let mapped_reader = Reader.map reader ~f:Int.to_string in
      let d =
        expect_pipe (module String) mapped_reader
        @@ List.map ~f:Int.to_string (initial_value :: values_to_write)
      in
      let%bind () =
        Deferred.List.iter ~how:`Sequential values_to_write
          ~f:(Writer.write writer)
      in
      Writer.close writer ; d )

let%test_unit "Filter filters values from parent pipe" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let initial = 0 in
      let r, w = create initial in
      let filtered_reader_ivar = Reader.filter r ~f:(fun x -> x % 2 = 0) in
      let d =
        let%bind filtered_reader = Ivar.read filtered_reader_ivar in
        expect_int_pipe filtered_reader [2; 4]
      in
      let%bind () =
        Deferred.List.init 4 ~how:`Sequential ~f:(fun x ->
            Writer.write w (x + 1) )
        |> Deferred.ignore
      in
      Writer.close w ; d )

module Test_input = struct
  module T = struct
    type t = [`A | `B | `C | `D] [@@deriving sexp, compare]
  end

  include T
  include Comparable.Make (T)
end

let%test_unit "Merges values from different pipes" =
  Core.Backtrace.elide := false ;
  Async.Thread_safe.block_on_async_exn (fun () ->
      let first_reader, first_writer = create `A in
      let second_reader, second_writer = create `C in
      let merged_reader =
        Reader.merge (Non_empty_list.init first_reader [second_reader])
      in
      let d =
        expect_pipe (module Test_input) merged_reader [`A; `B; `D; `A; `C]
      in
      let%bind () = Writer.write first_writer `B in
      let%bind () = Writer.write second_writer `D in
      let%bind () = Writer.write first_writer `A in
      let%bind () = Writer.write second_writer `C in
      Writer.close first_writer ;
      (* TODO: uncommenting the below code would cause the writer to throw an `Already_closed` exception. Handle that *)
      (* Writer.close second_writer; *)
      d )

let%test_module _ =
  ( module struct
    type iter_counts =
      {mutable immediate_iterations: int; mutable deferred_iterations: int}

    let zero_counts () = {immediate_iterations= 0; deferred_iterations= 0}

    let assert_immediate counts expected =
      [%test_eq: int] counts.immediate_iterations expected

    let assert_deferred counts expected =
      [%test_eq: int] counts.deferred_iterations expected

    let assert_both counts expected =
      assert_immediate counts expected ;
      assert_deferred counts expected

    let%test "Writing is synchronous" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Core.Backtrace.elide := false ;
          Async.Scheduler.set_record_backtraces true ;
          let pipe_r, pipe_w = create () in
          let counts1, counts2 = (zero_counts (), zero_counts ()) in
          let setup_reader counts =
            don't_wait_for
            @@ Reader.iter pipe_r ~f:(fun () ->
                   counts.immediate_iterations
                   <- counts.immediate_iterations + 1 ;
                   let%map () = Async.after @@ Time.Span.of_sec 1. in
                   counts.deferred_iterations <- counts.deferred_iterations + 1
               )
          in
          setup_reader counts1 ;
          (* The reader doesn't run until we yield. *)
          assert_both counts1 0 ;
          (* Once we yield, the reader has run, but has returned to the
             scheduler before setting deferred_iterations. *)
          let%bind () = Async.after @@ Time.Span.of_sec 0.1 in
          assert_immediate counts1 1 ;
          assert_deferred counts1 0 ;
          (* After we yield for long enough, deferred_iterations has been
             set. *)
          let%bind () = Async.after @@ Time.Span.of_sec 1.1 in
          assert_both counts1 1 ;
          (* Writing to the pipe blocks until the reader is finished. *)
          let%bind () = Writer.write pipe_w () in
          assert_both counts1 2 ;
          (* A second reader gets the current value, and all values written
             after its creation. *)
          setup_reader counts2 ;
          assert_both counts2 0 ;
          let%bind () = Async.after @@ Time.Span.of_sec 0.1 in
          assert_immediate counts2 1 ;
          assert_deferred counts2 0 ;
          let%bind () = Writer.write pipe_w () in
          assert_both counts1 3 ; assert_both counts2 2 ; Deferred.return true
      )
  end )
