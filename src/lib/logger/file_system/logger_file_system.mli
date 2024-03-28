(** Dumb_logrotate is a Transport which persists logs to the file system by
    using `num_rotate` log files. This Transport will rotate these logs,
    ensuring that each log file is less than some maximum size before writing
    to it. When the logs reach max size, the old log is deleted and a new log
    is started.
*)
val dumb_logrotate :
     directory:string
  -> log_filename:string
  -> max_size:int
  -> num_rotate:int
  -> Logger.Transport.t

(** Pretty printer for time, in "%Y-%m-%d %H:%M:%S UTC" format.

    On linking this library, this is used to override the JS-safe
    implementation given in [Logger.Time.pretty_to_string].
*)
val time_pretty_to_string : Core.Time.t -> string
