open Core
open Test_log

let build_report (log_info : TestLogInfo.t) =
  let test_name =
    match log_info.test_name with
    | Some test_name ->
        test_name
    | None ->
        failwith "cannot find test name in log file"
  in
  let suite =
    let properties =
      [ Junit.Property.make ~name:"test.name" ~value:test_name
      ; Junit.Property.make ~name:"testnet.name"
          ~value:(Option.value ~default:"unknown" log_info.testnet_name)
      ; Junit.Property.make ~name:"mina.image"
          ~value:(Option.value ~default:"unknown" log_info.mina_image)
      ; Junit.Property.make ~name:"coverage.files"
          ~value:(String.concat ~sep:"," log_info.coverage_files)
      ]
    in
    let classname = sprintf "Test_executive.%s_test" test_name in
    let testcase =
      match log_info.test_result with
      | Passed ->
          Junit.Testcase.pass ~name:test_name ~classname
            ~time:(log_info.test_end -. log_info.test_start)
      | Failed ->
          let message =
            Option.value log_info.failure_reason ~default:"no message"
          in
          Junit.Testcase.failure ~name:test_name ~classname
            ~time:(log_info.test_end -. log_info.test_start)
            ~message ~typ:"Test Failure"
            (String.concat ~sep:"\n" log_info.failure_expanded)
      | Skipped ->
          Junit.Testcase.skipped ~name:test_name ~classname
            ~time:(log_info.test_end -. log_info.test_start)
    in

    let timestamp =
      match Ptime.of_date_time ((2013, 5, 24), ((10, 23, 58), 0)) with
      | Some t ->
          t
      | None ->
          assert false
    in
    Junit.Testsuite.make ~timestamp ~name:test_name ()
    |> Junit.Testsuite.add_testcases [ testcase ]
    |> Junit.Testsuite.add_properties properties
  in
  Junit.make [ suite ]

let write_to_xml ~(test_log : TestLogInfo.t) ~output_file =
  let report = build_report test_log in
  Junit.to_file report output_file
