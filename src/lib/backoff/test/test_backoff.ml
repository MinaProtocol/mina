open Core_kernel
open Backoff

module Identity = struct
  type 'a t = 'a

  let return x = x

  let bind x ~f = f x

  let sleep _ = ()
end

module B = Make (Identity)

let test_strategy ?max_attempts () =
  Strategy.create ~base:(Time_ns.Span.of_sec 1.0)
    ~max_delay:(Time_ns.Span.of_sec 60.0) ~max_attempts
    ~random_state:(Random.State.make [| 0 |])
    ()

let logger = Logger.null ()

let test_succeeds_on_first_attempt () =
  let strategy = test_strategy ~max_attempts:3 () in
  let called = ref 0 in
  let f () = Int.incr called ; Ok "success" in
  let result = B.retry strategy ~logger ~f in
  Alcotest.(check bool) "result is ok" true (Result.is_ok result) ;
  Alcotest.(check int) "f called once" 1 !called

let test_succeeds_after_failures () =
  let strategy = test_strategy ~max_attempts:5 () in
  let called = ref 0 in
  let f () =
    Int.incr called ;
    if Int.equal !called 3 then Ok "success" else Error (Error.of_string "fail")
  in
  let result = B.retry strategy ~logger ~f in
  Alcotest.(check bool) "result is ok" true (Result.is_ok result) ;
  Alcotest.(check int) "f called 3 times" 3 !called

let test_exhausts_max_attempts () =
  let strategy = test_strategy ~max_attempts:3 () in
  let called = ref 0 in
  let f () = Int.incr called ; Error (Error.of_string "always fails") in
  let result = B.retry strategy ~logger ~f in
  Alcotest.(check bool) "result is error" true (Result.is_error result) ;
  Alcotest.(check int) "f called 3 times" 3 !called

let test_max_attempts_one_means_no_retries () =
  let strategy = test_strategy ~max_attempts:1 () in
  let called = ref 0 in
  let f () = Int.incr called ; Error (Error.of_string "fail") in
  let result = B.retry strategy ~logger ~f in
  Alcotest.(check bool) "result is error" true (Result.is_error result) ;
  Alcotest.(check int) "f called 1 time" 1 !called

let test_none_retries_indefinitely () =
  let strategy =
    Strategy.create ~base:(Time_ns.Span.of_ms 1.0)
      ~max_delay:(Time_ns.Span.of_sec 1.0) ~max_attempts:None
      ~random_state:(Random.State.make [| 0 |])
      ()
  in
  let called = ref 0 in
  let succeed_after = 10 in
  let f () =
    Int.incr called ;
    if Int.equal !called succeed_after then Ok "success" else Error (Error.of_string "fail")
  in
  let result = B.retry strategy ~logger ~f in
  Alcotest.(check bool) "result is ok" true (Result.is_ok result) ;
  Alcotest.(check int) "f called 10 times" 10 !called

let () =
  Alcotest.run "Backoff"
    [ ( "retry"
      , [ Alcotest.test_case "succeeds on first attempt" `Quick
            test_succeeds_on_first_attempt
        ; Alcotest.test_case "succeeds after failures" `Quick
            test_succeeds_after_failures
        ; Alcotest.test_case "exhausts max_attempts" `Quick
            test_exhausts_max_attempts
        ; Alcotest.test_case "max_attempts=1 means no retries" `Quick
            test_max_attempts_one_means_no_retries
        ; Alcotest.test_case "None retries indefinitely" `Quick
            test_none_retries_indefinitely
        ] )
    ]
