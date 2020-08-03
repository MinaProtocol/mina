open Core_kernel
open Async_kernel
open Pipe_lib
open O1trace

let dispatch (archive_location : Host_and_port.t Cli_lib.Flag.Types.with_name)
    diff =
  match%bind
    Daemon_rpcs.Client.dispatch Archive_lib.Rpc.t diff archive_location.value
  with
  | Ok () ->
      Deferred.Or_error.ok_unit
  | Error e ->
      Deferred.Or_error.errorf
        !"Could not send data to archive host_and_port (%s). The archive \
          process may not be running. Please check the daemon-argument (%s):\n\
          %s"
        (Host_and_port.to_string archive_location.value)
        archive_location.name (Error.to_string_hum e)

let transfer ~logger ~archive_location
    (breadcrumb_reader :
      Transition_frontier.Extensions.New_breadcrumbs.view
      Broadcast_pipe.Reader.t) =
  Broadcast_pipe.Reader.iter breadcrumb_reader ~f:(fun breadcrumbs ->
      Deferred.List.iter breadcrumbs ~f:(fun breadcrumb ->
          let diff = Archive_lib.Diff.Builder.breadcrumb_added breadcrumb in
          match%map dispatch archive_location (Transition_frontier diff) with
          | Ok () ->
              ()
          | Error e ->
              [%log warn]
                ~metadata:
                  [ ("error", `String (Error.to_string_hum e))
                  ; ( "breadcrumb"
                    , Transition_frontier.Breadcrumb.to_yojson breadcrumb ) ]
                "Could not send breadcrumb to archive: $error" ) )

let run ~logger
    ~(frontier_broadcast_pipe :
       Transition_frontier.t option Broadcast_pipe.Reader.t) archive_location =
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
               transfer ~logger ~archive_location breadcrumb_reader )) )
