open Core_kernel
open Async_kernel
open Pipe_lib

let dispatch ?(max_tries = 5) ~logger ~state_hash
    (archive_location : Host_and_port.t Cli_lib.Flag.Types.with_name) diff =
  let diff_time = Time.now () in
  let rec go tries_left errs =
    if Int.( <= ) tries_left 0 then
      let e = Error.of_list (List.rev errs) in
      let err =
        Error.tag_arg e
          (sprintf
             "Could not send archive diff data to archive process after %d \
              tries. The process may not be running, please check the \
              daemon-argument"
             max_tries )
          ( ("host_and_port", archive_location.value)
          , ("daemon-argument", archive_location.name) )
          [%sexp_of: (string * Host_and_port.t) * (string * string)]
      in
      [%log error] "Failed to send archive data for $state_hash: $error"
        ~metadata:
          [ ("state_hash", Mina_base.State_hash.to_yojson state_hash)
          ; ("error", `String (Error.to_string_hum err))
          ]
    else
      upon
        (Daemon_rpcs.Client.dispatch Archive_lib.Rpc.t diff
           archive_location.value ) (fun res ->
          match res with
          | Ok () ->
              [%log debug]
                "Dispatched archive data for $state_hash, took $time ms"
                ~metadata:
                  [ ("state_hash", Mina_base.State_hash.to_yojson state_hash)
                  ; ( "time"
                    , `Float
                        (Time.Span.to_ms (Time.diff (Time.now ()) diff_time)) )
                  ]
          | Error e ->
              [%log error]
                "Error sending data for $state_hash to the archive process \
                 $error. Retrying..."
                ~metadata:
                  [ ("state_hash", Mina_base.State_hash.to_yojson state_hash)
                  ; ("error", `String (Error.to_string_hum e))
                  ] ;
              go (tries_left - 1) (e :: errs) )
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
                 max_tries )
              ( ("host_and_port", archive_location.value)
              , ("daemon-argument", archive_location.name) )
              [%sexp_of: (string * Host_and_port.t) * (string * string)] ) )
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

let transfer ~logger ~precomputed_values ~archive_location
    (breadcrumb_reader :
      Transition_frontier.Extensions.New_breadcrumbs.view
      Broadcast_pipe.Reader.t ) =
  Broadcast_pipe.Reader.iter breadcrumb_reader ~f:(fun breadcrumbs ->
      List.iter breadcrumbs ~f:(fun breadcrumb ->
          let start = Time.now () in
          let diff =
            Archive_lib.Diff.Builder.breadcrumb_added ~precomputed_values
              ~logger breadcrumb
          in
          let diff_time = Time.now () in
          [%log debug] "Archive data generation for $state_hash took $time ms"
            ~metadata:
              [ ( "state_hash"
                , Mina_base.State_hash.to_yojson
                    (Transition_frontier.Breadcrumb.state_hash breadcrumb) )
              ; ("time", `Float (Time.Span.to_ms (Time.diff diff_time start)))
              ] ;
          dispatch archive_location ~logger
            ~state_hash:(Transition_frontier.Breadcrumb.state_hash breadcrumb)
            (Transition_frontier diff) ) ;
      return () )

let run ~logger ~precomputed_values
    ~(frontier_broadcast_pipe :
       Transition_frontier.t option Broadcast_pipe.Reader.t ) archive_location =
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
               transfer ~logger ~precomputed_values ~archive_location
                 breadcrumb_reader ) ) )
