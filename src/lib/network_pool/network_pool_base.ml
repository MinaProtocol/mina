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

  let create ~logger ~pids ~trust_system ~incoming_diffs
      ~frontier_broadcast_pipe =
    of_resource_pool_and_diffs
      (Resource_pool.create ~logger ~pids ~trust_system
         ~frontier_broadcast_pipe)
      ~logger ~incoming_diffs
end
