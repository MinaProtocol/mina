open Core_kernel
open Bench_report

let floats = Alcotest.(option (float 0.))

let test_percentile () =
  let s = Stats.sorted [ 5.; 1.; 4.; 2.; 3. ] in
  Alcotest.check floats "p50" (Some 3.) (Stats.percentile s 0.5) ;
  Alcotest.check floats "p95" (Some 5.) (Stats.percentile s 0.95) ;
  Alcotest.check floats "p0" (Some 1.) (Stats.percentile s 0.) ;
  Alcotest.check floats "no sample" None (Stats.percentile [||] 0.95)

let test_median () =
  Alcotest.check floats "odd" (Some 2.)
    (Stats.median (Stats.sorted [ 3.; 1.; 2. ])) ;
  Alcotest.check floats "even" (Some 2.5)
    (Stats.median (Stats.sorted [ 4.; 1.; 2.; 3. ])) ;
  Alcotest.check floats "no sample" None (Stats.median [||])

let ts = Int63.of_int 7

let test_escaping () =
  Alcotest.(check (option string))
    "escaped" (Some {|my\ bench,branch=a\,b\=c\ d,shape=x lat\ ms=1.500,n=2i 7|})
    (Influx.line ~measurement:"my bench"
       ~tags:[ ("branch", "a,b=c d"); ("shape", "x"); ("empty", "") ]
       ~fields:[ ("lat ms", Float 1.5); ("n", Int 2) ]
       ~timestamp_ns:ts )

let test_non_finite () =
  Alcotest.(check (option string))
    "nan and infinity left out" (Some "m ok=1.000,c=3i 7")
    (Influx.line ~measurement:"m" ~tags:[]
       ~fields:
         [ ("p95", Float Float.nan)
         ; ("ok", Float 1.)
         ; ("max", Float Float.infinity)
         ; ("c", Int64 3L)
         ]
       ~timestamp_ns:ts ) ;
  Alcotest.(check (option string))
    "no field left" None
    (Influx.line ~measurement:"m" ~tags:[]
       ~fields:[ ("p95", Float Float.nan) ]
       ~timestamp_ns:ts )

let test_string_field () =
  Alcotest.(check (option string))
    "quoted" (Some {|m s="a\"b\\c" 7|})
    (Influx.line ~measurement:"m" ~tags:[]
       ~fields:[ ("s", String {|a"b\c|}) ]
       ~timestamp_ns:ts )

let () =
  Alcotest.run "bench_report"
    [ ( "stats"
      , [ Alcotest.test_case "percentile" `Quick test_percentile
        ; Alcotest.test_case "median" `Quick test_median
        ] )
    ; ( "influx"
      , [ Alcotest.test_case "escaping" `Quick test_escaping
        ; Alcotest.test_case "non-finite fields" `Quick test_non_finite
        ; Alcotest.test_case "string field" `Quick test_string_field
        ] )
    ]
