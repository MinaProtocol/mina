open Core_kernel
open Async_kernel
open Pipe_lib
open O1trace

let dispatch archive_process_port diff =
  match%bind
    Daemon_rpcs.Client.dispatch Archive_lib.Rpc.t diff archive_process_port
  with
  | Ok () ->
      Deferred.Or_error.ok_unit
  | Error e ->
      Deferred.Or_error.errorf
        !"Could not send data to archive port. The archive process may not be \
          running: %s"
        (Error.to_string_hum e)

let transfer ~logger ~archive_process_port
    (breadcrumb_reader :
      Transition_frontier.Extensions.New_breadcrumbs.view
      Broadcast_pipe.Reader.t) =
  Broadcast_pipe.Reader.iter breadcrumb_reader ~f:(fun breadcrumbs ->
      Deferred.List.iter breadcrumbs ~f:(fun breadcrumb ->
          let diff = Archive_lib.Diff.Builder.breadcrumb_added breadcrumb in
          match%map
            dispatch archive_process_port (Transition_frontier diff)
          with
          | Ok () ->
              ()
          | Error e ->
              Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
                !"Could not send breadcrumb to archive: %s"
                (Error.to_string_hum e)
                ~metadata:
                  [ ( "Breadcrumb"
                    , Transition_frontier.Breadcrumb.to_yojson breadcrumb ) ]
      ) )

let run ~logger ~archive_process_port
    ~(frontier_broadcast_pipe :
       Transition_frontier.t option Broadcast_pipe.Reader.t) =
  trace_task "Daemon sending diffs to archive loop" (fun () ->
      Broadcast_pipe.Reader.iter frontier_broadcast_pipe
        ~f:
          (Option.value_map ~default:Deferred.unit
             ~f:(fun transition_frontier ->
               let extensions =
                 Transition_frontier.extensions transition_frontier
               in
               let breadcrumb_reader =
                 Transition_frontier.Extensions.get_view_pipe extensions
                   Transition_frontier.Extensions.New_breadcrumbs
               in
               transfer ~logger ~archive_process_port breadcrumb_reader )) )
