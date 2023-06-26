open Core
module CoverageFiles = Map.Make (String)

module PerfMeasurement = struct
  type t = { name : string; start : float; duration : float }
end

module TestResult = struct
  type t = Passed | Failed | Skipped
  [@@deriving sexp, equal, compare, show { with_path = false }, enumerate]

  let to_yojson t = `String (show t)

  let of_string str =
    try Ok (t_of_sexp (Sexp.Atom str))
    with Sexp.Of_sexp_error (err, _) -> Error (Exn.to_string err)
end

module TestLogInfo = struct
  type t =
    { mutable testnet_name : string option
    ; mutable test_name : string option
    ; mutable mina_image : string option
    ; mutable coverage_files : string list
    ; mutable perf_measurements : PerfMeasurement.t list
    ; mutable test_result : TestResult.t
    ; mutable test_start : float
    ; mutable test_end : float
    ; mutable failure_reason : string option
    ; mutable failure_expanded : string list
    }

  let get_metadata_key_or_fail metadata key =
    match Map.find_exn metadata key with
    | `String p ->
        p
    | _ ->
        failwith (Printf.sprintf "Expected '%s' key in metadata " key)

  let get_maybe_failure_expanded t =
    if List.length t.failure_expanded > 0 then Some t.failure_expanded else None

  let empty =
    { testnet_name = None
    ; test_name = None
    ; mina_image = None
    ; coverage_files = []
    ; perf_measurements = []
    ; test_result = TestResult.Skipped
    ; failure_reason = None
    ; failure_expanded = []
    ; test_start = 0.0
    ; test_end = 0.0
    }

  let from_logs ~logger ~log_file =
    let coverage_manager_ref : t ref = ref empty in
    let log_lines = In_channel.read_lines log_file in
    List.iter log_lines ~f:(fun line ->
        let json = Yojson.Safe.from_string line in
        let msg = Logger.Message.of_yojson json in
        match msg with
        | Ok msg ->
            if
              String.is_substring msg.message
                ~substring:"Coverage files downloaded"
            then
              let coverage_files_metadata =
                get_metadata_key_or_fail msg.metadata "files"
              in
              !coverage_manager_ref.coverage_files <-
                String.split ~on:',' coverage_files_metadata
            else if String.is_substring msg.message ~substring:"Running test"
            then (
              let testnet_name =
                get_metadata_key_or_fail msg.metadata "testnet_name"
              in
              let test_name =
                get_metadata_key_or_fail msg.metadata "test_name"
              in
              let mina_image = get_metadata_key_or_fail msg.metadata "image" in
              !coverage_manager_ref.testnet_name <- Some testnet_name ;
              !coverage_manager_ref.test_name <- Some test_name ;
              !coverage_manager_ref.mina_image <- Some mina_image )
            else if
              String.is_substring msg.message
                ~substring:"Contextualized Incident found"
            then
              !coverage_manager_ref.failure_expanded <-
                !coverage_manager_ref.failure_expanded
                @ [ get_metadata_key_or_fail msg.metadata "message" ]
            else if String.is_substring msg.message ~substring:"Test Result:"
            then
              let result_str = get_metadata_key_or_fail msg.metadata "result" in
              let result =
                match TestResult.of_string result_str with
                | Ok test_result -> (
                    match test_result with
                    | TestResult.Failed ->
                        let failure_text =
                          get_metadata_key_or_fail msg.metadata "failure_text"
                        in
                        !coverage_manager_ref.failure_reason <-
                          Some failure_text ;
                        test_result
                    | _ ->
                        test_result )
                | Error _ ->
                    [%log warn]
                      "cannot determine test result.. set Skipped by default" ;
                    TestResult.Skipped
              in
              !coverage_manager_ref.test_result <- result
            else if
              String.is_substring msg.message
                ~substring:"Performance measurement"
            then
              let description =
                get_metadata_key_or_fail msg.metadata "description"
              in
              let soft_timeout =
                get_metadata_key_or_fail msg.metadata "soft_timeout"
              in
              let hard_timeout =
                get_metadata_key_or_fail msg.metadata "hard_timeout"
              in
              let name =
                Printf.sprintf "%s with timeouts (%s/%s)" description
                  soft_timeout hard_timeout
              in
              let duration = get_metadata_key_or_fail msg.metadata "duration" in
              let start = get_metadata_key_or_fail msg.metadata "start" in
              !coverage_manager_ref.perf_measurements <-
                !coverage_manager_ref.perf_measurements
                @ [ { name
                    ; start = float_of_string start
                    ; duration = float_of_string duration
                    }
                  ]
            else ()
        | Error str ->
            [%log error] "%s" str ) ;
    !coverage_manager_ref
end
