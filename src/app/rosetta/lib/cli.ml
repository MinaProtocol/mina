open Core_kernel

let required_uri =
  Command.Param.(required (Command.Arg_type.map string ~f:Uri.of_string))

let log_level =
  let open Command.Param in
  optional_with_default Logger.Level.Info
    (Command.Arg_type.map string ~f:(fun log_level_str_with_case ->
         let open Logger in
         let log_level_str = String.lowercase log_level_str_with_case in
         match Level.of_string log_level_str with
         | Error _ ->
             (* eprintf "Received unknown log-level %s. Expected one of: %s\n" *)
             (*   log_level_str *)
             (*   ( Level.all |> List.map ~f:Level.show *)
             (*   |> List.map ~f:String.lowercase *)
             (*   |> String.concat ~sep:", " ) ; *)
             failwith "test"
         | Ok ll ->
             ll ))

let logger_setup log_json log_level =
  let stdout_log_processor =
    if log_json then Logger.Processor.raw ~log_level ()
    else
      Logger.Processor.pretty ~log_level
        ~config:
          { Logproc_lib.Interpolator.mode= Inline
          ; max_interpolation_length= 50
          ; pretty_print= true }
  in
  Logger.Consumer_registry.register ~id:"default"
    ~processor:stdout_log_processor
    ~transport:(Logger.Transport.stdout ())
