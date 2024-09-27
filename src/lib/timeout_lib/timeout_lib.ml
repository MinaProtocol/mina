open Async_kernel
open Core_kernel

module type Time_intf = sig
  type t

  module Span : sig
    type t

    val to_time_ns_span : t -> Time_ns.Span.t

    val zero : t

    val ( - ) : t -> t -> t

    val ( < ) : t -> t -> bool

    val ( > ) : t -> t -> bool
  end

  module Controller : sig
    type t
  end

  val now : Controller.t -> t

  val diff : t -> t -> Span.t

  val add : t -> Span.t -> t

  val ( < ) : t -> t -> bool
end

module Timeout_intf (Time : Time_intf) = struct
  module type S = sig
    type 'a t

    type ('a, 'b) reschedulable

    type ('a, 'b) reschedulable_result =
      [ `Rescheduled
      | `Paused of 'b Deferred.t
      | `Canceled of 'a
      | `Complete of 'b ]

    val create : Time.Controller.t -> Time.Span.t -> f:(Time.t -> 'a) -> 'a t

    val scheduler : unit -> (_, _) reschedulable

    (** While a timeout is paused, the callback is prevented from firing. *)
    val pause : (_, _) reschedulable -> unit

    (** Unpause the timeout, processing the callback if enough time has elapsed. *)
    val unpause : (_, _) reschedulable -> unit

    val to_deferred : 'a t -> 'a Async_kernel.Deferred.t

    val peek : 'a t -> 'a option

    (** Never fire the callback. *)
    val cancel : Time.Controller.t -> 'a t -> 'a -> unit

    val remaining_time : 'a t -> Time.Span.t

    val await :
         timeout_duration:Time.Span.t
      -> Time.Controller.t
      -> 'a Deferred.t
      -> [ `Ok of 'a | `Timeout ] Deferred.t

    val await_exn :
         timeout_duration:Time.Span.t
      -> Time.Controller.t
      -> 'a Deferred.t
      -> 'a Deferred.t

    (** A timeout can be rescheduled, when created via [scheduler ()]. If
        [new_deadline] is after the current deadline, it is ignored,
        and [f] will be called at the earliest deadline time. *)
    val reschedule :
         ('a, 'b) reschedulable
      -> Time.Controller.t
      -> new_deadline:Time.t
      -> f:(unit -> 'b)
      -> unit
  end
end

module Make (Time : Time_intf) : Timeout_intf(Time).S = struct
  type 'a t =
    { deferred : 'a Deferred.t
    ; cancel : 'a option Ivar.t
    ; start_time : Time.t
    ; span : Time.Span.t
    ; ctrl : Time.Controller.t
    }

  type ('a, 'b) reschedulable_result =
    [ `Rescheduled
    | `Paused of 'b Deferred.t
    | `Canceled of 'a
    | `Complete of 'b ]

  type ('a, 'b) reschedulable =
    { mutable timeout : ('a, 'b) reschedulable_result t option
    ; mutable unpaused : unit Ivar.t
    }

  let create ctrl span ~f:action =
    let open Deferred.Let_syntax in
    let cancel = Ivar.create () in
    let timeout = after (Time.Span.to_time_ns_span span) >>| fun () -> None in
    let deferred =
      Deferred.any [ Ivar.read cancel; timeout ]
      >>| function None -> action (Time.now ctrl) | Some x -> x
    in
    { ctrl; deferred; cancel; start_time = Time.now ctrl; span }

  let to_deferred { deferred; _ } = deferred

  let peek { deferred; _ } = Deferred.peek deferred

  let cancel _ { cancel; _ } value = Ivar.fill_if_empty cancel (Some value)

  let remaining_time { ctrl : _; start_time; span; _ } =
    let current_time = Time.now ctrl in
    let time_elapsed = Time.diff current_time start_time in
    Time.Span.(span - time_elapsed)

  let await ~timeout_duration time_controller deferred =
    let timeout =
      Deferred.create (fun ivar ->
          ignore
            ( create time_controller timeout_duration ~f:(fun x ->
                  if Ivar.is_full ivar then
                    [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
                  Ivar.fill_if_empty ivar x )
              : unit t ) )
    in
    Deferred.(
      choose
        [ choice deferred (fun x -> `Ok x); choice timeout (Fn.const `Timeout) ])

  let await_exn ~timeout_duration time_controller deferred =
    match%map await ~timeout_duration time_controller deferred with
    | `Timeout ->
        failwith "timeout"
    | `Ok x ->
        x

  let scheduler () : (_, _) reschedulable =
    { timeout = None; unpaused = Ivar.create_full () }

  let pause ({ unpaused; _ } as t) =
    if Ivar.is_full unpaused then t.unpaused <- Ivar.create ()

  let unpause { unpaused; _ } = Ivar.fill unpaused ()

  let reschedule (t : (_, 'complete) reschedulable) ctrl ~new_deadline
      ~(f : unit -> 'complete) =
    let f_now () =
      t.timeout <- None ;
      f ()
    in
    let min a b = if Time.( < ) a b then a else b in
    Option.iter t.timeout ~f:(fun timeout -> cancel ctrl timeout `Rescheduled) ;
    let until_earliest_deadline =
      Time.diff
        (Option.value_map t.timeout ~default:new_deadline ~f:(fun t ->
             let remaining = remaining_time t in
             if Time.Span.(remaining < zero) then (
               (* An overdue timeout gets ignored, and ought to be incredibly rare. *)
               [%log' error (Logger.create ())]
                 "rescheduled a timeout that was overdue this cycle" ;
               new_deadline )
             else min new_deadline Time.(add (now ctrl) remaining) ) )
        (Time.now ctrl)
    in
    let wait_til_unpaused _ =
      if Ivar.is_full t.unpaused then `Complete (f_now ())
      else
        let res = Ivar.create () in
        don't_wait_for
          (let%map () = Ivar.read t.unpaused in
           if
             Option.value_map ~default:true
               ~f:(fun { cancel; _ } -> Ivar.is_empty cancel)
               t.timeout
           then Ivar.fill res (f_now ()) ) ;
        `Paused (Ivar.read res)
    in
    t.timeout <- Some (create ctrl until_earliest_deadline ~f:wait_til_unpaused)
end

module Core_time = Make (struct
  include (
    Core_kernel.Time :
      module type of Core_kernel.Time
        with module Span := Core_kernel.Time.Span
         and type underlying = float )

  module Controller = struct
    type t = unit
  end

  module Span = struct
    include Core_kernel.Time.Span

    let to_time_ns_span = Fn.compose Core_kernel.Time_ns.Span.of_ns to_ns
  end

  let diff x y =
    let x_ns = Span.to_ns @@ to_span_since_epoch x in
    let y_ns = Span.to_ms @@ to_span_since_epoch y in
    Span.of_ns (x_ns -. y_ns)
end)

module Core_time_ns = Make (struct
  include (
    Core_kernel.Time_ns :
      module type of Core_kernel.Time_ns
        with module Span := Core_kernel.Time_ns.Span )

  module Controller = struct
    type t = unit
  end

  module Span = struct
    include Core_kernel.Time_ns.Span

    let to_time_ns_span = Fn.id
  end

  let diff x y =
    let x_ns = Span.to_ns @@ to_span_since_epoch x in
    let y_ns = Span.to_ms @@ to_span_since_epoch y in
    Span.of_ns (x_ns -. y_ns)
end)
