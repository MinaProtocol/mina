open Core
open Async
module Validation_callback = Mina_net2.Validation_callback

let%test_module "Recording validation callback outcomes" =
  ( module struct
    let state_hash = "a-state-hash"

    let resolved outcome : Block_outcome_log.event =
      Callback_resolved { state_hash; outcome }

    let record f =
      snd
        (Async.Thread_safe.block_on_async_exn (fun () ->
             Block_outcome_log.For_tests.recording_deferred f ) )

    let named_callback ~expires_in =
      let cb =
        Validation_callback.create
          (Time_ns.add (Time_ns.now ()) (Time_ns.Span.of_ms expires_in))
      in
      Validation_callback.set_subject cb (lazy state_hash) ;
      cb

    let%test_unit "The first firing is recorded" =
      [%test_eq: Block_outcome_log.event list]
        (record (fun () ->
             let cb = named_callback ~expires_in:10_000. in
             Validation_callback.fire_if_not_already_fired cb `Accept ;
             Validation_callback.fire_if_not_already_fired cb `Reject ;
             Deferred.unit ) )
        [ resolved `Accept ]

    let%test_unit "Expiring unfired is recorded" =
      [%test_eq: Block_outcome_log.event list]
        (record (fun () ->
             let cb = named_callback ~expires_in:50. in
             let%bind () = Validation_callback.await_timeout cb in
             (* Let the outcome log's own wait on the expiry run. *)
             Scheduler.yield_until_no_jobs_remain () ) )
        [ resolved `Expired ]

    let%test_unit "A callback without a subject isn't recorded" =
      [%test_eq: Block_outcome_log.event list]
        (record (fun () ->
             let cb = Validation_callback.create_without_expiration () in
             Validation_callback.fire_if_not_already_fired cb `Ignore ;
             Deferred.unit ) )
        []
  end )
