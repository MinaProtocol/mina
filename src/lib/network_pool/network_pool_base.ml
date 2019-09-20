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
   and type transition_frontier := Transition_frontier.t = struct
  type t =
    { resource_pool: Resource_pool.t
    ; logger: Logger.t
    ; write_broadcasts: Resource_pool.Diff.t Linear_pipe.Writer.t
    ; read_broadcasts: Resource_pool.Diff.t Linear_pipe.Reader.t }

  let resource_pool {resource_pool; _} = resource_pool

  let broadcasts {read_broadcasts; _} = read_broadcasts

  let apply_and_broadcast t pool_diff =
    match%bind Resource_pool.Diff.apply t.resource_pool pool_diff with
    | Ok diff' ->
        Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
          "Broadcasting %s"
          (Resource_pool.Diff.summary diff') ;
        Linear_pipe.write t.write_broadcasts diff'
    | Error e ->
        Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
          "Pool diff apply feedback: %s" (Error.to_string_hum e) ;
        Deferred.unit

  let of_resource_pool_and_diffs resource_pool ~logger ~incoming_diffs =
    let read_broadcasts, write_broadcasts = Linear_pipe.create () in
    let network_pool =
      {resource_pool; logger; read_broadcasts; write_broadcasts}
    in
    Linear_pipe.iter incoming_diffs ~f:(fun diff ->
        apply_and_broadcast network_pool diff )
    |> ignore ;
    network_pool

  (* Rebroadcast locally generated pool items every 5 minutes or every slot,
     whichever is slower. Do so for half an hour before giving up. *)
  let rebroadcast_loop : t -> Logger.t -> unit Deferred.t =
   fun t logger ->
    let rebroadcast_interval =
      Time.Span.(
        max
          (of_ms @@ Float.of_int Consensus.Constants.block_window_duration_ms)
          (of_min 5.))
    in
    let is_expired time = Time.(add time (Time.Span.of_min 30.) < now ()) in
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

  let create ~logger ~pids ~trust_system ~incoming_diffs
      ~frontier_broadcast_pipe =
    let t =
      of_resource_pool_and_diffs
        (Resource_pool.create ~logger ~trust_system ~pids
           ~frontier_broadcast_pipe)
        ~logger ~incoming_diffs
    in
    don't_wait_for (rebroadcast_loop t logger) ;
    t
end
