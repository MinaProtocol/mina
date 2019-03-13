open Async_kernel

module type Time_intf = sig
  type t

  module Span : sig
    type t

    val to_time_ns_span : t -> Core.Time_ns.Span.t

    val ( - ) : t -> t -> t
  end

  module Controller : sig
    type t
  end

  val now : Controller.t -> t

  val diff : t -> t -> Span.t
end

module Timeout_intf (Time : Time_intf) = struct
  module type S = sig
    type 'a t

    val create : Time.Controller.t -> Time.Span.t -> f:(Time.t -> 'a) -> 'a t

    val to_deferred : 'a t -> 'a Async_kernel.Deferred.t

    val peek : 'a t -> 'a option

    val cancel : Time.Controller.t -> 'a t -> 'a -> unit

    val remaining_time : 'a t -> Time.Span.t
  end
end

module Make (Time : Time_intf) : Timeout_intf(Time).S = struct
  type 'a t =
    { deferred: 'a Deferred.t
    ; cancel: 'a -> unit
    ; start_time: Time.t
    ; span: Time.Span.t
    ; ctrl: Time.Controller.t }

  let create ctrl span ~f:action =
    let open Deferred.Let_syntax in
    let cancel_ivar = Ivar.create () in
    let timeout = after (Time.Span.to_time_ns_span span) >>| fun () -> None in
    let deferred =
      Deferred.any [Ivar.read cancel_ivar; timeout]
      >>| function None -> action (Time.now ctrl) | Some x -> x
    in
    let cancel value = Ivar.fill_if_empty cancel_ivar (Some value) in
    {ctrl; deferred; cancel; start_time= Time.now ctrl; span}

  let to_deferred {deferred; _} = deferred

  let peek {deferred; _} = Deferred.peek deferred

  let cancel _ {cancel; _} value = cancel value

  let remaining_time {ctrl : _; deferred : _; cancel : _; start_time; span} =
    let current_time = Time.now ctrl in
    let time_elapsed = Time.diff current_time start_time in
    Time.Span.(span - time_elapsed)
end
