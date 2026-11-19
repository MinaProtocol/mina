(** Testing
    -------
    Component: Vrf_evaluator
    Subject: Testing the VRF evaluator's slot search
    Invocation: dune exec \
      src/lib/vrf_evaluator/tests/test_vrf_evaluator.exe
*)

open Core

module Search_deadline_tests = struct
  let time ms = Block_time.of_int64 (Int64.of_int ms)

  let slot_start = time 100_000

  let slot_duration = Block_time.Span.of_ms 10_000L

  let check name ~current_time ~expected =
    Alcotest.(check (option int64))
      name
      (Option.map ~f:Block_time.to_int64 expected)
      (Option.map ~f:Block_time.to_int64
         (Vrf_evaluator.Worker_state.search_deadline
            ~current_time:(time current_time) ~slot_start ~slot_duration ) )

  let test_far_enough_ahead () =
    check "long before the lead deadline" ~current_time:0
      ~expected:(Some (time 80_000)) ;
    check "just before the lead deadline" ~current_time:79_999
      ~expected:(Some (time 80_000))

  let test_too_close () =
    check "at the lead deadline" ~current_time:80_000
      ~expected:(Some (time 105_000)) ;
    check "at the slot start" ~current_time:100_000
      ~expected:(Some (time 105_000)) ;
    check "just before the midpoint" ~current_time:104_999
      ~expected:(Some (time 105_000))

  let test_past_midpoint () =
    check "at the midpoint" ~current_time:105_000 ~expected:None ;
    check "after the slot" ~current_time:200_000 ~expected:None
end

let () =
  let open Alcotest in
  run "VRF evaluator tests"
    [ ( "search_deadline"
      , [ test_case "far enough ahead stops at the lead deadline" `Quick
            Search_deadline_tests.test_far_enough_ahead
        ; test_case "too close stops at the midpoint" `Quick
            Search_deadline_tests.test_too_close
        ; test_case "past the midpoint is skipped" `Quick
            Search_deadline_tests.test_past_midpoint
        ] )
    ]
