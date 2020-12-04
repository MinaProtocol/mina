open Async_kernel
open Core_kernel
open Pipe_lib
open Network_peer

module Make (Transition_frontier : sig
  type t
end)
(Resource_pool : Intf.Resource_pool_intf
                 with type transition_frontier := Transition_frontier.t) :
  Intf.Network_pool_base_intf
  with type resource_pool := Resource_pool.t
   and type resource_pool_diff := Resource_pool.Diff.t
   and type resource_pool_diff_verified := Resource_pool.Diff.verified
   and type transition_frontier := Transition_frontier.t
   and type transition_frontier_diff := Resource_pool.transition_frontier_diff
   and type config := Resource_pool.Config.t
   and type rejected_diff := Resource_pool.Diff.rejected = struct
  module Broadcast_callback = struct
    type t =
      | Local of
          (   (Resource_pool.Diff.t * Resource_pool.Diff.rejected) Or_error.t
           -> unit)
      | External of Coda_net2.Validation_callback.t

    let is_expired = function
      | Local _ ->
          false
      | External cb ->
          Coda_net2.Validation_callback.is_expired cb

    open Coda_net2.Validation_callback

    let error err =
      Fn.compose Deferred.return (function
        | Local f ->
            f (Error err)
        | External cb ->
            fire_exn cb `Reject )

    let drop accepted rejected =
      Fn.compose Deferred.return (function
        | Local f ->
            f (Ok (accepted, rejected))
        | External cb ->
            fire_exn cb `Ignore )

    let forward broadcast_pipe accepted rejected = function
      | Local f ->
          f (Ok (accepted, rejected)) ;
          Linear_pipe.write broadcast_pipe accepted
      | External cb ->
          fire_exn cb `Accept ;
          Deferred.unit

    let replace broadcast_pipe accepted rejected = function
      | Local f ->
          f (Ok (accepted, rejected)) ;
          Linear_pipe.write broadcast_pipe accepted
      | External cb ->
          fire_exn cb `Ignore ;
          Linear_pipe.write broadcast_pipe accepted
  end

  type t =
    { resource_pool: Resource_pool.t
    ; logger: Logger.t
    ; write_broadcasts: Resource_pool.Diff.t Linear_pipe.Writer.t
    ; read_broadcasts: Resource_pool.Diff.t Linear_pipe.Reader.t
    ; constraint_constants: Genesis_constants.Constraint_constants.t }

  let resource_pool {resource_pool; _} = resource_pool

  let broadcasts {read_broadcasts; _} = read_broadcasts

  let apply_and_broadcast t
      (diff : Resource_pool.Diff.verified Envelope.Incoming.t) cb =
    let open Envelope.Incoming in
    let rebroadcast (diff', rejected) =
      let open Broadcast_callback in
      if Resource_pool.Diff.is_empty diff' then (
        [%log' trace t.logger]
          "Refusing to rebroadcast $diff. Pool diff apply feedback: empty diff"
          ~metadata:
            [ ( "diff"
              , Resource_pool.Diff.verified_to_yojson
                @@ Envelope.Incoming.data diff ) ] ;
        drop diff' rejected cb )
      else if
        Resource_pool.Diff.verified_size diff.data
        = Resource_pool.Diff.size diff'
      then (
        [%log' trace t.logger] "Rebroadcasting diff %s"
          (Resource_pool.Diff.summary diff') ;
        forward t.write_broadcasts diff' rejected cb )
      else (
        [%log' trace t.logger] "Broadcasting %s"
          (Resource_pool.Diff.summary diff') ;
        replace t.write_broadcasts diff' rejected cb )
    in
    match%bind Resource_pool.Diff.unsafe_apply t.resource_pool diff with
    | Ok res ->
        rebroadcast res
    | Error (`Locally_generated res) ->
        rebroadcast res
    | Error (`Other e) ->
        [%log' trace t.logger]
          "Refusing to rebroadcast. Pool diff apply feedback: $error"
          ~metadata:[("error", Error_json.error_to_yojson e)] ;
        Broadcast_callback.error e cb

  let filter_verified pipe t ~f =
    let r, w =
      Strict_pipe.create ~name:"verified network pool diffs"
        (Buffered (`Capacity 1024, `Overflow Drop_head))
    in
    (*Note: This is done asynchronously to use batch verification*)
    Strict_pipe.Reader.iter_without_pushback pipe ~f:(fun d ->
        let diff, cb = f d in
        if not (Broadcast_callback.is_expired cb) then (
          let summary =
            `String (Resource_pool.Diff.summary @@ Envelope.Incoming.data diff)
          in
          [%log' debug t.logger] "Verifying $diff" ~metadata:[("diff", summary)] ;
          don't_wait_for
            ( match%bind Resource_pool.Diff.verify t.resource_pool diff with
            | Error err ->
                [%log' trace t.logger]
                  "Refusing to rebroadcast $diff. Verification error: $error"
                  ~metadata:
                    [ ("diff", summary)
                    ; ("error", Error_json.error_to_yojson err) ] ;
                (*reject incoming messages*)
                Broadcast_callback.error err cb
            | Ok verified_diff ->
                [%log' debug t.logger] "Verified diff: $verified_diff"
                  ~metadata:
                    [ ( "verified_diff"
                      , Resource_pool.Diff.verified_to_yojson
                        @@ Envelope.Incoming.data verified_diff )
                    ; ( "sender"
                      , Envelope.Sender.to_yojson
                        @@ Envelope.Incoming.sender verified_diff ) ] ;
                Deferred.return
                @@ Strict_pipe.Writer.write w (verified_diff, cb) ) ) )
    |> don't_wait_for ;
    r

  let of_resource_pool_and_diffs resource_pool ~logger ~constraint_constants
      ~incoming_diffs ~local_diffs ~tf_diffs =
    let read_broadcasts, write_broadcasts = Linear_pipe.create () in
    let network_pool =
      { resource_pool
      ; logger
      ; read_broadcasts
      ; write_broadcasts
      ; constraint_constants }
    in
    (*proiority: Transition frontier diffs > local diffs > incomming diffs*)
    Strict_pipe.Reader.Merge.iter
      [ Strict_pipe.Reader.map tf_diffs ~f:(fun diff ->
            `Transition_frontier_extension diff )
      ; Strict_pipe.Reader.map
          (filter_verified local_diffs network_pool ~f:(fun (diff, cb) ->
               (Envelope.Incoming.local diff, Broadcast_callback.Local cb) ))
          ~f:(fun d -> `Local d)
      ; Strict_pipe.Reader.map
          (filter_verified incoming_diffs network_pool ~f:(fun (diff, cb) ->
               (diff, Broadcast_callback.External cb) ))
          ~f:(fun d -> `Incoming d) ]
      ~f:(fun diff_source ->
        match diff_source with
        | `Incoming (verified_diff, cb) ->
            apply_and_broadcast network_pool verified_diff cb
        | `Local (verified_diff, cb) ->
            apply_and_broadcast network_pool verified_diff cb
        | `Transition_frontier_extension diff ->
            Resource_pool.handle_transition_frontier_diff diff resource_pool )
    |> Deferred.don't_wait_for ;
    network_pool

  (* Rebroadcast locally generated pool items every 10 minutes. Do so for 50
     minutes - at most 5 rebroadcasts - before giving up.

     The goal here is to be resilient to short term network failures and
     partitions. Note that with gossip we don't know anything about the state of
     other peers' pools (we know if something made it into a block, but that can
     take a long time and it's possible for things to be successfully received
     but never used in a block), so in a healthy network all repetition is spam.
     We need to balance reliability with efficiency. Exponential "backoff" would
     be better, but it'd complicate the interface between this module and the
     specific pool implementations.
  *)
  let rebroadcast_loop : t -> Logger.t -> unit Deferred.t =
   fun t logger ->
    let rebroadcast_interval = Time.Span.of_min 10. in
    let rebroadcast_window = Time.Span.scale rebroadcast_interval 5. in
    let has_timed_out time =
      if Time.(add time rebroadcast_window < now ()) then `Timed_out else `Ok
    in
    let rec go () =
      let rebroadcastable =
        Resource_pool.get_rebroadcastable t.resource_pool ~has_timed_out
      in
      if List.is_empty rebroadcastable then
        [%log trace] "Nothing to rebroadcast"
      else
        [%log debug]
          "Preparing to rebroadcast locally generated resource pool diffs \
           $diffs"
          ~metadata:
            [ ( "diffs"
              , `List
                  (List.map ~f:Resource_pool.Diff.to_yojson rebroadcastable) )
            ] ;
      let%bind () =
        Deferred.List.iter rebroadcastable
          ~f:(Linear_pipe.write t.write_broadcasts)
      in
      let%bind () = Async.after rebroadcast_interval in
      go ()
    in
    go ()

  let create ~config ~constraint_constants ~consensus_constants
      ~time_controller ~incoming_diffs ~local_diffs ~frontier_broadcast_pipe
      ~logger =
    (*Diffs from tansition frontier extensions*)
    let tf_diff_reader, tf_diff_writer =
      Strict_pipe.(
        create ~name:"Network pool transition frontier diffs" Synchronous)
    in
    let t =
      of_resource_pool_and_diffs
        (Resource_pool.create ~constraint_constants ~consensus_constants
           ~time_controller ~config ~logger ~frontier_broadcast_pipe
           ~tf_diff_writer)
        ~constraint_constants ~incoming_diffs ~local_diffs ~logger
        ~tf_diffs:tf_diff_reader
    in
    don't_wait_for (rebroadcast_loop t logger) ;
    t
end
