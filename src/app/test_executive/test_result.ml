open Core
open Async
open Integration_test_lib
open Test_error
open Test_error.Set

module Test_Result_Evaluator = struct
  type t =
    { log_error_set :
        Integration_test_lib.Test_error.remote_error
        Integration_test_lib.Test_error.Set.t
    ; internal_error_set :
        Integration_test_lib.Test_error.internal_error
        Integration_test_lib.Test_error.Set.t
    }

  let max_sev a b =
    match (a, b) with
    | `Hard, _ | _, `Hard ->
        `Hard
    | `Soft, _ | _, `Soft ->
        `Soft
    | _ ->
        `None

  let max_severity_of_list severities =
    List.fold severities ~init:`None ~f:max_sev

  let combine_errors error_set =
    Error_accumulator.combine
      [ Error_accumulator.map error_set.soft_errors ~f:(fun err -> (`Soft, err))
      ; Error_accumulator.map error_set.hard_errors ~f:(fun err -> (`Hard, err))
      ]

  let internal_errors t = combine_errors t.internal_error_set

  let internal_errors_severity t = max_severity t.internal_error_set

  let log_errors t = combine_errors t.log_error_set

  let log_errors_severity t = max_severity t.log_error_set

  let test_failed t =
    match (log_errors_severity t, internal_errors_severity t) with
    | _, `Hard | _, `Soft ->
        true
    (* TODO: re-enable log error checks after libp2p logs are cleaned up *)
    | `Hard, _ | `Soft, _ | `None, `None ->
        false

  let exit_code t =
    match (t.internal_error_set.exit_code, t.log_error_set.exit_code) with
    | None, None ->
        1
    | Some exit_code, _ | None, Some exit_code ->
        exit_code
end

let failure_text = "The test has failed. See the above errors for details"

let success_text = "The test has completed successfully"

