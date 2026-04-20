open Core

let rotated_log_timestamps directory log_filename =
  let prefix = log_filename ^ "." in
  let prefix_len = String.length prefix in
  Core.Sys.readdir directory |> Array.to_list
  |> List.filter_map ~f:(fun name ->
         if String.is_prefix name ~prefix then
           Some (String.drop_prefix name prefix_len)
         else None )
  |> List.sort ~compare:String.compare

let parse_timestamp s =
  match String.lsplit2 s ~on:'Z' with
  | Some (before_z, _) ->
      Time.of_string (before_z ^ "Z")
  | None ->
      Time.of_string s

let test_timestamped_logrotate_rotates_logs_when_expected () =
  let max_size = 1024 * 2 (* 2KiB *) in
  let num_rotate = 1 in
  let logger = Logger.create () ~id:"test" in
  let directory = Filename.temp_dir ~in_dir:"/tmp" "coda_spun_test" "" in
  let log_filename = "mina.log" in
  let time_before = Time.now () in
  let get_size name =
    Int64.to_int_exn (Unix.stat (Filename.concat directory name)).st_size
  in
  let rec run_test ~last_size ~rotations ~rotation_expected =
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "test" ;
    let curr_size = get_size "mina.log" in
    if curr_size < last_size then (
      Alcotest.(check bool) "rotation expected" true rotation_expected ;
      let timestamps = rotated_log_timestamps directory log_filename in
      Alcotest.(check bool)
        "rotated log exists" true
        (List.length timestamps > 0) ;
      Alcotest.(check bool)
        "rotated count within limit" true
        (List.length timestamps <= num_rotate) ;
      let time_after = Time.now () in
      let tolerance = Time.Span.of_sec 1.0 in
      List.iter timestamps ~f:(fun ts_str ->
          let ts = parse_timestamp ts_str in
          Alcotest.(check bool)
            "timestamp not before test start" true
            (Time.( >= ) ts (Time.sub time_before tolerance)) ;
          Alcotest.(check bool)
            "timestamp not after rotation" true
            (Time.( <= ) ts (Time.add time_after tolerance)) ) ;
      if rotations <= 2 then
        run_test ~last_size:curr_size ~rotations:(rotations + 1)
          ~rotation_expected:false )
    else (
      Alcotest.(check bool) "rotation not expected" false rotation_expected ;
      run_test ~last_size:curr_size ~rotations
        ~rotation_expected:(curr_size >= max_size) )
  in
  try
    Logger.Consumer_registry.register ~id:"test"
      ~processor:(Logger.Processor.raw ())
      ~transport:
        (Logger_file_system.timestamped_logrotate ~directory ~log_filename
           ~max_size ~num_rotate )
      () ;
    run_test ~last_size:0 ~rotations:0 ~rotation_expected:false
  with exn ->
    ignore (Unix.system ("rm -rf " ^ directory) : Unix.Exit_or_signal.t) ;
    raise exn

let test_timestamped_logrotate_multiple_rotations () =
  let max_size = 512 in
  let num_rotate = 3 in
  let logger = Logger.create () ~id:"test_multi" in
  let directory = Filename.temp_dir ~in_dir:"/tmp" "coda_spun_test" "" in
  let log_filename = "mina.log" in
  let time_before = Time.now () in
  let get_size name =
    Int64.to_int_exn (Unix.stat (Filename.concat directory name)).st_size
  in
  let rec run_test ~last_size ~rotations =
    let current_rotated =
      List.length (rotated_log_timestamps directory log_filename)
    in
    if current_rotated >= num_rotate then ()
    else (
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        "padding message to fill up the log file quickly for rotation test" ;
      let curr_size = get_size "mina.log" in
      let new_rotations =
        if curr_size < last_size then rotations + 1 else rotations
      in
      run_test ~last_size:curr_size ~rotations:new_rotations )
  in
  ( try
      Logger.Consumer_registry.register ~id:"test_multi"
        ~processor:(Logger.Processor.raw ())
        ~transport:
          (Logger_file_system.timestamped_logrotate ~directory ~log_filename
             ~max_size ~num_rotate )
        () ;
      run_test ~last_size:0 ~rotations:0
    with exn ->
      ignore (Unix.system ("rm -rf " ^ directory) : Unix.Exit_or_signal.t) ;
      raise exn ) ;
  let time_after = Time.now () in
  let tolerance = Time.Span.of_sec 1.0 in
  let timestamps = rotated_log_timestamps directory log_filename in
  Alcotest.(check bool)
    "multiple rotated logs exist" true
    (List.length timestamps >= 2) ;
  Alcotest.(check bool)
    "rotated count within limit" true
    (List.length timestamps <= num_rotate) ;
  let parsed = List.map timestamps ~f:parse_timestamp in
  List.iter parsed ~f:(fun ts ->
      Alcotest.(check bool)
        "timestamp not before test start" true
        (Time.( >= ) ts (Time.sub time_before tolerance)) ;
      Alcotest.(check bool)
        "timestamp not after test end" true
        (Time.( <= ) ts (Time.add time_after tolerance)) ) ;
  let sorted = List.sort parsed ~compare:Time.compare in
  Alcotest.(check bool)
    "timestamps are in chronological order" true
    (List.equal Time.equal parsed sorted) ;
  ignore (Unix.system ("rm -rf " ^ directory) : Unix.Exit_or_signal.t)

let () =
  let open Alcotest in
  run "Logger"
    [ ( "timestamped_logrotate"
      , [ test_case "rotates logs when expected" `Quick
            test_timestamped_logrotate_rotates_logs_when_expected
        ; test_case "multiple rotations produce ordered timestamps" `Quick
            test_timestamped_logrotate_multiple_rotations
        ] )
    ]
