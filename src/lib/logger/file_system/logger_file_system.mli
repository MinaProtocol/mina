(** Timestamped_logrotate is a Transport which persists logs to the file system
    using timestamp-suffixed log files (e.g. mina.log.2024-01-15T10:30:00Z).
    When the primary log exceeds max size, it is rotated to a timestamped file
    and the oldest rotated files beyond `num_rotate` are deleted.
*)
val timestamped_logrotate :
     directory:string
  -> log_filename:string
  -> max_size:int
  -> num_rotate:int
  -> Logger.Transport.t

val evergrowing : log_filename:string -> Logger.Transport.t

(** Pretty printer for time, in "%Y-%m-%d %H:%M:%S UTC" format.

    On linking this library, this is used to override the JS-safe
    implementation given in [Logger.Time.pretty_to_string].
*)
val time_pretty_to_string : Core.Time.t -> string