let printout_test_result (test_eval : Test_Result_Evaluator.t) =
  (* TODO: we should be able to show which sections passed as well *)
  let open Test_error in
  let color_eprintf color =
    Printf.ksprintf (fun s -> Print.eprintf "%s%s%s" color s Bash_colors.none)
  in
  let color_of_severity = function
    | `None ->
        Bash_colors.green
    | `Soft ->
        Bash_colors.yellow
    | `Hard ->
        Bash_colors.red
  in
  let category_prefix_of_severity = function
    | `None ->
        "✓"
    | `Soft ->
        "-"
    | `Hard ->
        "×"
  in
  let print_category_header severity =
    Printf.ksprintf
      (color_eprintf
         (color_of_severity severity)
         "%s %s\n"
         (category_prefix_of_severity severity) )
  in
  let report_log_errors log_type =
    color_eprintf
      (color_of_severity (Test_Result_Evaluator.log_errors_severity test_eval))
      "=== Log %ss ===\n" log_type ;
    Test_Result_Evaluator.log_errors test_eval
    |> Error_accumulator.iter_contexts ~f:(fun node_id log_errors ->
           color_eprintf Bash_colors.light_magenta "    %s:\n" node_id ;
           List.iter log_errors ~f:(fun (severity, { error_message; _ }) ->
               color_eprintf
                 (color_of_severity severity)
                 "        [%s] %s\n"
                 (Time.to_string error_message.timestamp)
                 (Yojson.Safe.to_string
                    (Logger.Message.to_yojson error_message) ) ) ;
           Print.eprintf "\n" )
  in
  (* check invariants *)
  match (Test_Result_Evaluator.log_errors test_eval).from_current_context with
  | _ :: _ ->
      failwith "all error logs should be contextualized by node id"
  | [] ->
      (* report log errors *)
      Print.eprintf "\n" ;
      ( match Test_Result_Evaluator.log_errors_severity test_eval with
      | `None ->
          ()
      | `Soft ->
          report_log_errors "Warning"
      | `Hard ->
          report_log_errors "Error" ) ;
      (* report contextualized internal errors *)
      color_eprintf Bash_colors.magenta "=== Test Results ===\n" ;
      Test_Result_Evaluator.internal_errors test_eval
      |> Error_accumulator.iter_contexts ~f:(fun context errors ->
             print_category_header
               (Test_Result_Evaluator.max_severity_of_list
                  (List.map errors ~f:fst) )
               "%s" context ;
             List.iter errors ~f:(fun (severity, { occurrence_time; error }) ->
                 color_eprintf
                   (color_of_severity severity)
                   "    [%s] %s\n"
                   (Time.to_string occurrence_time)
                   (Error.to_string_hum error) ) ) ;
      (* report non-contextualized internal errors *)
      List.iter
        (Test_Result_Evaluator.internal_errors test_eval).from_current_context
        ~f:(fun (severity, { occurrence_time; error }) ->
          color_eprintf
            (color_of_severity severity)
            "[%s] %s\n"
            (Time.to_string occurrence_time)
            (Error.to_string_hum error) ) ;
      (* determine if test is passed/failed and exit accordingly *)
      Print.eprintf "\n" ;
      if Test_Result_Evaluator.test_failed test_eval then
        color_eprintf Bash_colors.red "%s\n\n" failure_text
      else color_eprintf Bash_colors.green "%s\n\n" success_text ;
      Writer.(flushed (Lazy.force stderr))

let write_test_result_to_log ~test_eval ~logger =
  let severity_to_string severity =
    match severity with `None -> "Ok" | `Soft -> "Warning" | `Hard -> "Error"
  in
  [%log span] "Test result generation $event"
    ~metadata:[ ("event", `String "start") ] ;
  let report_log_errors log_type =
    [%log span] "Node logs analysis $event for "
      ~metadata:[ ("event", `String "start"); ("severity", `String log_type) ] ;
    Test_Result_Evaluator.log_errors test_eval
    |> Error_accumulator.iter_contexts ~f:(fun node_id log_errors ->
           List.iter log_errors ~f:(fun (severity, { error_message; _ }) ->
               [%log error] "Incident found: $message"
                 ~metadata:
                   [ ("time", `String (Time.to_string error_message.timestamp))
                   ; ("node_is", `String node_id)
                   ; ("severity", `String (severity_to_string severity))
                   ; ( "message"
                     , `String
                         (Yojson.Safe.to_string
                            (Logger.Message.to_yojson error_message) ) )
                   ] ) )
  in
  ( match Test_Result_Evaluator.log_errors_severity test_eval with
  | `None ->
      ()
  | `Soft ->
      report_log_errors "Warning"
  | `Hard ->
      report_log_errors "Error" ) ;
  [%log span] "Node logs analysis $event"
    ~metadata:[ ("event", `String "finish") ] ;
  [%log span] "Test result analysis $event"
    ~metadata:[ ("event", `String "start") ] ;
  [%log span] "Contextualized result analysis $event"
    ~metadata:[ ("event", `String "start") ] ;
  Test_Result_Evaluator.internal_errors test_eval
  |> Error_accumulator.iter_contexts ~f:(fun context errors ->
         [%log span] "Analysis for context: $context"
           ~metadata:
             [ ("event", `String "start"); ("context", `String context) ] ;
         List.iter errors ~f:(fun (severity, { occurrence_time; error }) ->
             [%log error] "Contextualized Incident found"
               ~metadata:
                 [ ("time", `String (Time.to_string occurrence_time))
                 ; ("severity", `String (severity_to_string severity))
                 ; ("message", `String (Error.to_string_hum error))
                 ] ) ;
         [%log span] "Analysis for context: $context"
           ~metadata:
             [ ("event", `String "finish"); ("context", `String context) ] ) ;
  [%log span] "Contextualized result analysis $event"
    ~metadata:[ ("event", `String "finish") ] ;
  [%log span] "Non-Contextualized result analysis $event"
    ~metadata:[ ("event", `String "start") ] ;
  List.iter
    (Test_Result_Evaluator.internal_errors test_eval).from_current_context
    ~f:(fun (severity, { occurrence_time; error }) ->
      [%log error] "Non-Contextualized Incident found: $message"
        ~metadata:
          [ ("time", `String (Time.to_string occurrence_time))
          ; ("severity", `String (severity_to_string severity))
          ; ("message", `String (Error.to_string_hum error))
          ] ) ;
  [%log span] "Non-Contextualized result analysis $event"
    ~metadata:[ ("event", `String "finish") ] ;
  if Test_Result_Evaluator.test_failed test_eval then (
    [%log fatal] "Test Result: $result. $failure_text"
      ~metadata:
        [ ("result", `String "failed"); ("failure_text", `String failure_text) ] ;
    [%log fatal] "Exit Code: $exit_code."
      ~metadata:
        [ ("exit_code", `Int (Test_Result_Evaluator.exit_code test_eval)) ] )
  else
    [%log fatal] "Test Result: $result. $success_text"
      ~metadata:
        [ ("result", `String "passed"); ("success_text", `String success_text) ] ;
  [%log span] "Test result generation $event"
    ~metadata:[ ("event", `String "finish") ]

let calculate_test_result ~log_error_set ~internal_error_set ~logger =
  let test_eval : Test_Result_Evaluator.t =
    { log_error_set; internal_error_set }
  in
  let exit_code =
    if Test_Result_Evaluator.test_failed test_eval then
      Some (Test_Result_Evaluator.exit_code test_eval)
    else None
  in
  let () = write_test_result_to_log ~test_eval ~logger in
  let%bind () = printout_test_result test_eval in
  return exit_code
