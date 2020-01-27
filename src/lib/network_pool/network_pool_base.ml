open Async_kernel
open Core_kernel
open Pipe_lib

module Make (Transition_frontier : sig
  type t
end)
(Resource_pool : Intf.Resource_pool_intf
                 with type transition_frontier := Transition_frontier.t) :
  Intf.Network_pool_base_intf
  with type resource_pool := Resource_pool.t
   and type resource_pool_diff := Resource_pool.Diff.t
   and type transition_frontier := Transition_frontier.t
   and type config := Resource_pool.Config.t = struct
  type t =
    { resource_pool: Resource_pool.t
    ; logger: Logger.t
    ; write_broadcasts: Resource_pool.Diff.t Linear_pipe.Writer.t
    ; read_broadcasts: Resource_pool.Diff.t Linear_pipe.Reader.t }

  let resource_pool {resource_pool; _} = resource_pool

  let broadcasts {read_broadcasts; _} = read_broadcasts

  let apply_and_broadcast t (pool_diff, valid_cb) =
    let rebroadcast diff' ~forward =
      valid_cb true ;
      Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
        "Broadcasting %s"
        (Resource_pool.Diff.summary diff') ;
      if forward then Linear_pipe.write t.write_broadcasts diff'
      else Deferred.unit
    in
    match%bind Resource_pool.Diff.apply t.resource_pool pool_diff with
    | Ok diff' ->
        rebroadcast diff' ~forward:true
    | Error (`Locally_generated diff') ->
        rebroadcast diff' ~forward:false
    | Error (`Other e) ->
        valid_cb false ;
        Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
          "Refusing to rebroadcast: pool diff apply feedback: %s"
          (Error.to_string_hum e) ;
        Deferred.unit

  let of_resource_pool_and_diffs resource_pool ~logger ~incoming_diffs =
    let read_broadcasts, write_broadcasts = Linear_pipe.create () in
    let network_pool =
      {resource_pool; logger; read_broadcasts; write_broadcasts}
    in
    Linear_pipe.iter incoming_diffs ~f:(fun diff_and_cb ->
        apply_and_broadcast network_pool diff_and_cb )
    |> ignore ;
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
    let is_expired time =
      if Time.(add time rebroadcast_window < now ()) then `Expired else `Ok
    in
    let rec go () =
      let rebroadcastable =
        Resource_pool.get_rebroadcastable t.resource_pool ~is_expired
      in
      let log (log_func : 'a Logger.log_function) =
        log_func logger ~location:__LOC__ ~module_:__MODULE__
      in
      if List.is_empty rebroadcastable then
        log Logger.trace "Nothing to rebroadcast"
      else
        log Logger.debug
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

  let create ~config ~incoming_diffs ~frontier_broadcast_pipe ~logger =
    let t =
      of_resource_pool_and_diffs
        (Resource_pool.create ~config ~logger ~frontier_broadcast_pipe)
        ~incoming_diffs ~logger
    in
    don't_wait_for (rebroadcast_loop t logger) ;
    t
end
