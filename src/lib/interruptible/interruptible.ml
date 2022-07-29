open Async_kernel
open Core_kernel

type 'a t = ('a, unit) Deferred.Result.t

module type F = Functor_type.F with type 'a t := 'a t

let don't_wait_for = Fn.compose don't_wait_for Deferred.ignore_m

let peek_result action =
  Option.(join @@ map ~f:Result.ok @@ Deferred.peek action)

let unit = Deferred.Result.return ()

module Make () = struct
  let interrupt_ivar = Ivar.create ()

  let lift action =
    Deferred.choose
      [ Deferred.choice action Result.return
      ; Deferred.choice (Ivar.read interrupt_ivar) Result.fail
      ]

  let map_ ~f action =
    let default =
      let%map.Deferred res =
        Deferred.choose
          [ Deferred.choice action Fn.id
          ; Deferred.choice (Ivar.read interrupt_ivar) Result.fail
          ]
      in
      (* If the interruption signal fires between [t.d] resolving and the
         scheduler running this code to call [f], we prefer the signal and
         avoid running [f].
      *)
      match Ivar.peek interrupt_ivar with
      | None ->
          Result.map ~f res
      | Some e ->
          Error e
    in
    Option.value_map (Ivar.peek interrupt_ivar) ~f:Deferred.Result.fail ~default

  let force action = map_ ~f:Fn.id action

  let peek action =
    match Ivar.peek interrupt_ivar with
    | Some () ->
        Some (Result.fail ())
    | None ->
        Deferred.peek action

  let finally action ~f =
    let%map.Deferred res =
      Deferred.choose
        [ Deferred.choice action Fn.id
        ; Deferred.choice (Ivar.read interrupt_ivar) Result.fail
        ]
    in
    f () ; res

  include Monad.Make (struct
    type 'a t = ('a, unit) Deferred.Result.t

    let map = `Define_using_bind

    let bind action ~f = Deferred.Result.join (map_ ~f action)

    let return = Deferred.Result.return
  end)

  module Deferred_let_syntax = struct
    module Let_syntax = struct
      module Let_syntax = struct
        let return = return

        let bind x ~f = bind (lift x) ~f

        let map x ~f = map (lift x) ~f

        let both x y = Let_syntax.Let_syntax.both (lift x) (lift y)

        module Open_on_rhs = Deferred.Result.Let_syntax
      end
    end
  end

  module Result = struct
    type nonrec ('a, 'b) t = ('a, 'b) Result.t t

    include Monad.Make2 (struct
      type nonrec ('a, 'b) t = ('a, 'b) t

      let bind x ~f =
        x >>= function Ok y -> f y | Error err -> return (Error err)

      let map = `Define_using_bind

      let return x = return (Result.return x)
    end)
  end
end

let%test_module "interruptible tests" =
  ( module struct
    let wait i = after (Time_ns.Span.of_ms i)

    let wait_r i = wait i >>| Result.return

    let%test_unit "monad gets interrupted" =
      Run_in_thread.block_on_async_exn (fun () ->
          let r = ref 0 in
          let open Make () in
          don't_wait_for
            (let open Let_syntax in
            let%bind () = wait_r 100. in
            incr r ;
            let%map () = wait_r 100. in
            incr r) ;
          let%bind.Deferred () = wait 130. in
          Ivar.fill interrupt_ivar () ;
          let%map.Deferred () = wait 100. in
          assert (!r = 1) )

    let%test_unit "monad gets interrupted within nested binds" =
      Run_in_thread.block_on_async_exn (fun () ->
          let r = ref 0 in
          let open Make () in
          let rec go () =
            let open Let_syntax in
            let%bind () = wait_r 100. in
            incr r ; go ()
          in
          don't_wait_for (go ()) ;
          let open Deferred.Let_syntax in
          let%bind () = wait 130. in
          Ivar.fill interrupt_ivar () ;
          let%map () = wait 100. in
          assert (!r = 1) )

    let%test_unit "interruptions still run finally blocks" =
      Run_in_thread.block_on_async_exn (fun () ->
          let r = ref 0 in
          let open Make () in
          let rec go () =
            let open Let_syntax in
            let%bind () = wait_r 100. in
            incr r ; go ()
          in
          don't_wait_for (finally (go ()) ~f:(fun () -> incr r)) ;
          let open Deferred.Let_syntax in
          let%bind () = wait 130. in
          Ivar.fill interrupt_ivar () ;
          let%map () = wait 100. in
          assert (!r = 2) )

    let%test_unit "interruptions branches do not cancel each other" =
      Run_in_thread.block_on_async_exn (fun () ->
          let s = ref 0 in
          let module S = Make () in
          let rec go_s () =
            let open S.Let_syntax in
            let%bind () = wait_r 100. in
            incr s ; go_s ()
          in
          let r = ref 0 in
          let module R = Make () in
          let rec go_r () =
            let open R.Let_syntax in
            let%bind () = wait_r 100. in
            incr r ; go_r ()
          in
          don't_wait_for (go_r ()) ;
          don't_wait_for (go_s ()) ;
          let open Deferred.Let_syntax in
          let%bind () = wait 130. in
          Ivar.fill R.interrupt_ivar () ;
          let%bind () = wait 100. in
          Ivar.fill S.interrupt_ivar () ;
          let%map () = wait 100. in
          assert (!r = 1) ;
          assert (!s = 2) )
  end )
