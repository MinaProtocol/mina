open Core_kernel
open Async_kernel
open Prometheus

module type Metric_spec_intf = sig
  val subsystem : string

  val name : string

  val help : string
end

module type Bucketed_average_spec_intf = sig
  include Metric_spec_intf

  val bucket_interval : Time.Span.t -> Time.Span.t

  val num_buckets : Time.Span.t -> int

  val render_average : (float * int) list -> float
end

module Intervals = struct
  type t = { rolling : Time.Span.t; tick : Time.Span.t }

  let make ~rolling_interval ~tick_interval =
    let open Time.Span in
    let ( = ) = Float.equal in
    let ( mod ) = Float.mod_float in
    if not (to_ns rolling_interval mod to_ns tick_interval = 0.0) then
      failwith
        "invalid intervals provided to Moving_time_average -- the \
         tick_interval does not evenly divide the rolling_interval"
    else { rolling = rolling_interval; tick = tick_interval }
end

module type Time_average_spec_intf = sig
  include Metric_spec_intf

  val intervals : Time.Span.t -> Intervals.t
end

module type Moving_average_metric_intf = sig
  type datum

  val update : datum -> unit

  val clear : unit -> unit

  val v : Gauge.t

  val initialize : Time.Span.t -> unit
end

module Moving_bucketed_average (Spec : Bucketed_average_spec_intf) :
  Moving_average_metric_intf with type datum := float = struct
  open Spec

  let empty_bucket_entry = (0.0, 0)

  let buckets = ref None

  let clear () =
    buckets :=
      Option.map ~f:(List.map ~f:(Fn.const empty_bucket_entry)) !buckets

  let update datum =
    match !buckets with
    | None ->
        ()
    | Some [] ->
        failwith "Moving_bucketed_average buckets are malformed"
    | Some ((value, num_entries) :: t) ->
        buckets := Some ((value +. datum, num_entries + 1) :: t)

  let v = Gauge.v name ~subsystem ~namespace:Namespace.namespace ~help

  let initialize block_window_duration =
    let rec tick () =
      upon
        (after
           ( Time_ns.Span.of_ns @@ Time.Span.to_ns
           @@ bucket_interval block_window_duration ) )
        (fun () ->
          let num_buckets = num_buckets block_window_duration in
          if Option.is_none !buckets then
            buckets :=
              Some (List.init num_buckets ~f:(Fn.const empty_bucket_entry)) ;
          let buckets_val = Option.value_exn !buckets in
          Gauge.set v (render_average buckets_val) ;
          buckets :=
            Some (empty_bucket_entry :: List.take buckets_val (num_buckets - 1)) ;
          tick () )
    in
    tick ()
end

module Moving_time_average (Spec : Time_average_spec_intf) :
  Moving_average_metric_intf with type datum := Time.Span.t = struct
  include Moving_bucketed_average (struct
    include Spec

    let bucket_interval block_window_duration =
      (Spec.intervals block_window_duration).rolling

    let num_buckets block_window_duration =
      let intervals = Spec.intervals block_window_duration in
      Float.to_int
        (Time.Span.to_ns intervals.rolling /. Time.Span.to_ns intervals.tick)

    let render_average buckets =
      let total_sum, count_sum =
        List.fold buckets ~init:(0.0, 0)
          ~f:(fun (total_sum, count_sum) (total, count) ->
            (total_sum +. total, count_sum + count) )
      in
      total_sum /. Float.of_int count_sum
  end)

  let update span = update (Time.Span.to_sec span)
end
