open Core
module Logger = Impl

let%test_unit "Logger.Dumb_logrotate rotates logs when expected" =
  let max_size = 1024 * 2 (* 2KB *) in
  let logger = Logger.create () ~id:"test" in
  let directory = Filename.temp_dir ~in_dir:"/tmp" "coda_spun_test" "" in
  let log_name = "coda.log" in
  let exists name =
    Result.is_ok (Unix.access (Filename.concat directory name) [`Exists])
  in
  let get_size name =
    Int64.to_int_exn (Unix.stat (Filename.concat directory name)).st_size
  in
  let rec run_test ~last_size ~rotations ~rotation_expected =
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "test" ;
    let curr_size = get_size "coda.log" in
    if curr_size < last_size then (
      assert rotation_expected ;
      assert (exists "coda.log.0") ;
      assert (get_size "coda.log.0" = last_size) ;
      if rotations <= 2 then
        run_test ~last_size:curr_size ~rotations:(rotations + 1)
          ~rotation_expected:false )
    else (
      assert (not rotation_expected) ;
      run_test ~last_size:curr_size ~rotations
        ~rotation_expected:(curr_size >= max_size) )
  in
  try
    Logger.Consumer_registry.register ~id:"test"
      ~processor:(Logger.Processor.raw ())
      ~transport:
        (Logger.Transport.File_system.dumb_logrotate ~directory ~log_name
           ~max_size) ;
    run_test ~last_size:0 ~rotations:0 ~rotation_expected:false
  with exn ->
    ignore (Unix.system ("rm -rf " ^ directory)) ;
    raise exn
