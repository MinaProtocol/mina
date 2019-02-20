open Core_kernel
open Async_kernel

type 'a t =
  { root_pipe:
      ('a, Strict_pipe.synchronous, unit Deferred.t) Strict_pipe.Writer.t
  ; mutable cache: 'a
  ; mutable reader_id: int
  ; pipes:
      ( 'a Strict_pipe.Reader.t
      * ('a, Strict_pipe.synchronous, unit Deferred.t) Strict_pipe.Writer.t )
      Int.Table.t }

let create a =
  let r, w = Strict_pipe.create Strict_pipe.Synchronous in
  let t = {root_pipe= w; cache= a; reader_id= 0; pipes= Int.Table.create ()} in
  don't_wait_for
    (Strict_pipe.Reader.iter r ~f:(fun a ->
         t.cache <- a ;
         Deferred.List.iter ~how:`Parallel (Int.Table.data t.pipes)
           ~f:(fun (_, w) -> Strict_pipe.Writer.write w a ) )) ;
  (t, t)

exception Already_closed

let guard_already_closed t k =
  if Strict_pipe.Writer.is_closed t.root_pipe then raise Already_closed
  else k ()

module Reader = struct
  type nonrec 'a t = 'a t

  let peek t = guard_already_closed t (fun () -> t.cache)

  let fresh_reader_id t =
    t.reader_id <- t.reader_id + 1 ;
    t.reader_id

  let prepare_pipe t ~f =
    guard_already_closed t (fun () ->
        let r, w = Strict_pipe.create Strict_pipe.Synchronous in
        let reader_id = fresh_reader_id t in
        Int.Table.add_exn t.pipes ~key:reader_id ~data:(r, w) ;
        let d =
          don't_wait_for (Strict_pipe.Writer.write w (peek t)) ;
          let%map b = f r in
          Int.Table.remove t.pipes reader_id ;
          b
        in
        (d, w) )

  let fold t ~init ~f =
    prepare_pipe t ~f:(fun r -> Strict_pipe.Reader.fold r ~init ~f)

  let iter t ~f = prepare_pipe t ~f:(fun r -> Strict_pipe.Reader.iter r ~f)
end

module Writer = struct
  type nonrec 'a t = 'a t

  let write t x =
    guard_already_closed t (fun () -> Strict_pipe.Writer.write t.root_pipe x)

  let close t =
    guard_already_closed t (fun () ->
        Strict_pipe.Writer.close t.root_pipe ;
        Int.Table.iter t.pipes ~f:(fun (_, w) -> Strict_pipe.Writer.close w) ;
        Int.Table.clear t.pipes )
end

(*
let start dir =
  O1trace.forget_tid (fun () ->
      Async.Writer.open_file ~append:true
        (dir ^ "/" ^ sprintf "%d.trace" (Async.Unix.getpid () |> Pid.to_int))
      >>| O1trace.start_tracing )

let () = start "/tmp"
*)

(*
 * 1. Cached value is keeping peek working
 * 2. Multiple listeners receive the first mvar value
 * 3. Multiple listeners receive updates after changes
 * 4. Listeners can be closed, and other listeners still work
 * 5. Peek sees the latest value
 * 6. If we close the shared_mvar, all listeners stop
*)
let%test_unit "listeners properly receive updates" =
  Backtrace.elide := false ;
  let expect_pipe t expected =
    let got_rev, pipe =
      Reader.fold t ~init:[] ~f:(fun acc a1 -> return @@ (a1 :: acc))
    in
    let d =
      let%map got = got_rev >>| List.rev in
      [%test_result: int list]
        ~message:"Expected the following values from the pipe" ~expect:expected
        got
    in
    (d, pipe)
  in
  let yield () = Async.after (Time.Span.of_ms 10.) in
  Async.Thread_safe.block_on_async_exn (fun () ->
      let initial = 0 in
      let r, w = create initial in
      (*1*)
      [%test_result: int] ~message:"Initial value not observed when peeking"
        ~expect:initial (Reader.peek r) ;
      (* 2-3 *)
      let d1, p1 = expect_pipe r [0; 1] in
      let d2, _ = expect_pipe r [0; 1; 2] in
      don't_wait_for d1 ;
      don't_wait_for d2 ;
      let%bind () = yield () in
      let next_value = 1 in
      (*3*)
      let%bind () = Writer.write w next_value in
      (*4*)
      Strict_pipe.Writer.close p1 ;
      let%bind () = yield () in
      let next_value = 2 in
      let%bind () = Writer.write w next_value in
      let%bind () = yield () in
      (*5*)
      [%test_result: int] ~message:"Latest value is observed when peeking"
        ~expect:next_value (Reader.peek r) ;
      (*6*)
      let%bind () = yield () in
      Writer.close w ;
      let%bind () = yield () in
      Deferred.both d1 d2 >>| Fn.ignore )
