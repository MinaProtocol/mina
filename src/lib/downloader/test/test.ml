open Core
open Async
open Pipe_lib
open Network_peer

(* Regression test for the downloader [`No_peers] wedge.

   The downloader step loop reaches the [`No_peers] state when no known peer has
   any of the pending jobs. Before the fix, that branch waited only on the
   [got_new_peers] signal and ignored the [useful_peers] signal that fires
   whenever a peer's usefulness changes (a download finishing, a knowledge
   update, a temporary-ignore expiring). Once parked, the loop could therefore
   only be woken by a brand-new peer connecting; every other recovery signal was
   dropped, leaving the node silently stuck in bootstrap or catchup.

   This test drives the loop into [`No_peers] by starting it with no peers, then
   advertises -- via [add_knowledge] -- that an existing peer has the job. That
   writes only the [useful_peers] signal. The fixed loop wakes and downloads the
   job; the unfixed loop stays parked and the job never resolves, which the
   timeout below turns into a failure.

   [peers] returns the empty list throughout, so the [got_new_peers] signal is
   never fired and cannot mask the bug, and the timeout is well under the loop's
   one-minute fallback re-check so a pass requires the signal-driven wake
   specifically. *)

module Key = struct
  include Int

  let to_yojson i = `Int i
end

module Attempt = struct
  type t = unit

  let to_yojson () = `Null

  let download = ()

  let worth_retrying _ = true
end

module Result = struct
  type t = Key.t

  let key = Fn.id
end

module Knowledge_context = struct
  type t = unit
end

module D = Downloader.Make (Key) (Attempt) (Result) (Knowledge_context)

let%test_unit "[`No_peers] state wakes on a useful_peers signal" =
  Thread_safe.block_on_async_exn (fun () ->
      let logger = Logger.null () in
      let trust_system = Trust_system.null () in
      let stop = Ivar.create () in
      let peer =
        Peer.create
          (Core.Unix.Inet_addr.of_string "1.2.3.4")
          ~libp2p_port:8302
          ~peer_id:(Peer.Id.unsafe_of_string "regression-test-peer")
      in
      let knowledge_context, _knowledge_w = Broadcast_pipe.create () in
      let%bind downloader =
        D.create ~max_batch_size:1 ~stop:(Ivar.read stop) ~logger ~trust_system
          ~get:(fun _peer keys -> Deferred.Or_error.return keys)
          ~knowledge_context
          ~knowledge:(fun () _peer -> Deferred.return (`Some []))
          ~peers:(fun () -> Deferred.return [])
          ~preferred:[] ()
      in
      let job = D.download downloader ~key:1 ~attempts:Peer.Map.empty in
      (* Let the loop settle into [`No_peers] (the flush delay is 100ms). *)
      let%bind () = after (Time.Span.of_ms 500.) in
      (* Advertise that [peer] has the job. This fires only the [useful_peers]
         signal -- not [got_new_peers] -- which the unfixed loop ignores. *)
      D.add_knowledge downloader peer [ 1 ] ;
      let%map result = with_timeout (Time.Span.of_sec 15.) (D.Job.result job) in
      Ivar.fill_if_empty stop () ;
      match result with
      | `Timeout ->
          failwith
            "downloader stayed wedged in [`No_peers]: did not wake on the \
             useful_peers signal"
      | `Result (Ok _) ->
          ()
      | `Result (Error `Finished) ->
          failwith "job was cancelled/stopped unexpectedly" )

(* End-to-end regression test for the full self-heal path.

   Unlike the test above (which injects a [useful_peers] signal directly), this
   one exercises the production recovery chain: a download fails, which marks the
   job [tried_and_failed] against the peer and temporarily ignores it; the loop
   parks in [`No_peers]; the temporary-ignore expires; the loop wakes,
   re-evaluates to [`Stalled], resets the peer's knowledge (clearing
   [tried_and_failed]); and the subsequent retry succeeds.

   The recovery delays are set to small values via [create]'s optional
   parameters so the whole chain runs in well under a second. [get] fails the
   first attempt and succeeds thereafter. [peers] returns a single stable peer so
   that [reset_knowledge] (which drops peers not in the peer set) keeps it, and
   [peer_refresh_interval] is small so the peer is delivered promptly after the
   initial empty broadcast value. *)

let%test_unit "[`No_peers] self-heals through `Stalled`/reset_knowledge" =
  Thread_safe.block_on_async_exn (fun () ->
      let logger = Logger.null () in
      let trust_system = Trust_system.null () in
      let stop = Ivar.create () in
      let peer =
        Peer.create
          (Core.Unix.Inet_addr.of_string "1.2.3.4")
          ~libp2p_port:8302
          ~peer_id:(Peer.Id.unsafe_of_string "regression-test-peer")
      in
      let knowledge_context, _knowledge_w = Broadcast_pipe.create () in
      let download_attempts = ref 0 in
      let%bind downloader =
        D.create ~ignore_period:(Time.Span.of_ms 200.)
          ~post_stall_retry_delay:(Time.Span.of_ms 200.)
          ~peer_refresh_interval:(Time.Span.of_ms 100.) ~max_batch_size:1
          ~stop:(Ivar.read stop) ~logger ~trust_system
          ~get:(fun _peer keys ->
            incr download_attempts ;
            if !download_attempts = 1 then
              Deferred.return
                (Or_error.error_string "simulated download failure")
            else Deferred.Or_error.return keys )
          ~knowledge_context
          ~knowledge:(fun () _peer -> Deferred.return `All)
          ~peers:(fun () -> Deferred.return [ peer ])
          ~preferred:[] ()
      in
      let job = D.download downloader ~key:1 ~attempts:Peer.Map.empty in
      let%map result = with_timeout (Time.Span.of_sec 15.) (D.Job.result job) in
      Ivar.fill_if_empty stop () ;
      match result with
      | `Timeout ->
          failwith
            "downloader did not self-heal: the failed job was not retried \
             after the temporary ignore expired"
      | `Result (Ok _) ->
          [%test_eq: bool] (!download_attempts >= 2) true
      | `Result (Error `Finished) ->
          failwith "job was cancelled/stopped unexpectedly" )
