val t : Histogram.Exp_time_spans.t Core_kernel.String.Table.t

val add_span :
  name:Core_kernel.String.Table.key -> Core_kernel.Time.Span.t -> unit

val report :
  name:Core_kernel.String.Table.key -> Histogram.Exp_time_spans.Pretty.t option

val wipe : unit -> unit
