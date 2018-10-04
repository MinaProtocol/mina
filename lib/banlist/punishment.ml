open Core_kernel

type t = Timeout of Time.t | Forever

let timeout_duration = Time.Span.of_day 1.0

let create_timeout () = Timeout (Time.add (Time.now ()) timeout_duration)

let evict_time = function Timeout time -> time | Forever -> failwith "TODO"
