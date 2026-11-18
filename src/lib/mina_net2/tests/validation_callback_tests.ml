open Core
open Async
module Validation_callback = Mina_net2.Validation_callback

let%test_module "Observing how validation callbacks resolve" =
  ( module struct
    type resolution = [ `Accept | `Reject | `Ignore | `Expired ]
    [@@deriving compare, sexp]

    (* Run [f] on a callback that expires after [expires_in] ms, observing how
       it resolves until [f] finishes. *)
    let resolutions ~expires_in f =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let resolutions = ref [] in
          let cb =
            Validation_callback.create
              (Time_ns.add (Time_ns.now ()) (Time_ns.Span.of_ms expires_in))
          in
          Validation_callback.set_on_resolve cb (fun resolution ->
              resolutions := resolution :: !resolutions ) ;
          let%map () = f cb in
          List.rev !resolutions )

    let%test_unit "Only the first firing is observed" =
      [%test_eq: resolution list]
        (resolutions ~expires_in:10_000. (fun cb ->
             Validation_callback.fire_if_not_already_fired cb `Accept ;
             Validation_callback.fire_if_not_already_fired cb `Reject ;
             Deferred.unit ) )
        [ `Accept ]

    let%test_unit "Expiring unfired is observed" =
      [%test_eq: resolution list]
        (resolutions ~expires_in:50. (fun cb ->
             let%bind () = Validation_callback.await_timeout cb in
             (* Let the observer's own wait on the expiry run. *)
             Scheduler.yield_until_no_jobs_remain () ) )
        [ `Expired ]

    let%test_unit "Firing before expiry isn't also observed as expiring" =
      [%test_eq: resolution list]
        (resolutions ~expires_in:50. (fun cb ->
             Validation_callback.fire_if_not_already_fired cb `Ignore ;
             let%bind () = Validation_callback.await_timeout cb in
             Scheduler.yield_until_no_jobs_remain () ) )
        [ `Ignore ]
  end )
