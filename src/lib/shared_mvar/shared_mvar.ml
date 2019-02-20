open Core_kernel
open Async_kernel
open Pipe_lib

module Listener = struct
  type 'a t =
    { pipe: 'a option Strict_pipe.Reader.t
    ; stop_listening: unit -> unit
    ; writer:
        ( 'a option
        , Strict_pipe.drop_head Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t }
  [@@deriving make]

  let pipe {pipe; _} = pipe

  let stop t =
    t.stop_listening () ;
    Strict_pipe.Writer.close t.writer
end

type 'a t =
  { mvar: 'a option Mvar.Read_only.t
  ; mutable cache: 'a option
  ; mvar_pipe_handle: 'a option Pipe.Reader.t
  ; mutable listeners: 'a Listener.t list }

let create mvar =
  let mvar_pipe_handle = Mvar.pipe_when_ready mvar in
  let t =
    { mvar
    ; cache= Mvar.peek mvar |> Option.join
    ; mvar_pipe_handle
    ; listeners= [] }
  in
  don't_wait_for
    (Pipe.iter_without_pushback t.mvar_pipe_handle ~f:(fun a ->
         t.cache <- a ;
         List.iter t.listeners ~f:(fun listener ->
             Strict_pipe.Writer.write listener.writer a ) )) ;
  t

let peek {cache; _} = cache

let close t =
  Pipe.close_read t.mvar_pipe_handle ;
  List.iter t.listeners ~f:Listener.stop

let observe t =
  let pipe, writer =
    Strict_pipe.create
      (Strict_pipe.Buffered (`Capacity 3, `Overflow Strict_pipe.Drop_head))
  in
  let listener =
    Listener.make ~pipe ~writer ~stop_listening:(fun () ->
        t.listeners
        <- List.filter t.listeners ~f:(fun listener ->
               not (phys_equal listener.writer writer) ) )
  in
  t.listeners <- listener :: t.listeners ;
  listener

(*
 * 1. Cached value is keeping peek working
 * 2. Multiple listeners receive the first mvar value
 * 3. Multiple listeners receive updates after changes
 * 4. Listeners can be closed, and other listeners still work
 * 5. Peek sees the latest value
 * 6. If we close the shared_mvar, all listeners stop
*)
let%test_unit "listeners properly receive updates" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let mvar = Mvar.create () in
      let initial = Some 0 in
      Mvar.set mvar initial ;
      let t = create (Mvar.read_only mvar) in
      (*1*)
      [%test_result: int option]
        ~message:"Initial value not observed when peeking" ~expect:initial
        (peek t) ;
      let l1 = observe t in
      let l2 = observe t in
      let%bind res1 = Strict_pipe.Reader.read (Listener.pipe l1)
      and res2 = Strict_pipe.Reader.read (Listener.pipe l2) in
      (*2*)
      [%test_result: [`Eof | `Ok of int option]]
        ~message:"Initial value not observed by first listener"
        ~expect:(`Ok initial) res1 ;
      [%test_result: [`Eof | `Ok of int option]]
        ~message:"Initial value not observed by second listener"
        ~expect:(`Ok initial) res2 ;
      (*3*)
      let next_value = Some 1 in
      Mvar.set mvar next_value ;
      let%bind res1 = Strict_pipe.Reader.read (Listener.pipe l1)
      and res2 = Strict_pipe.Reader.read (Listener.pipe l2) in
      [%test_result: [`Eof | `Ok of int option]]
        ~message:"Next_value not observed by first listener"
        ~expect:(`Ok next_value) res1 ;
      [%test_result: [`Eof | `Ok of int option]]
        ~message:"Next_value not observed by second listener"
        ~expect:(`Ok next_value) res2 ;
      (*4*)
      Listener.stop l1 ;
      let next_value = Some 2 in
      Mvar.set mvar next_value ;
      let%bind res1 = Strict_pipe.Reader.read (Listener.pipe l1)
      and res2 = Strict_pipe.Reader.read (Listener.pipe l2) in
      [%test_result: [`Eof | `Ok of int option]]
        ~message:"We stopped the first listener so it shouldn't read anything"
        ~expect:`Eof res1 ;
      [%test_result: [`Eof | `Ok of int option]]
        ~message:"Third value is not observed by second listener"
        ~expect:(`Ok next_value) res2 ;
      (*5*)
      [%test_result: int option]
        ~message:"Latest value is observed when peeking" ~expect:next_value
        (peek t) ;
      (*6*)
      close t ;
      let next_value = Some 3 in
      Mvar.set mvar next_value ;
      let%bind res1 = Strict_pipe.Reader.read (Listener.pipe l1)
      and res2 = Strict_pipe.Reader.read (Listener.pipe l2) in
      [%test_result: [`Eof | `Ok of int option]]
        ~message:
          "Stopping the shared mvar should stop listeners, but listener1 is \
           alive"
        ~expect:`Eof res1 ;
      [%test_result: [`Eof | `Ok of int option]]
        ~message:
          "Stopping the shared mvar should stop listeners, but listener2 is \
           alive"
        ~expect:`Eof res2 ;
      return () )
