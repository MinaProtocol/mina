open Core_kernel
open Async_kernel
open Prometheus
open Namespace

module type Metric_spec_intf = sig
  val subsystem : string

  val name : string

  val help : string
end

module type Bucketed_average_spec_intf = sig
  include Metric_spec_intf

  val bucket_interval : Core.Time.Span.t

  val num_buckets : int

  val render_average : (float * int) list -> float
end

module type Time_average_spec_intf = sig
  include Metric_spec_intf

  val tick_interval : Core.Time.Span.t

  val rolling_interval : Core.Time.Span.t
end

module type Moving_average_metric_intf = sig
  type datum

  val v : Gauge.t

  val update : datum -> unit

  val clear : unit -> unit
end

module Moving_bucketed_average (Spec : Bucketed_average_spec_intf) () :
  Moving_average_metric_intf with type datum := float = struct
  open Spec

  let v = Gauge.v name ~subsystem ~namespace ~help

  let empty_bucket_entry = (0.0, 0)

  let empty_buckets = List.init num_buckets ~f:(Fn.const empty_bucket_entry)

  let buckets = ref empty_buckets

  let clear () = buckets := empty_buckets

  let update datum =
    match !buckets with
    | [] ->
        failwith "Moving_bucketed_average buckets are malformed"
    | (value, num_entries) :: t ->
        buckets := (value +. datum, num_entries + 1) :: t

  let () =
    let rec tick () =
      upon
        (after (Time_ns.Span.of_ns @@ Time.Span.to_ns bucket_interval))
        (fun () ->
          Gauge.set v (render_average !buckets) ;
          buckets := empty_bucket_entry :: List.take !buckets (num_buckets - 1) ;
          tick () )
    in
    tick ()
end

module Moving_time_average (Spec : sig
  include Time_average_spec_intf

  val render_time_average : Core.Time.Span.t -> float
end)
() : Moving_average_metric_intf with type datum := Core.Time.Span.t = struct
  open Spec
  open Time.Span

  let () =
    let ( = ) = Float.equal in
    let ( mod ) = Float.mod_float in
    if not (to_ns rolling_interval mod to_ns tick_interval = 0.0) then
      failwith
        "invalid intervals provided to Moving_time_average -- the \
         tick_interval does not evenly divide the rolling_interval"

  include Moving_bucketed_average (struct
              include Spec

              let bucket_interval = tick_interval

              let num_buckets =
                Float.to_int (to_ns rolling_interval /. to_ns tick_interval)

              let render_average buckets =
                let sum =
                  List.fold buckets ~init:0.0 ~f:(fun sum (bucket_total, _) ->
                      sum +. bucket_total )
                in
                render_time_average (Core.Time.Span.of_ns sum)
            end)
            ()

  let update span = update (Core.Time.Span.to_ns span)
end

module Moving_time_sec_average (Spec : Time_average_spec_intf) () :
  Moving_average_metric_intf with type datum := Core.Time.Span.t =
  Moving_time_average (struct
      include Spec

      let render_time_average span =
        Core.Time.Span.(to_sec span /. to_sec rolling_interval)
    end)
    ()
