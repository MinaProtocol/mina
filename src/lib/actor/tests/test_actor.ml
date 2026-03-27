let () =
  let open Alcotest in
  run "Actor"
    [ ("ping pong", [ test_case "Simple ping pong" `Quick Ping_pong.test_case ])
    ]
