open Core_kernel
open Async_kernel
open Pipe_lib
open O1trace

let dispatch (archive_location : Host_and_port.t Cli_lib.Flag.Types.with_name)
    diff =
  match%map
    Daemon_rpcs.Client.dispatch Archive_lib.Rpc.t diff archive_location.value
  with
  | Ok () ->
      Ok ()
  | Error e ->
      Error
        (Error.tag_arg e
           "Could not send data to archive process. It may not be running, \
            please check the daemon-argument"
           ( ("host_and_port", archive_location.value)
           , ("daemon-argument", archive_location.name) )
           [%sexp_of: (string * Host_and_port.t) * (string * string)])

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
                  [ ("error", Error_json.error_to_yojson e)
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
