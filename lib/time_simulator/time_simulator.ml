open Core_kernel
open Async_kernel

type t = Int64.t [@@deriving compare]

let add = Int64.( + )

let diff = Int64.( - )

let modulus = Int64.( % )

let ( < ) = Int64.( < )

module Action = struct
  type nonrec t = {at: t; perform: t Ivar.t}

  let compare {at; _} {at= at'; _} = compare at at'
end

(* Seconds in floating point *)
module Span = struct
  include Int64

  let of_time_span s = Int64.of_float (Time.Span.to_ms s)
end

module Controller = struct
  type nonrec t =
    { mutable last_time: t
    ; mutable last_snapshot: Time.t
    ; actions: Action.t Heap.t }

  let create () =
    { last_time= Int64.zero
    ; last_snapshot= Time.now ()
    ; actions= Heap.create ~cmp:Action.compare () }

  let fast_forward t time =
    if time < t.last_time then ()
    else
      let sys_now = Time.now () in
      let diff = diff time t.last_time in
      let diff_since_checked =
        Span.of_time_span (Time.diff sys_now t.last_snapshot)
      in
      let true_diff = Int64.max diff diff_since_checked in
      t.last_time <- add t.last_time true_diff ;
      t.last_snapshot <- sys_now

  let now t =
    let sys_now = Time.now () in
    let diff_since_checked =
      Span.of_time_span (Time.diff sys_now t.last_snapshot)
    in
    t.last_time <- add t.last_time diff_since_checked ;
    t.last_snapshot <- sys_now ;
    t.last_time

  (* Semantics: Tick to the next event immediately. The internal clock
   * fast-forwards to at-least the time of the next event. If real sys time
   * elapsed since the last tick/now is greater we prefer that time. Thus, we
   * could end up needing to process more than one event. And we do so.
   *
   * Why? This behavior ensures that if our real logic is too slow, we'll still
   * simulate that same behavior.
   *)
  let tick t =
    let exec t =
      let {Action.perform; at} = Heap.pop_exn t.actions in
      fast_forward t at ;
      Ivar.fill_if_empty perform t.last_time
    in
    let rec go once =
      match (Heap.top t.actions, once) with
      | Some _, `First ->
          exec t ;
          go `No
      | Some {Action.at; _}, `No when at < t.last_time ->
          exec t ;
          go `No
      | Some _, `No -> ()
      | None, _ -> ()
    in
    go `First
end

let now = Controller.now

module Timeout = struct
  type 'a t = {d: 'a Deferred.t; elt: 'a Heap.Elt.t; cancel: 'a Ivar.t}

  let create (ctrl: Controller.t) span ~f =
    let ivar = Ivar.create () in
    let elt =
      Heap.add_removable ctrl.actions
        {Action.at= add (now ctrl) span; perform= ivar}
    in
    let cancel = Ivar.create () in
    let d = Deferred.any [Ivar.read ivar >>| f; Ivar.read cancel] in
    {d; elt; cancel}

  let to_deferred {d; _} = d

  let peek {d; _} = Deferred.peek d

  let cancel (ctrl: Controller.t) {elt; cancel; _} a =
    Heap.remove ctrl.actions elt ;
    Ivar.fill_if_empty cancel a
end
