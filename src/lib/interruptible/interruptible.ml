open Core_kernel
open Async_kernel

module T = struct
  type ('a, 's) t =
    { interruption_signal : 's Ivar.t; d : ('a, 's) Deferred.Result.t }

  let map_signal t ~f =
    let interruption_signal =
      match Ivar.peek t.interruption_signal with
      | Some signal ->
          Ivar.create_full (f signal)
      | None ->
          let interruption_signal = Ivar.create () in
          Deferred.upon (Ivar.read t.interruption_signal) (fun signal ->
              Ivar.fill_if_empty interruption_signal (f signal) ) ;
          interruption_signal
    in
    { interruption_signal; d = Deferred.Result.map_error ~f t.d }

  let map t ~f =
    match Ivar.peek t.interruption_signal with
    | None ->
        (* Note: we do not shortcut if [t.d] has resolved, otherwise the
           interruption signal cannot interrupt this function.
        *)
        let d =
          let%map res =
            Deferred.choose
              [ Deferred.choice (Ivar.read t.interruption_signal) Result.fail
              ; Deferred.choice t.d Fn.id
              ]
          in
          (* If the interruption signal fires between [t.d] resolving and the
             scheduler running this code to call [f], we prefer the signal and
             avoid running [f].
          *)
          match Ivar.peek t.interruption_signal with
          | None ->
              Result.map ~f res
          | Some e ->
              Error e
        in
        { interruption_signal = t.interruption_signal; d }
    | Some e ->
        (* The interruption signal has already triggered, resolve to the
           signal's value.
        *)
        { interruption_signal = t.interruption_signal
        ; d = Deferred.Result.fail e
        }

  let bind t ~f =
    let t : (('a, 's) t, 's) t = map ~f t in
    (* Propagate the signal into the [Interruptible.t] returned by [bind]. *)
    Deferred.upon (Ivar.read t.interruption_signal) (fun signal ->
        Deferred.upon t.d (function
          | Ok t' ->
              Ivar.fill_if_empty t'.interruption_signal signal
          | Error _ ->
              () ) ) ;
    let interruption_signal =
      match Ivar.peek t.interruption_signal with
      | Some interruption_signal ->
          Ivar.create_full interruption_signal
      | None ->
          let interruption_signal = Ivar.create () in
          Deferred.upon t.d (function
            | Ok t' ->
                Deferred.upon
                  (Ivar.read t'.interruption_signal)
                  (Ivar.fill_if_empty interruption_signal)
            | Error signal ->
                (* [t] was interrupted by [signal], [f] was not run. *)
                Ivar.fill_if_empty interruption_signal signal ) ;
          interruption_signal
    in
    Deferred.upon (Ivar.read interruption_signal) (fun signal ->
        match Deferred.peek t.d with
        | Some (Ok t') ->
            (* The computation [t] which we bound over has resolved, don't
               interrupt it in case some other values also depend on it.
               Still interrupt [t'] because it's a consequence of this [bind].
            *)
            Ivar.fill_if_empty t'.interruption_signal signal
        | Some (Error _) ->
            (* Already interrupted, do nothing. *)
            ()
        | None ->
            (* The computation we bound hasn't resolved, interrupt it. *)
            Ivar.fill_if_empty t.interruption_signal signal ) ;
    { interruption_signal; d = Deferred.Result.bind t.d ~f:(fun t' -> t'.d) }

  let return a =
    { interruption_signal = Ivar.create (); d = Deferred.Result.return a }

  let don't_wait_for { d; _ } =
    don't_wait_for @@ Deferred.map d ~f:(function Ok () -> () | Error _ -> ())

  let finally t ~f =
    { interruption_signal = t.interruption_signal
    ; d = Deferred.map t.d ~f:(fun r -> f () ; r)
    }

  let uninterruptible d =
    { interruption_signal = Ivar.create ()
    ; d = Deferred.map d ~f:(fun x -> Ok x)
    }

  let lift d interrupt =
    let interruption_signal = Ivar.create () in
    Deferred.upon interrupt (Ivar.fill_if_empty interruption_signal) ;
    { interruption_signal; d = Deferred.map d ~f:(fun x -> Ok x) }

  let force t =
    (* We use [map] here to prefer interrupt signals even where the underlying
       value has been resolved.
    *)
    (map ~f:Fn.id t).d

  let map = `Define_using_bind
end

module M = Monad.Make2 (T)
include T
include M

module Result = struct
  type nonrec ('a, 'b, 's) t = (('a, 'b) Result.t, 's) t

  include Monad.Make3 (struct
    type nonrec ('a, 'b, 's) t = ('a, 'b, 's) t

    let bind x ~f =
      x >>= function Ok y -> f y | Error err -> return (Error err)

    let map = `Define_using_bind

    let return x = return (Result.return x)
  end)
end

module Or_error = struct
  type nonrec ('a, 's) t = ('a Or_error.t, 's) t

  include (
    Result :
      module type of Result with type ('a, 'b, 's) t := ('a, 'b, 's) Result.t )
end

module Deferred_let_syntax = struct
  module Let_syntax = struct
    let return = return

    let bind x ~f = bind (uninterruptible x) ~f

    let map x ~f = map (uninterruptible x) ~f

    let both x y =
      Let_syntax.Let_syntax.both (uninterruptible x) (uninterruptible y)

    module Open_on_rhs = Deferred.Let_syntax
  end
end
