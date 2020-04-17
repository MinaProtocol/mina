open Core_kernel
open Async_kernel
open Prometheus
open Namespace

let block_window_duration = ref None

let ticks = ref (Some [])

let lazy_block_window_duration =
  lazy
    ( match !block_window_duration with
    | Some x ->
        x
    | None ->
        failwith "Coda_metrics.block_window_duration is not set" )

module type Metric_spec_intf = sig
  val subsystem : string

  val name : string

  val help : string
end

module type Bucketed_average_spec_intf = sig
  include Metric_spec_intf

  (** Argument is block_window_duration *)
  val bucket_interval : int -> Core.Time.Span.t

  (** Argument is block_window_duration *)
  val num_buckets : int -> int

  val render_average : (float * int) list -> float
end

module type Time_average_spec_intf = sig
  include Metric_spec_intf

  val tick_interval : int -> Core.Time.Span.t

  val rolling_interval : int -> Core.Time.Span.t
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

  let num_buckets = lazy (num_buckets (Lazy.force lazy_block_window_duration))

  let bucket_interval =
    lazy (bucket_interval (Lazy.force lazy_block_window_duration))

  let empty_buckets () =
    List.init (Lazy.force num_buckets) ~f:(Fn.const empty_bucket_entry)

  let buckets = ref None

  let clear () = buckets := Some (empty_buckets ())

  let update datum =
    if Option.is_none !buckets then buckets := Some (empty_buckets ()) ;
    match Option.value_exn !buckets with
    | [] ->
        failwith "Moving_bucketed_average buckets are malformed"
    | (value, num_entries) :: t ->
        buckets := Some ((value +. datum, num_entries + 1) :: t)

  let rec tick () =
    upon
      (after
         (Time_ns.Span.of_ns @@ Time.Span.to_ns (Lazy.force bucket_interval)))
      (fun () ->
        if Option.is_none !buckets then buckets := Some (empty_buckets ()) ;
        let buckets_val = Option.value_exn !buckets in
        Gauge.set v (render_average buckets_val) ;
        buckets :=
          Some
            ( empty_bucket_entry
            :: List.take buckets_val (Lazy.force num_buckets - 1) ) ;
        tick () )

  let () =
    match !ticks with
    | Some l ->
        ticks := Some (tick :: l)
    | None ->
        failwith "Metric generators have already been started."
end

module Moving_time_average (Spec : sig
  include Time_average_spec_intf

  val render_time_average : Core.Time.Span.t -> float
end)
() : Moving_average_metric_intf with type datum := Core.Time.Span.t = struct
  open Time.Span

  include Moving_bucketed_average (struct
              include Spec

              let intervals =
                lazy
                  (let rolling_interval =
                     rolling_interval (Lazy.force lazy_block_window_duration)
                   in
                   let tick_interval =
                     tick_interval (Lazy.force lazy_block_window_duration)
                   in
                   let ( = ) = Float.equal in
                   let ( mod ) = Float.mod_float in
                   if to_ns rolling_interval mod to_ns tick_interval = 0.0 then
                     (tick_interval, rolling_interval)
                   else
                     failwith
                       "invalid intervals provided to Moving_time_average -- \
                        the tick_interval does not evenly divide the \
                        rolling_interval")

              let bucket_interval _block_window_duration =
                fst @@ Lazy.force intervals

              let num_buckets _block_window_duration =
                let tick_interval, rolling_interval = Lazy.force intervals in
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
        Core.Time.Span.(
          to_sec span
          /. to_sec (rolling_interval (Lazy.force lazy_block_window_duration)))
    end)
    ()
