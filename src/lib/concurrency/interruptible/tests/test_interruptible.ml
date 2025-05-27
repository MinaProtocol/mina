open Core_kernel
open Async_kernel
open Interruptible

(* Test helper to convert a deferred async test into a synchronous test that can be run by Alcotest *)
let run_async_test f = Run_in_thread.block_on_async_exn f

(* Test: monad gets interrupted *)
let test_monad_gets_interrupted () =
  run_async_test (fun () ->
      let r = ref 0 in
      let wait i = after (Time_ns.Span.of_ms i) in
      let ivar = Ivar.create () in
      don't_wait_for
        (let open Let_syntax in
        let%bind () = lift Deferred.unit (Ivar.read ivar) in
        let%bind () = uninterruptible (wait 100.) in
        incr r ;
        let%map () = uninterruptible (wait 100.) in
        incr r) ;
      let open Deferred.Let_syntax in
      let%bind () = wait 130. in
      Ivar.fill ivar () ;
      let%map () = wait 100. in
      Alcotest.(check int) "Only first operation ran before interruption" 1 !r )

(* Test: monad gets interrupted within nested binds *)
let test_monad_gets_interrupted_within_nested_binds () =
  run_async_test (fun () ->
      let r = ref 0 in
      let wait i = after (Time_ns.Span.of_ms i) in
      let ivar = Ivar.create () in
      let rec go () =
        let open Let_syntax in
        let%bind () = uninterruptible (wait 100.) in
        incr r ; go ()
      in
      don't_wait_for
        (let open Let_syntax in
        let%bind () = lift Deferred.unit (Ivar.read ivar) in
        go ()) ;
      let open Deferred.Let_syntax in
      let%bind () = wait 130. in
      Ivar.fill ivar () ;
      let%map () = wait 100. in
      Alcotest.(check int) "Only first operation ran in nested bind" 1 !r )

(* Test: interruptions still run finally blocks *)
let test_interruptions_still_run_finally_blocks () =
  run_async_test (fun () ->
      let r = ref 0 in
      let wait i = after (Time_ns.Span.of_ms i) in
      let ivar = Ivar.create () in
      let rec go () =
        let open Let_syntax in
        let%bind () = uninterruptible (wait 100.) in
        incr r ; go ()
      in
      don't_wait_for
        (let open Let_syntax in
        let%bind () = lift Deferred.unit (Ivar.read ivar) in
        finally (go ()) ~f:(fun () -> incr r)) ;
      let open Deferred.Let_syntax in
      let%bind () = wait 130. in
      Ivar.fill ivar () ;
      let%map () = wait 100. in
      Alcotest.(check int) "One operation ran plus finally block" 2 !r )

(* Test: interruptions branches do not cancel each other *)
let test_interruptions_branches_do_not_cancel_each_other () =
  run_async_test (fun () ->
      let r = ref 0 in
      let s = ref 0 in
      let wait i = after (Time_ns.Span.of_ms i) in
      let ivar_r = Ivar.create () in
      let ivar_s = Ivar.create () in
      let rec go r =
        let open Let_syntax in
        let%bind () = uninterruptible (wait 100.) in
        incr r ; go r
      in
      (* Both computations hang off [start]. *)
      let start = uninterruptible Deferred.unit in
      don't_wait_for
        (let open Let_syntax in
        let%bind () = start in
        let%bind () = lift Deferred.unit (Ivar.read ivar_r) in
        go r) ;
      don't_wait_for
        (let open Let_syntax in
        let%bind () = start in
        let%bind () = lift Deferred.unit (Ivar.read ivar_s) in
        go s) ;
      let open Deferred.Let_syntax in
      let%bind () = wait 130. in
      Ivar.fill ivar_r () ;
      let%bind () = wait 100. in
      Ivar.fill ivar_s () ;
      let%map () = wait 100. in
      Alcotest.(check int) "First branch ran once" 1 !r ;
      Alcotest.(check int) "Second branch ran twice" 2 !s )

(* The test runner *)
let () =
  Alcotest.run "Interruptible"
    [ ( "interruption"
      , [ Alcotest.test_case "monad gets interrupted" `Quick
            test_monad_gets_interrupted
        ; Alcotest.test_case "monad gets interrupted within nested binds" `Quick
            test_monad_gets_interrupted_within_nested_binds
        ; Alcotest.test_case "interruptions still run finally blocks" `Quick
            test_interruptions_still_run_finally_blocks
        ; Alcotest.test_case "interruptions branches do not cancel each other"
            `Quick test_interruptions_branches_do_not_cancel_each_other
        ] )
    ]
