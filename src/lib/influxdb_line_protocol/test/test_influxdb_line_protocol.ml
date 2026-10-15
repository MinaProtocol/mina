open Core
module Point = Influxdb_line_protocol

let timestamp = Time_ns.of_int_ns_since_epoch 1_700_000_000_000_000_000

let line ?tags fields =
  Point.(to_line (create ~timestamp ?tags ~measurement:"bench" fields))

let check name expected got = Alcotest.(check string) name expected got

let field_types () =
  check "line"
    "bench,branch=compatible rows=288965i,ms=16.3,ok=true,note=\"x\" \
     1700000000000000000"
    (line
       ~tags:[ ("branch", "compatible") ]
       [ ("rows", Int 288965)
       ; ("ms", Float 16.3)
       ; ("ok", Bool true)
       ; ("note", String "x")
       ] )

let escaping () =
  check "measurement, tags, fields"
    "my\\ bench\\,x,a\\=b=c\\ d\\,e f\\ g=\"say \\\"hi\\\" \\\\\" \
     1700000000000000000"
    Point.(
      to_line
        (create ~timestamp ~measurement:"my bench,x"
           ~tags:[ ("a=b", "c d,e") ]
           [ ("f g", String "say \"hi\" \\") ] ))

let left_out () =
  check "empty tag and non-finite float"
    "bench,kept=1 ok=1i 1700000000000000000"
    (line
       ~tags:[ ("empty", ""); ("kept", "1") ]
       [ ("nan", Float Float.nan); ("ok", Int 1) ] )

let no_field () =
  match line [ ("nan", Float Float.infinity) ] with
  | _ ->
      Alcotest.fail "expected a failure for a point with no field"
  | exception Failure _ ->
      ()

let () =
  Alcotest.run "influxdb_line_protocol"
    [ ( "to_line"
      , [ Alcotest.test_case "field types" `Quick field_types
        ; Alcotest.test_case "escaping" `Quick escaping
        ; Alcotest.test_case "left out" `Quick left_out
        ; Alcotest.test_case "no field" `Quick no_field
        ] )
    ]
