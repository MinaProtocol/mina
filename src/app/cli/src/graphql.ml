open Core
open Async
open Graphql_async
open Schema
open Pipe_lib

module Make (Program : Coda_inputs.Main_intf) = struct
  open Program
  open Inputs

  module Types = struct
    let sync_status : ('context, [`Offline | `Synced | `Bootstrap]) typ =
      non_null
        (enum "sync_status" ~doc:"Sync status as daemon node"
           ~values:
             [ enum_value "BOOTSTRAP" ~value:`Bootstrap
             ; enum_value "SYNCED" ~value:`Synced
             ; enum_value "OFFLINE" ~value:`Offline ])
  end

  module Queries = struct
    open Types

    let sync_state =
      io_field "sync_status" ~typ:sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} () ->
          Deferred.return
            (Inputs.Incr_status.Observer.value @@ Program.sync_status coda)
          >>| Result.map_error ~f:Error.to_string_hum )

    let commands = [sync_state]
  end

  module Subscriptions = struct
    let to_pipe observer =
      let reader, writer =
        Strict_pipe.(create (Buffered (`Capacity 1, `Overflow Drop_head)))
      in
      Incr_status.Observer.on_update_exn observer ~f:(function
        | Initialized value ->
            Strict_pipe.Writer.write writer value
        | Changed (_, value) ->
            Strict_pipe.Writer.write writer value
        | Invalidated ->
            () ) ;
      (Strict_pipe.Reader.to_linear_pipe reader).Linear_pipe.Reader.pipe

    let new_sync_update =
      subscription_field "new_sync_update"
        ~doc:"Subscripts on sync update from Coda" ~deprecated:NotDeprecated
        ~typ:Types.sync_status
        ~args:Arg.[]
        ~resolve:(fun {ctx= coda; _} ->
          Program.sync_status coda |> to_pipe |> Deferred.Result.return )

    let commands = [new_sync_update]
  end

  let schema =
    Graphql_async.Schema.(
      schema Queries.commands ~subscriptions:Subscriptions.commands)
end
