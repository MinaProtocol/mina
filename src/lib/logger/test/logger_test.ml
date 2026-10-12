open Core

module Discard = struct
  type t = unit

  let transport () _ = ()
end

let with_temp_dir f =
  let directory = Filename.temp_dir ~in_dir:"/tmp" "coda_spun_test" "" in
  Fun.protect
    ~finally:(fun () ->
      ignore (Unix.system ("rm -rf " ^ directory) : Unix.Exit_or_signal.t) )
    (fun () -> f directory)

let test_dumb_logrotate_rotates_logs_when_expected () =
  let max_size = 1024 * 2 (* 2KB *) in
  let num_rotate = 1 in
  let logger = Logger.create () ~id:"test" in
  let log_filename = "mina.log" in
  with_temp_dir (fun directory ->
      let exists name =
        Result.is_ok (Unix.access (Filename.concat directory name) [ `Exists ])
      in
      let get_size name =
        Int64.to_int_exn (Unix.stat (Filename.concat directory name)).st_size
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
      Logger.Consumer_registry.register ~id:"test"
        ~processor:(Logger.Processor.raw ())
        ~transport:
          (Logger_file_system.dumb_logrotate ~directory ~log_filename ~max_size
             ~num_rotate )
        () ;
      run_test ~last_size:0 ~rotations:0 ~rotation_expected:false )

let test_dumb_logrotate_resumes_from_oldest () =
  let max_size = 0 in
  let num_rotate = 2 in
  let log_filename = "mina.log" in
  with_temp_dir (fun directory ->
      let path name = Filename.concat directory name in
      let write_file name contents =
        let fd =
          Unix.openfile ~perm:0o644
            ~mode:[ O_RDWR; O_CREAT; O_TRUNC ]
            (path name)
        in
        let len = String.length contents in
        ignore (Unix.write fd ~buf:(Bytes.of_string contents) ~len : int) ;
        Unix.close fd
      in
      let get_contents name = In_channel.read_all (path name) in
      write_file "mina.log.0" "oldest\n" ;
      Unix.sleep 1 ;
      write_file "mina.log.1" "newer\n" ;
      Unix.sleep 1 ;
      write_file "mina.log.2" "newest\n" ;
      write_file "mina.log" "" ;
      let logger = Logger.create () ~id:"test_resume" in
      Logger.Consumer_registry.register ~id:"test_resume"
        ~processor:(Logger.Processor.raw ())
        ~transport:
          (Logger_file_system.dumb_logrotate ~directory ~log_filename ~max_size
             ~num_rotate )
        () ;
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "first" ;
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "second" ;
      Alcotest.(check bool)
        "mina.log.0 was overwritten (oldest)" true
        (not (String.equal (get_contents "mina.log.0") "oldest\n")) ;
      Alcotest.(check string)
        "mina.log.1 was preserved (newer)" "newer\n"
        (get_contents "mina.log.1") ;
      Alcotest.(check string)
        "mina.log.2 was preserved (newest)" "newest\n"
        (get_contents "mina.log.2") )

(* the consumer registry is global and keyed by id, so each case registers
   under its own id to stay independent of the others *)
let register_at ~id ~processor =
  Logger.Consumer_registry.register ~id ~processor
    ~transport:(Logger.Transport.create (module Discard) ())
    ()

let test_would_log_follows_the_consumer_level () =
  let id = "would_log_level" in
  register_at ~id ~processor:(Logger.Processor.raw ~log_level:Info ()) ;
  let logger = Logger.create ~id () in
  Alcotest.(check bool)
    "below the consumer's level" false
    (Logger.would_log logger Logger.Level.Trace) ;
  Alcotest.(check bool)
    "at the consumer's level" true
    (Logger.would_log logger Logger.Level.Info) ;
  Alcotest.(check bool)
    "above the consumer's level" true
    (Logger.would_log logger Logger.Level.Error)

let test_would_log_takes_the_most_permissive_consumer () =
  let id = "would_log_many" in
  register_at ~id ~processor:(Logger.Processor.raw ~log_level:Error ()) ;
  register_at ~id ~processor:(Logger.Processor.raw ~log_level:Debug ()) ;
  let logger = Logger.create ~id () in
  Alcotest.(check bool)
    "a message one consumer would emit" true
    (Logger.would_log logger Logger.Level.Debug) ;
  Alcotest.(check bool)
    "a message no consumer would emit" false
    (Logger.would_log logger Logger.Level.Trace)

let test_would_log_allows_structured_event_consumers () =
  let id = "would_log_structured" in
  (* selects on event identity rather than level, so it may emit any level and
     nothing may be skipped on its account *)
  register_at ~id
    ~processor:
      (Logger.Processor.raw_structured_log_events
         Structured_log_events.Set.empty ) ;
  let logger = Logger.create ~id () in
  Alcotest.(check bool)
    "the lowest level is still possible" true
    (Logger.would_log logger Logger.Level.Trace)

(* the shape internal tracing has: it emits one level rather than everything
   from some level upwards, so a lower bound could not describe it *)
module Only_internal = struct
  type t = unit

  let accepts () level = Logger.Level.equal level Logger.Level.Internal

  let process () (_ : Logger.Message.t) = None
end

let test_would_log_respects_a_single_level_consumer () =
  let id = "would_log_single_level" in
  register_at ~id ~processor:(Logger.Processor.raw ~log_level:Info ()) ;
  register_at ~id ~processor:(Logger.Processor.create (module Only_internal) ()) ;
  let logger = Logger.create ~id () in
  Alcotest.(check bool)
    "the level it does emit" true
    (Logger.would_log logger Logger.Level.Internal) ;
  Alcotest.(check bool)
    "a level neither consumer emits" false
    (Logger.would_log logger Logger.Level.Trace)

let test_would_log_is_false_for_a_null_logger () =
  Alcotest.(check bool)
    "a null logger emits nothing" false
    (Logger.would_log (Logger.null ()) Logger.Level.Fatal)

let () =
  let open Alcotest in
  run "Logger"
    [ ( "dumb_logrotate"
      , [ test_case "rotates logs when expected" `Quick
            test_dumb_logrotate_rotates_logs_when_expected
        ; test_case "resumes rotation from oldest log" `Quick
            test_dumb_logrotate_resumes_from_oldest
        ] )
    ; ( "would_log"
      , [ test_case "follows the consumer's level" `Quick
            test_would_log_follows_the_consumer_level
        ; test_case "takes the most permissive consumer" `Quick
            test_would_log_takes_the_most_permissive_consumer
        ; test_case "allows structured event consumers" `Quick
            test_would_log_allows_structured_event_consumers
        ; test_case "respects a single-level consumer" `Quick
            test_would_log_respects_a_single_level_consumer
        ; test_case "is false for a null logger" `Quick
            test_would_log_is_false_for_a_null_logger
        ] )
    ]
