open Core_kernel

include Plugins.Plugin_intf

val elapsed_time_of_thread : Thread.t -> Time_ns.Span.t
