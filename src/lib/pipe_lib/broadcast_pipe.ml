open Core_kernel
open Async_kernel

type 'a t =
  { mvar: 'a option Mvar.Read_only.t
  ; mutable cache: 'a option
  ; mvar_pipe_handle: 'a option Pipe.Reader.t
  ; mutable id: int
  ; pipes:
      ( 'a option Strict_pipe.Reader.t
      * ( 'a option
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t )
      Int.Table.t }

let create mvar =
  let mvar_pipe_handle = Mvar.pipe_when_ready mvar in
  let t =
    { mvar
    ; cache= Mvar.peek mvar |> Option.join
    ; mvar_pipe_handle
    ; id= 0
    ; pipes= Int.Table.create () }
  in
  don't_wait_for
    (Pipe.iter_without_pushback t.mvar_pipe_handle ~f:(fun a ->
         t.cache <- a ;
         Int.Table.iter t.pipes ~f:(fun (_, w) -> Strict_pipe.Writer.write w a)
     )) ;
  t

let peek {cache; _} = cache

let close t =
  Pipe.close_read t.mvar_pipe_handle ;
  Int.Table.iter t.pipes ~f:(fun (_, w) -> Strict_pipe.Writer.close w) ;
  Int.Table.clear t.pipes

let fresh_id t =
  t.id <- t.id + 1 ;
  t.id

let prepare_pipe ~close t =
  let r, w =
    Strict_pipe.create
      (Strict_pipe.Buffered (`Capacity 3, `Overflow Strict_pipe.Drop_head))
  in
  let id = fresh_id t in
  Int.Table.add_exn t.pipes ~key:id ~data:(r, w) ;
  don't_wait_for
    (let%map () = close in
     Int.Table.remove t.pipes id ;
     Strict_pipe.Writer.close w) ;
  r

let fold ~close t =
  let r = prepare_pipe ~close t in
  Strict_pipe.Reader.fold r

let fold_without_pushback ~close t =
  let r = prepare_pipe ~close t in
  Strict_pipe.Reader.fold_without_pushback r

let iter ~close t =
  let r = prepare_pipe ~close t in
  Strict_pipe.Reader.iter r

let iter_without_pushback ~close t =
  let r = prepare_pipe ~close t in
  Strict_pipe.Reader.iter_without_pushback r

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
  Async.Scheduler.set_record_backtraces true ;
  let expect_pipe t ~close expected =
    let%map got =
      fold_without_pushback ~close t ~init:[] ~f:(fun acc a1 -> a1 :: acc)
      >>| List.rev
    in
    [%test_result: int option list]
      ~message:"Expected the following values from the pipe" ~expect:expected
      got
  in
  let yield () = Async.after (Time.Span.of_ms 10.) in
  Async.Thread_safe.block_on_async_exn (fun () ->
      let mvar = Mvar.create () in
      let initial = Some 0 in
      Mvar.set mvar initial ;
      let t = create (Mvar.read_only mvar) in
      (*1*)
      [%test_result: int option]
        ~message:"Initial value not observed when peeking" ~expect:initial
        (peek t) ;
      (* 2-3 *)
      let close1 = Ivar.create () in
      let d1 = expect_pipe t ~close:(Ivar.read close1) [Some 0; Some 1] in
      let d2 =
        expect_pipe t ~close:(Deferred.never ()) [Some 0; Some 1; Some 2]
      in
      don't_wait_for d1 ;
      don't_wait_for d2 ;
      let%bind () = yield () in
      let next_value = Some 1 in
      (*3*)
      Mvar.set mvar next_value ;
      let%bind () = yield () in
      (*4*)
      Ivar.fill close1 () ;
      let%bind () = yield () in
      let next_value = Some 2 in
      Mvar.set mvar next_value ;
      let%bind () = yield () in
      (*5*)
      [%test_result: int option]
        ~message:"Latest value is observed when peeking" ~expect:next_value
        (peek t) ;
      (*6*)
      close t ;
      let next_value = Some 3 in
      Mvar.set mvar next_value ;
      let%bind () = yield () in
      Deferred.both d1 d2 >>| Fn.ignore )
