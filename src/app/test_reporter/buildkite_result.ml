open Test_log
open Core

module Outcome = struct
  type t = Passed | Failed | Skipped | Unknown
  [@@deriving sexp, equal, compare, show { with_path = false }, enumerate]

  let to_yojson t = `String (show t)

  let of_string str =
    try Ok (t_of_sexp (Sexp.Atom str))
    with Sexp.Of_sexp_error (err, _) -> Error (Exn.to_string err)

  let of_test_result test_result =
    match test_result with
    | TestResult.Passed ->
        Passed
    | TestResult.Failed ->
        Failed
    | TestResult.Skipped ->
        Skipped
end

module Section = struct
  type t = Http | Sql | Sleep | Annotation
  [@@deriving sexp, equal, compare, show { with_path = false }, enumerate]

  let to_yojson t = `String (show t)
end

module HttpMethod = struct
  type t =
    | GET
    | POST
    | PUT
    | DELETE
    | PATCH
    | HEAD
    | CONNECT
    | OPTIONS
    | TRACE
  [@@deriving sexp, equal, compare, show { with_path = false }, enumerate]

  let to_yojson t = `String (show t)
end

module BuildkiteTestResult = struct
  type detail_t =
    { m : HttpMethod.t option [@default None] [@key "method"]
    ; url : string option
    ; lib : string option
    ; query : string option
    }
  [@@deriving to_yojson]

  type span_t =
    { section : Section.t
    ; start_at : float
    ; end_at : float
    ; duration : float option
    ; detail : detail_t option
    }
  [@@deriving to_yojson]

  type history_t =
    { start_at : float
    ; end_at : float option
    ; duration : float
    ; children : span_t list option
    }
  [@@deriving to_yojson]

  type test_result =
    { id : string option
    ; scope : string option
    ; name : string option
    ; identifier : string
    ; file_name : string option
    ; result : Outcome.t option
    ; failure_reason : string option
    ; failure_expanded : string list option
    ; history : history_t list
    }
  [@@deriving to_yojson]

  let from_test_log ~(test_log : TestLogInfo.t) =
    let history =
      List.map test_log.perf_measurements
        ~f:(fun (measurement : PerfMeasurement.t) ->
          { start_at = measurement.start
          ; end_at = Some (measurement.start +. measurement.duration)
          ; duration = measurement.duration
          ; children =
              Some
                [ { section = Section.Annotation
                  ; start_at = measurement.start
                  ; end_at = measurement.start +. measurement.duration
                  ; duration = Some measurement.duration
                  ; detail =
                      Some
                        { m = None
                        ; url = None
                        ; lib = Some measurement.name
                        ; query = None
                        }
                  }
                ]
          } )
    in
    let identifier =
      match test_log.test_name with Some name -> name | None -> "undefined"
    in
    { id = None
    ; scope = Some "Test executive integration test"
    ; name = test_log.test_name
    ; identifier
    ; file_name = Some "src/app/test_executive/test_executive.ml"
    ; result = Some (Outcome.of_test_result test_log.test_result)
    ; failure_reason = test_log.failure_reason
    ; failure_expanded = TestLogInfo.get_maybe_failure_expanded test_log
    ; history
    }

  let write_to_json t ~output_file =
    Out_channel.with_file ~fail_if_exists:true output_file ~f:(fun ch ->
        test_result_to_yojson t |> Yojson.Safe.pretty_to_string
        |> Out_channel.output_string ch )
end

let write_to_json ~(test_log : TestLogInfo.t) ~output_file =
  BuildkiteTestResult.from_test_log ~test_log
  |> BuildkiteTestResult.write_to_json ~output_file
