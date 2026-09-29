open Core

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

(* a fixed timestamp, so a rendered record can be compared in full *)
let message ?(level = Logger.Level.Info) ?(metadata = []) text =
  { Logger.Message.timestamp = Logger.Time.epoch
  ; level
  ; source = Some (Logger.Source.create ~module_:__MODULE__ ~location:__LOC__)
  ; message = text
  ; metadata = String.Map.of_alist_exn metadata
  ; event_id = None
  }

(* renders one message through a pretty consumer of its own and returns what
   the transport was handed *)
let pretty_render ~id ?(mode = Interpolator_lib.Interpolator.Inline) msg =
  let emitted = ref None in
  Logger.Consumer_registry.register ~id
    ~processor:
      (Logger.Processor.pretty ~log_level:Logger.Level.Spam
         ~config:
           { Interpolator_lib.Interpolator.mode
           ; max_interpolation_length = 50
           ; pretty_print = true
           } )
    ~transport:(Logger.Transport.raw (fun line -> emitted := Some line))
    () ;
  Logger.raw (Logger.create ~id ()) msg ;
  Option.value_exn !emitted ~message:"the pretty processor emitted nothing"

let test_pretty_renders_a_record_without_metadata_on_one_line () =
  Alcotest.(check string)
    "no trailing line"
    "1970-01-01 00:00:00 UTC [Error] block get: one of --index or --hash is \
     required"
    (pretty_render ~id:"pretty_no_metadata"
       (message ~level:Logger.Level.Error
          "block get: one of --index or --hash is required" ) )

let test_pretty_renders_interpolated_metadata_on_one_line () =
  Alcotest.(check string)
    "no trailing line" {|1970-01-01 00:00:00 UTC [Info] connected to "1.2.3.4"|}
    (pretty_render ~id:"pretty_interpolated"
       (message ~metadata:[ ("peer", `String "1.2.3.4") ] "connected to $peer") )

let test_pretty_keeps_metadata_left_over_by_interpolation () =
  Alcotest.(check string)
    "each leftover key on its own indented line"
    "1970-01-01 00:00:00 UTC [Info] rotated\n  count: 2\n  reason: \"size\""
    (pretty_render ~id:"pretty_extra" ~mode:Interpolator_lib.Interpolator.After
       (message
          ~metadata:[ ("count", `Int 2); ("reason", `String "size") ]
          "rotated" ) )

let () =
  let open Alcotest in
  run "Logger"
    [ ( "dumb_logrotate"
      , [ test_case "rotates logs when expected" `Quick
            test_dumb_logrotate_rotates_logs_when_expected
        ; test_case "resumes rotation from oldest log" `Quick
            test_dumb_logrotate_resumes_from_oldest
        ] )
    ; ( "pretty"
      , [ test_case "renders a record without metadata on one line" `Quick
            test_pretty_renders_a_record_without_metadata_on_one_line
        ; test_case "renders interpolated metadata on one line" `Quick
            test_pretty_renders_interpolated_metadata_on_one_line
        ; test_case "keeps metadata left over by interpolation" `Quick
            test_pretty_keeps_metadata_left_over_by_interpolation
        ] )
    ]
