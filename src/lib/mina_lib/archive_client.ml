open Core_kernel
open Async_kernel
open Pipe_lib

let dispatch ?(max_tries = 5)
    (archive_location : Host_and_port.t Cli_lib.Flag.Types.with_name) diff =
  let rec go tries_left errs =
    if Int.( <= ) tries_left 0 then
      let e = Error.of_list (List.rev errs) in
      return
        (Error
           (Error.tag_arg e
              (sprintf
                 "Could not send archive diff data to archive process after %d \
                  tries. The process may not be running, please check the \
                  daemon-argument"
                 max_tries)
              ( ("host_and_port", archive_location.value)
              , ("daemon-argument", archive_location.name) )
              [%sexp_of: (string * Host_and_port.t) * (string * string)]))
    else
      match%bind
        Daemon_rpcs.Client.dispatch Archive_lib.Rpc.t diff
          archive_location.value
      with
      | Ok () ->
          return (Ok ())
      | Error e ->
          go (tries_left - 1) (e :: errs)
  in
  go max_tries []

let make_dispatch_block rpc ?(max_tries = 5)
    (archive_location : Host_and_port.t Cli_lib.Flag.Types.with_name) block =
  let rec go tries_left errs =
    if Int.( <= ) tries_left 0 then
      let e = Error.of_list (List.rev errs) in
      return
        (Error
           (Error.tag_arg e
              (sprintf
                 "Could not send block data to archive process after %d tries. \
                  The process may not be running, please check the \
                  daemon-argument"
                 max_tries)
              ( ("host_and_port", archive_location.value)
              , ("daemon-argument", archive_location.name) )
              [%sexp_of: (string * Host_and_port.t) * (string * string)]))
    else
      match%bind
        Daemon_rpcs.Client.dispatch rpc block archive_location.value
      with
      | Ok () ->
          return (Ok ())
      | Error e ->
          go (tries_left - 1) (e :: errs)
  in
  go max_tries []

let dispatch_precomputed_block =
  make_dispatch_block Archive_lib.Rpc.precomputed_block

let dispatch_extensional_block =
  make_dispatch_block Archive_lib.Rpc.extensional_block

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
                    , Transition_frontier.Breadcrumb.to_yojson breadcrumb )
                  ]
                "Could not send breadcrumb to archive: $error"))

let run ~logger
    ~(frontier_broadcast_pipe :
       Transition_frontier.t option Broadcast_pipe.Reader.t) archive_location =
  O1trace.background_thread "send_diffs_to_archiver" (fun () ->
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
               transfer ~logger ~archive_location breadcrumb_reader)))
