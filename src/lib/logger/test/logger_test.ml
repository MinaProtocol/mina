open Core

let test_dumb_logrotate_rotates_logs_when_expected () =
  let max_size =
    1024 * 2
    (* 2KB *)
  in
  let num_rotate = 1 in
  let logger = Logger.create () ~id:"test" in
  let directory = Filename_unix.temp_dir ~in_dir:"/tmp" "coda_spun_test" "" in
  let log_filename = "mina.log" in
  let exists name =
    Result.is_ok (Core_unix.access (Filename.concat directory name) [ `Exists ])
  in
  let get_size name =
    Int64.to_int_exn (Core_unix.stat (Filename.concat directory name)).st_size
  in
  let rec run_test ~last_size ~rotations ~rotation_expected =
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "test" ;
    let curr_size = get_size "mina.log" in
    if curr_size < last_size then (
      Alcotest.(check bool) "rotation expected" true rotation_expected ;
      Alcotest.(check bool) "mina.log.0 exists" true (exists "mina.log.0") ;
      Alcotest.(check int)
        "mina.log.0 size equals last_size" last_size (get_size "mina.log.0") ;
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
        (Logger_file_system.dumb_logrotate ~directory ~log_filename ~max_size
           ~num_rotate )
      () ;
    run_test ~last_size:0 ~rotations:0 ~rotation_expected:false
  with exn ->
    ignore
      (Core_unix.system ("rm -rf " ^ directory) : Core_unix.Exit_or_signal.t) ;
    raise exn

let () =
  let open Alcotest in
  run "Logger"
    [ ( "dumb_logrotate"
      , [ test_case "rotates logs when expected" `Quick
            test_dumb_logrotate_rotates_logs_when_expected
        ] )
    ]
