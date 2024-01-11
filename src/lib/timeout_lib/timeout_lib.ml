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

  val ( < ) : t -> t -> bool
end

module Timeout_intf (Time : Time_intf) = struct
  module type S = sig
    type 'a t

    val create : Time.Controller.t -> Time.Span.t -> f:(Time.t -> 'a) -> 'a t

    val to_deferred : 'a t -> 'a Async_kernel.Deferred.t

    val peek : 'a t -> 'a option

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

    module Earliest : sig
      type t

      val create : Time.Controller.t -> t

      (** Pause all execution. No dispatched task will be called until [unpause t] is executed. *)
      val pause : t -> unit

      (** Unpause execution. Any pending task is examined. *)
      val unpause : t -> unit

      val schedule : t -> Time.t -> f:(unit -> unit) -> unit
    end
  end
end

module Make (Time : Time_intf) : Timeout_intf(Time).S = struct
  type 'a t =
    { deferred : 'a Deferred.t
    ; cancel : 'a -> unit
    ; start_time : Time.t
    ; span : Time.Span.t
    ; ctrl : Time.Controller.t
    }

  let create ctrl span ~f:action =
    let open Deferred.Let_syntax in
    let cancel_ivar = Ivar.create () in
    let timeout = after (Time.Span.to_time_ns_span span) >>| fun () -> None in
    let deferred =
      Deferred.any [ Ivar.read cancel_ivar; timeout ]
      >>| function None -> action (Time.now ctrl) | Some x -> x
    in
    let cancel value = Ivar.fill_if_empty cancel_ivar (Some value) in
    { ctrl; deferred; cancel; start_time = Time.now ctrl; span }

  let to_deferred { deferred; _ } = deferred

  let peek { deferred; _ } = Deferred.peek deferred

  let cancel _ { cancel; _ } value = cancel value

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

  module Earliest = struct
    type nonrec t =
      { mutable timeout : unit t option
      ; mutable unpaused : unit Ivar.t
      ; mutable canceled : bool ref
      ; time_controller : Time.Controller.t
      }

    let create_timeout = create

    let create time_controller =
      { time_controller
      ; unpaused = Ivar.create_full ()
      ; timeout = None
      ; canceled = ref false
      }

    let pause t = if Ivar.is_full t.unpaused then t.unpaused <- Ivar.create ()

    let unpause t = Ivar.fill t.unpaused ()

    let cancel t =
      match t.timeout with
      | Some timeout ->
          cancel t.time_controller timeout () ;
          t.canceled := true ;
          t.timeout <- None
      | None ->
          ()

    let schedule t time ~f =
      let min a b = if Time.(a < b) then a else b in
      cancel t ;
      t.canceled <- ref false ;
      let new_start_time =
        Option.value_map t.timeout ~default:time ~f:(fun { start_time; _ } ->
            min time start_time )
      in
      let wait_span = Time.diff new_start_time (Time.now t.time_controller) in
      let canceled = t.canceled in
      let timeout =
        create_timeout t.time_controller wait_span ~f:(fun _ ->
            don't_wait_for
              (let%map () = Ivar.read t.unpaused in
               if not !canceled then (t.timeout <- None ;
               f ()) ) )
      in
      t.timeout <- Some timeout
  end
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
