open Core_kernel
open Async

let logger = Logger.null ()

let register ~tier ~description ~log =
  Exit_handlers.register_async_shutdown_handler ~logger ~description ~tier
    (fun () ->
      log := !log @ [ description ] ;
      Deferred.unit )

let string_list_testable =
  Alcotest.testable
    (fun fmt l ->
      Format.fprintf fmt "[%a]"
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt "; ")
           Format.pp_print_string )
        l )
    (List.equal String.equal)

(* -- deterministic tests ------------------------------------------------- *)

let test_tier_order () =
  Exit_handlers.For_testing.reset () ;
  let log = ref [] in
  register ~tier:ReleaseDaemonLockfile ~description:"lockfile" ~log ;
  register ~tier:FlushPersistentFrontier ~description:"frontier" ~log ;
  register ~tier:DestroyConfigAndLedgers ~description:"config" ~log ;
  let%map () = Exit_handlers.For_testing.run_shutdown_handlers () in
  Alcotest.(check string_list_testable)
    "tiers execute in declaration order"
    [ "frontier"; "config"; "lockfile" ]
    !log

let test_fifo_within_tier () =
  Exit_handlers.For_testing.reset () ;
  let log = ref [] in
  register ~tier:FlushPersistentFrontier ~description:"first" ~log ;
  register ~tier:FlushPersistentFrontier ~description:"second" ~log ;
  register ~tier:FlushPersistentFrontier ~description:"third" ~log ;
  let%map () = Exit_handlers.For_testing.run_shutdown_handlers () in
  Alcotest.(check string_list_testable)
    "same-tier handlers run in FIFO order"
    [ "first"; "second"; "third" ]
    !log

let test_sequential_execution () =
  Exit_handlers.For_testing.reset () ;
  let log = ref [] in
  let register_delayed ~tier ~description ~delay =
    Exit_handlers.register_async_shutdown_handler ~logger ~description ~tier
      (fun () ->
        let%map () = after (Time.Span.of_sec delay) in
        log := !log @ [ description ] )
  in
  register_delayed ~tier:FlushPersistentFrontier ~description:"slow-frontier"
    ~delay:0.1 ;
  register_delayed ~tier:DestroyConfigAndLedgers ~description:"fast-config"
    ~delay:0.0 ;
  register_delayed ~tier:ReleaseDaemonLockfile ~description:"fast-lock"
    ~delay:0.0 ;
  let%map () = Exit_handlers.For_testing.run_shutdown_handlers () in
  Alcotest.(check string_list_testable)
    "handlers run sequentially across tiers"
    [ "slow-frontier"; "fast-config"; "fast-lock" ]
    !log

let test_fault_isolation () =
  Exit_handlers.For_testing.reset () ;
  let log = ref [] in
  register ~tier:FlushPersistentFrontier ~description:"before-fail" ~log ;
  Exit_handlers.register_async_shutdown_handler ~logger ~description:"will-fail"
    ~tier:FlushPersistentFrontier (fun () -> failwith "boom") ;
  register ~tier:FlushPersistentFrontier ~description:"after-fail" ~log ;
  register ~tier:DestroyConfigAndLedgers ~description:"next-tier" ~log ;
  let%map () = Exit_handlers.For_testing.run_shutdown_handlers () in
  Alcotest.(check string_list_testable)
    "failing handler does not block others"
    [ "before-fail"; "after-fail"; "next-tier" ]
    !log

(* -- property-based tests ------------------------------------------------ *)

let all_tiers =
  [| Exit_handlers.FlushPersistentFrontier
   ; Exit_handlers.DestroyConfigAndLedgers
   ; Exit_handlers.ReleaseDaemonLockfile
  |]

let tier_name = function
  | Exit_handlers.FlushPersistentFrontier ->
      "flush"
  | Exit_handlers.DestroyConfigAndLedgers ->
      "destroy"
  | Exit_handlers.ReleaseDaemonLockfile ->
      "release"

let tier_index = function
  | Exit_handlers.FlushPersistentFrontier ->
      0
  | Exit_handlers.DestroyConfigAndLedgers ->
      1
  | Exit_handlers.ReleaseDaemonLockfile ->
      2

let tier_gen =
  Quickcheck.Generator.map (Int.gen_incl 0 2) ~f:(fun i -> all_tiers.(i))

let handler_spec_gen =
  Quickcheck.Generator.map tier_gen ~f:(fun tier -> (tier, tier_name tier))

let handler_list_gen = Quickcheck.Generator.list_non_empty handler_spec_gen

let test_property_tier_ordering () =
  Quickcheck.test ~trials:200 handler_list_gen ~f:(fun handler_specs ->
      Exit_handlers.For_testing.reset () ;
      let log = ref [] in
      let handler_specs =
        List.mapi handler_specs ~f:(fun i (tier, _) ->
            (tier, Printf.sprintf "%s-%d" (tier_name tier) i) )
      in
      List.iter handler_specs ~f:(fun (tier, description) ->
          register ~tier ~description ~log ) ;
      Thread_safe.block_on_async_exn (fun () ->
          Exit_handlers.For_testing.run_shutdown_handlers () ) ;
      let expected =
        List.stable_sort handler_specs ~compare:(fun (t1, _) (t2, _) ->
            Int.compare (tier_index t1) (tier_index t2) )
        |> List.map ~f:snd
      in
      [%test_result: string list] !log ~expect:expected ) ;
  Deferred.unit

(* -- runner -------------------------------------------------------------- *)

let () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      Alcotest_async.run "Exit_handlers"
        [ ( "shutdown ordering"
          , [ Alcotest_async.test_case "tiers execute in declaration order"
                `Quick test_tier_order
            ; Alcotest_async.test_case "FIFO within same tier" `Quick
                test_fifo_within_tier
            ; Alcotest_async.test_case "sequential execution across tiers"
                `Quick test_sequential_execution
            ; Alcotest_async.test_case "failing handler does not block others"
                `Quick test_fault_isolation
            ] )
        ; ( "property-based"
          , [ Alcotest_async.test_case
                "any registration order respects tier + FIFO" `Quick
                test_property_tier_ordering
            ] )
        ] )
