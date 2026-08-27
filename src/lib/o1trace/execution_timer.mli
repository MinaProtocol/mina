open Core

include Plugins.Plugin_intf

val elapsed_time_of_thread : O1thread.t -> Time_ns.Span.t
