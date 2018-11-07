open Core_kernel
open Async_kernel

(* TODO: Give clear semantics for and fix impl of this, see #300 *)
module T = struct
  type ('a, 's) t =
    {interruption_signal: 's Deferred.t; d: ('a, 's) Deferred.Result.t}

  let map_signal {interruption_signal; d} ~f =
    { interruption_signal= Deferred.map interruption_signal ~f
    ; d= Deferred.Result.map_error d ~f }

  let bind t ~f =
    match Deferred.peek t.d with
    | None ->
        let interruption_signal_to_res =
          t.interruption_signal >>| fun s -> Error s
        in
        let maybe_sig_d =
          let w : ('a, 's) Deferred.Result.t =
            Deferred.any [t.d; interruption_signal_to_res]
          in
          Deferred.Result.map w ~f:(fun a ->
              let t' = f a in
              (t'.interruption_signal, t'.d) )
        in
        let interruption_signal' =
          Deferred.any
            [ t.interruption_signal
            ; ( maybe_sig_d
              >>= function
              | Ok (interruption_signal, _) -> interruption_signal
              | Error e -> Deferred.return e ) ]
        in
        let d' =
          Deferred.any
            [ interruption_signal_to_res
            ; ( maybe_sig_d
              >>= fun m ->
              match m with
              | Ok (_, d) -> d
              | Error e -> Deferred.return (Error e) ) ]
        in
        {interruption_signal= interruption_signal'; d= d'}
    | Some (Ok a) ->
        let t' = f a in
        { interruption_signal=
            Deferred.any [t'.interruption_signal; t.interruption_signal]
        ; d= t'.d }
    | Some (Error e) -> {t with d= Deferred.return (Error e)}

  let return a =
    {interruption_signal= Deferred.never (); d= Deferred.Result.return a}

  let don't_wait_for {d; _} =
    don't_wait_for @@ Deferred.map d ~f:(function Ok () -> () | Error _ -> ())

  let finally t ~f = {t with d= Deferred.map t.d ~f:(fun r -> f () ; r)}

  let uninterruptible d =
    { interruption_signal= Deferred.never ()
    ; d= Deferred.map d ~f:(fun x -> Ok x) }

  let lift d interruption_signal =
    {d= Deferred.map d ~f:(fun x -> Ok x); interruption_signal}

  let map = `Define_using_bind
end

module M = Monad.Make2 (T)
include T
include M

let%test_unit "monad gets interrupted" =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let r = ref 0 in
      let wait i = Async.after (Core.Time.Span.of_ms i) in
      let change () = Deferred.return (r := 1) in
      let ivar = Ivar.create () in
      let _w =
        let change () = lift (change ()) (Ivar.read ivar) in
        let wait x = lift (wait x) (Ivar.read ivar) in
        let open Let_syntax in
        let%bind () = wait 100. in
        change ()
      in
      let open Deferred.Let_syntax in
      let%bind () = wait 30. in
      Ivar.fill ivar () ;
      let%map () = wait 100. in
      assert (!r = 0) )
