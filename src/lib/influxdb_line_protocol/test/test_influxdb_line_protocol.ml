open Core
module Point = Influxdb_line_protocol

let timestamp = Time_ns.of_int_ns_since_epoch 1_700_000_000_000_000_000

let point ?(measurement = "bench") ?tags fields =
  Point.create ~timestamp ?tags ~measurement fields

let line () =
  Alcotest.(check string)
    "line"
    "bench,branch=feature/x,variant=base\\ line\\,v\\=2 rows=288965i,ms=16.3 \
     1700000000000000000"
    (Point.to_line
       (point
          ~tags:[ ("branch", "feature/x"); ("variant", "base line,v=2") ]
          [ ("rows", Int 288965); ("ms", Float 16.3) ] ) )

let rejects name f =
  match f () with
  | (_ : Point.t) ->
      Alcotest.failf "accepted %s" name
  | exception Invalid_argument _ ->
      ()

let rejected () =
  let ok = [ ("rows", Point.Field.Int 1) ] in
  rejects "a measurement with a space" (fun () ->
      point ~measurement:"my bench" ok ) ;
  rejects "an empty measurement" (fun () -> point ~measurement:"" ok) ;
  rejects "a reserved name" (fun () -> point ~measurement:"_bench" ok) ;
  rejects "a tag key with a comma" (fun () -> point ~tags:[ ("a,b", "x") ] ok) ;
  rejects "an empty tag value" (fun () -> point ~tags:[ ("branch", "") ] ok) ;
  rejects "a multi-line tag value" (fun () ->
      point ~tags:[ ("branch", "a\nb") ] ok ) ;
  rejects "a tag given twice" (fun () ->
      point ~tags:[ ("branch", "a"); ("branch", "b") ] ok ) ;
  rejects "a field key with a space" (fun () -> point [ ("my rows", Int 1) ]) ;
  rejects "a field given twice" (fun () ->
      point [ ("rows", Int 1); ("rows", Int 2) ] ) ;
  rejects "a NaN field" (fun () -> point [ ("ms", Float Float.nan) ]) ;
  rejects "an infinite field" (fun () -> point [ ("ms", Float Float.infinity) ]) ;
  rejects "no field" (fun () -> point [])

let () =
  Alcotest.run "influxdb_line_protocol"
    [ ( "point"
      , [ Alcotest.test_case "line" `Quick line
        ; Alcotest.test_case "rejected" `Quick rejected
        ] )
    ]
