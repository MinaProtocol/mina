open Core
open Test_log

type format = Junit | Buildkite

let format_arg =
  Command.Arg_type.create (fun format ->
      let lowercase_format = String.lowercase format in
      match String.lowercase format with
      | "junit" ->
          Junit
      | "buildkite" ->
          Buildkite
      | _ ->
          eprintf "Invalid format: %s" lowercase_format ;
          exit 1 )

let generate_test_result =
  Command.basic
    ~summary:
      "Generates test report compatible with buildkite test analysis JSON \
       format"
    Command.Let_syntax.(
      let%map_open log_file =
        flag "--log-file" ~aliases:[ "-l" ] (required string)
          ~doc:"input log file from test execution"
      and output_file =
        flag "--output-file" ~aliases:[ "-o" ] (required string)
          ~doc:"output report file"
      and format =
        flag "--format" ~aliases:[ "-f" ] (required format_arg)
          ~doc:"output format type (Junit|Buildkite)"
      in
      fun () ->
        let logger = Logger.create () in
        [%log info] "Processing log file: %s" log_file ;
        let test_log = TestLogInfo.from_logs ~logger ~log_file in
        match format with
        | Junit ->
            Junit_result.write_to_xml ~test_log ~output_file
        | Buildkite ->
            Buildkite_result.write_to_json ~test_log ~output_file)
