let setup log_json log_level =
  let stdout_log_processor =
    if log_json then Logger.Processor.raw ~log_level ()
    else
      Logger.Processor.pretty ~log_level
        ~config:
          { Interpolator_lib.Interpolator.mode = Inline
          ; max_interpolation_length = 50
          ; pretty_print = true
          }
  in
  Logger.Consumer_registry.register ~id:"default"
    ~processor:stdout_log_processor
    ~transport:(Logger.Transport.stdout ())
