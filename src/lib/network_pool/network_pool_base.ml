open Async_kernel
open Core_kernel
open Pipe_lib

module Make (Transition_frontier : sig
  type t
end) (Resource_pool : sig
  include Intf.Resource_pool_intf

  (** Diff from a transition frontier extension that would update the resource pool*)
  val handle_transition_frontier_diff :
    transition_frontier_diff -> t -> unit Deferred.t

  val create :
       frontier_broadcast_pipe:Transition_frontier.t Option.t
                               Broadcast_pipe.Reader.t
    -> config:Config.t
    -> logger:Logger.t
    -> tf_diff_writer:transition_frontier_diff Linear_pipe.Writer.t
    -> t
end) :
  Intf.Network_pool_base_intf
  with type resource_pool := Resource_pool.t
   and type resource_pool_diff := Resource_pool.Diff.t
   and type transition_frontier := Transition_frontier.t
   and type transition_frontier_diff := Resource_pool.transition_frontier_diff
   and type config := Resource_pool.Config.t = struct
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

  let of_resource_pool_and_diffs resource_pool ~logger ~incoming_diffs
      ~local_diffs ~tf_diff =
    let read_broadcasts, write_broadcasts = Linear_pipe.create () in
    let network_pool =
      {resource_pool; logger; read_broadcasts; write_broadcasts}
    in
    Linear_pipe.merge_unordered
      [ Linear_pipe.map incoming_diffs ~f:(fun diff -> `Incoming diff)
      ; Linear_pipe.map local_diffs ~f:(fun diff -> `Local diff)
      ; Linear_pipe.map tf_diff ~f:(fun diff ->
            `Transition_frontier_extension diff ) ]
    |> Linear_pipe.iter ~f:(fun diff_source ->
           match diff_source with
           | `Incoming diff ->
               apply_and_broadcast network_pool diff
           | `Local diff ->
               (*Should this be coming from resource pool instead?*)
               apply_and_broadcast network_pool (Envelope.Incoming.local diff)
           | `Transition_frontier_extension diff ->
               Resource_pool.handle_transition_frontier_diff diff resource_pool
       )
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

  let create ~config ~incoming_diffs ~local_diffs ~frontier_broadcast_pipe
      ~logger =
    (*Diffs from tansition frontier extensions*)
    let tf_diff_reader, tf_diff_writer = Linear_pipe.create () in
    let t =
      of_resource_pool_and_diffs
        (Resource_pool.create ~config ~logger ~frontier_broadcast_pipe
           ~tf_diff_writer)
        ~incoming_diffs ~local_diffs ~logger ~tf_diff:tf_diff_reader
    in
    don't_wait_for (rebroadcast_loop t logger) ;
    t
end
