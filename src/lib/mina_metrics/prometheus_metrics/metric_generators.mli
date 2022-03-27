module type Metric_spec_intf = sig
  val subsystem : string

  val name : string

  val help : string
end

module type Bucketed_average_spec_intf = sig
  val subsystem : string

  val name : string

  val help : string

  val bucket_interval : Core.Time.Span.t

  val num_buckets : int

  val render_average : (float * int) list -> float
end

module type Time_average_spec_intf = sig
  val subsystem : string

  val name : string

  val help : string

  val tick_interval : Core.Time.Span.t

  val rolling_interval : Core.Time.Span.t
end

module type Moving_average_metric_intf = sig
  type datum

  val v : Prometheus.Gauge.t

  val update : datum -> unit

  val clear : unit -> unit
end

module Moving_bucketed_average : functor
  (Spec : Bucketed_average_spec_intf)
  ()
  -> sig
  val v : Prometheus.Gauge.t

  val update : float -> unit

  val clear : unit -> unit
end

module Moving_time_average : functor (Spec : Time_average_spec_intf) () -> sig
  val v : Prometheus.Gauge.t

  val update : Core.Time.Span.t -> unit

  val clear : unit -> unit
end
