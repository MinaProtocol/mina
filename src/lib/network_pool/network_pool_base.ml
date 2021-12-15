open Async_kernel
open Core_kernel
open Pipe_lib
open Network_peer
open O1trace

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
    type resource_pool_diff = Resource_pool.Diff.t

    type rejected_diff = Resource_pool.Diff.rejected

    type t =
      | Local of
          (   (Resource_pool.Diff.t * Resource_pool.Diff.rejected) Or_error.t
           -> unit)
      | External of Mina_net2.Validation_callback.t

    let is_expired = function
      | Local _ ->
          false
      | External cb ->
          Mina_net2.Validation_callback.is_expired cb

    open Mina_net2.Validation_callback

    let error err =
      Fn.compose Deferred.return (function
        | Local f ->
            f (Error err)
        | External cb ->
            fire_if_not_already_fired cb `Reject)

    let drop accepted rejected =
      Fn.compose Deferred.return (function
        | Local f ->
            f (Ok (accepted, rejected))
        | External cb ->
            fire_if_not_already_fired cb `Ignore)

    let forward broadcast_pipe accepted rejected = function
      | Local f ->
          f (Ok (accepted, rejected)) ;
          Linear_pipe.write broadcast_pipe accepted
      | External cb ->
          fire_if_not_already_fired cb `Accept ;
          Deferred.unit

    let _replace broadcast_pipe accepted rejected = function
      | Local f ->
          f (Ok (accepted, rejected)) ;
          Linear_pipe.write broadcast_pipe accepted
      | External cb ->
          fire_if_not_already_fired cb `Ignore ;
          Linear_pipe.write broadcast_pipe accepted
  end

  module Remote_sink =
    Pool_sink.Remote_sink
      (struct
        include Resource_pool.Diff

        type pool = Resource_pool.t
      end)
      (Broadcast_callback)

  module Local_sink =
    Pool_sink.Local_sink
      (struct
        include Resource_pool.Diff

        type pool = Resource_pool.t
      end)
      (Broadcast_callback)

  type t =
    { resource_pool : Resource_pool.t
    ; logger : Logger.t
    ; write_broadcasts : Resource_pool.Diff.t Linear_pipe.Writer.t
    ; read_broadcasts : Resource_pool.Diff.t Linear_pipe.Reader.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    }

  let resource_pool { resource_pool; _ } = resource_pool

  let broadcasts { read_broadcasts; _ } = read_broadcasts

  let create_rate_limiter () =
    Rate_limiter.create
      ~capacity:
        (Resource_pool.Diff.max_per_15_seconds, `Per (Time.Span.of_sec 15.0))

  let apply_and_broadcast t
      (diff : Resource_pool.Diff.verified Envelope.Incoming.t) cb =
    let rebroadcast (diff', rejected) =
      let open Broadcast_callback in
      if Resource_pool.Diff.is_empty diff' then (
        [%log' trace t.logger]
          "Refusing to rebroadcast $diff. Pool diff apply feedback: empty diff"
          ~metadata:
            [ ( "diff"
              , Resource_pool.Diff.verified_to_yojson
                @@ Envelope.Incoming.data diff )
            ] ;
        drop diff' rejected cb )
      else (
        [%log' debug t.logger] "Rebroadcasting diff %s"
          (Resource_pool.Diff.summary diff') ;
        forward t.write_broadcasts diff' rejected cb )
    in
    trace_recurring (Resource_pool.label ^ "_apply_and_broadcast") (fun () ->
        match%bind Resource_pool.Diff.unsafe_apply t.resource_pool diff with
        | Ok res ->
            rebroadcast res
        | Error (`Locally_generated res) ->
            rebroadcast res
        | Error (`Other e) ->
            [%log' debug t.logger]
              "Refusing to rebroadcast. Pool diff apply feedback: $error"
              ~metadata:[ ("error", Error_json.error_to_yojson e) ] ;
            Broadcast_callback.error e cb)

  let log_rate_limiter_occasionally t rl =
    let time = Time_ns.Span.of_min 1. in
    every time (fun () ->
        [%log' debug t.logger]
          ~metadata:[ ("rate_limiter", Rate_limiter.summary rl) ]
          !"%s $rate_limiter" Resource_pool.label)

  type wrapped_t =
    | Incoming of
        (Resource_pool.Diff.verified Envelope.Incoming.t * Broadcast_callback.t)
    | Local of
        (Resource_pool.Diff.verified Envelope.Incoming.t * Broadcast_callback.t)
    | Transition_frontier_extension of Resource_pool.transition_frontier_diff

  let of_resource_pool_and_diffs resource_pool ~logger ~constraint_constants
      ~tf_diffs =
    let read_broadcasts, write_broadcasts = Linear_pipe.create () in
    let network_pool =
      { resource_pool
      ; logger
      ; read_broadcasts
      ; write_broadcasts
      ; constraint_constants
      }
    in
    let remote_r, remote_w, remote_rl =
      Remote_sink.create
        ~wrap:(fun m -> Incoming m)
        ~unwrap:(function
          | Incoming m -> m | _ -> failwith "unexpected message type")
        ~trace_label:Resource_pool.label ~logger resource_pool
    in
    let local_r, local_w, _ =
      Local_sink.create
        ~wrap:(fun m -> Local m)
        ~unwrap:(function
          | Local m -> m | _ -> failwith "unexpected message type")
        ~trace_label:Resource_pool.label ~logger resource_pool
    in
    log_rate_limiter_occasionally network_pool remote_rl ;
    (*priority: Transition frontier diffs > local diffs > incomming diffs*)
    Strict_pipe.Reader.Merge.iter
      [ Strict_pipe.Reader.map tf_diffs ~f:(fun diff ->
            Transition_frontier_extension diff)
      ; remote_r
      ; local_r
      ]
      ~f:(fun diff_source ->
        match diff_source with
        | Incoming ((verified_diff, cb) : Remote_sink.unwrapped_t) ->
            apply_and_broadcast network_pool verified_diff cb
        | Local ((verified_diff, cb) : Local_sink.unwrapped_t) ->
            apply_and_broadcast network_pool verified_diff cb
        | Transition_frontier_extension diff ->
            trace_recurring
              (Resource_pool.label ^ "_handle_transition_frontier_diff")
              (fun () ->
                Resource_pool.handle_transition_frontier_diff diff resource_pool))
    |> Deferred.don't_wait_for ;
    (network_pool, remote_w, local_w)

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
      trace_recurring (Resource_pool.label ^ "_rebroadcast_loop") (fun () ->
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
                [ ("count", `Int (List.length rebroadcastable))
                ; ( "diffs"
                  , `List
                      (List.map
                         ~f:(fun d -> `String (Resource_pool.Diff.summary d))
                         rebroadcastable) )
                ] ;
          let%bind () =
            Deferred.List.iter rebroadcastable
              ~f:(Linear_pipe.write t.write_broadcasts)
          in
          let%bind () = Async.after rebroadcast_interval in
          go ())
    in
    go ()

  let create ~config ~constraint_constants ~consensus_constants ~time_controller
      ~frontier_broadcast_pipe ~logger =
    (*Diffs from tansition frontier extensions*)
    let tf_diff_reader, tf_diff_writer =
      Strict_pipe.(
        create ~name:"Network pool transition frontier diffs" Synchronous)
    in
    let t, locals, remotes =
      of_resource_pool_and_diffs
        (Resource_pool.create ~constraint_constants ~consensus_constants
           ~time_controller ~config ~logger ~frontier_broadcast_pipe
           ~tf_diff_writer)
        ~constraint_constants ~logger ~tf_diffs:tf_diff_reader
    in
    don't_wait_for (rebroadcast_loop t logger) ;
    (t, locals, remotes)
end
