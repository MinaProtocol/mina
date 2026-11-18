open Core_kernel

let metric_name = "Coda_Transition_frontier_proposed_protocol_version_blocks"

(* The samples that a scrape would report, as (version label, value) *)
let scrape () =
  let snapshot = Prometheus.CollectorRegistry.(collect default) in
  let samples =
    Prometheus.MetricFamilyMap.fold
      (fun (info : Prometheus.MetricInfo.t) samples acc ->
        if String.equal (info.name :> string) metric_name then Some samples
        else acc )
      snapshot None
    |> Option.value_exn ~message:"metric is not registered"
  in
  Prometheus.LabelSetMap.fold
    (fun labels sample_set acc ->
      match (labels, sample_set) with
      | [ version ], [ { Prometheus.Sample_set.value; _ } ] ->
          (version, Float.to_int value) :: acc
      | _ ->
          failwith "expected one label and one sample per series" )
    samples []
  |> List.sort ~compare:[%compare: string * int]

let check_scrape ~versions ~expected () =
  Mina_metrics.Transition_frontier.update_proposed_protocol_versions versions ;
  Alcotest.(check (list (pair string int)))
    "scraped series" expected (scrape ())

let repeat n version = List.init n ~f:(fun _ -> version)

let test_below_cap =
  check_scrape
    ~versions:[ Some "4.0.1"; None; None ]
    ~expected:[ ("4.0.1", 1); ("none", 2) ]

let test_above_cap () =
  (* 4.0.2 and 4.0.3 tie for third place; the tie goes to the smaller label *)
  check_scrape
    ~versions:
      ( repeat 5 None @ repeat 4 (Some "4.0.1") @ repeat 2 (Some "4.0.2")
      @ repeat 2 (Some "4.0.3") @ repeat 1 (Some "9.9.9") )
    ~expected:[ ("4.0.1", 4); ("4.0.2", 2); ("none", 5); ("other", 3) ]
    ()

let test_dropped_versions_are_not_reported () =
  check_scrape
    ~versions:[ Some "1.0.0"; Some "2.0.0"; Some "3.0.0"; Some "4.0.0"; None ]
    ~expected:[ ("1.0.0", 1); ("2.0.0", 1); ("3.0.0", 1); ("other", 2) ]
    () ;
  check_scrape ~versions:(repeat 3 (Some "4.0.1")) ~expected:[ ("4.0.1", 3) ] ()

let test_no_blocks = check_scrape ~versions:[] ~expected:[]

let () =
  Alcotest.run "Mina_metrics"
    [ ( "proposed protocol versions"
      , [ Alcotest.test_case "below the label cap" `Quick test_below_cap
        ; Alcotest.test_case "above the label cap" `Quick test_above_cap
        ; Alcotest.test_case "versions that drop out are not reported" `Quick
            test_dropped_versions_are_not_reported
        ; Alcotest.test_case "no blocks" `Quick test_no_blocks
        ] )
    ]
