open Core_kernel
open Async_kernel

type t = { mutable running : int; mutable idle : unit Ivar.t }

let create () = { running = 0; idle = Ivar.create () }

let run t f =
  t.running <- t.running + 1 ;
  let%map result = Monitor.try_with ~here:[%here] ~run:`Now ~rest:`Raise f in
  t.running <- t.running - 1 ;
  if t.running = 0 then (
    Ivar.fill t.idle () ;
    t.idle <- Ivar.create () ) ;
  Result.ok_exn result

let idle t = if t.running = 0 then Deferred.unit else Ivar.read t.idle

let%test_module "In_flight" =
  ( module struct
    open Async

    let%test_unit "Idle waits for every running piece of work" =
      Thread_safe.block_on_async_exn (fun () ->
          let t = create () in
          let first = Ivar.create () and second = Ivar.create () in
          let ran =
            Deferred.both
              (run t (fun () -> Ivar.read first))
              (run t (fun () -> Ivar.read second))
          in
          let idle = idle t in
          Ivar.fill first () ;
          let%bind () = Scheduler.yield_until_no_jobs_remain () in
          assert (not (Deferred.is_determined idle)) ;
          Ivar.fill second () ;
          let%bind () = Scheduler.yield_until_no_jobs_remain () in
          assert (Deferred.is_determined idle) ;
          Deferred.ignore_m ran )

    let%test_unit "Work that raises is no longer in flight" =
      Thread_safe.block_on_async_exn (fun () ->
          let t = create () in
          let%bind result =
            Monitor.try_with (fun () ->
                run t (fun () ->
                    let%bind () = Scheduler.yield () in
                    failwith "raised" ) )
          in
          assert (Result.is_error result) ;
          let%bind () = Scheduler.yield_until_no_jobs_remain () in
          assert (Deferred.is_determined (idle t)) ;
          Deferred.unit )

    let%test_unit "A late exception from work reaches the caller's monitor" =
      Thread_safe.block_on_async_exn (fun () ->
          let t = create () in
          let reached = ref false in
          let monitor = Monitor.create () in
          Monitor.detach_and_iter_errors monitor ~f:(fun _ -> reached := true) ;
          let work () =
            upon (after (Core.Time.Span.of_ms 10.)) (fun () -> failwith "late") ;
            Deferred.unit
          in
          let%bind () = Scheduler.within' ~monitor (fun () -> run t work) in
          let%map () = after (Core.Time.Span.of_ms 50.) in
          assert !reached )

    let%test_unit "With nothing in flight, it is idle at once" =
      assert (Deferred.is_determined (idle (create ())))
  end )
