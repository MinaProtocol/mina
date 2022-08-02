open Base
module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema

let sync_status () : ('context, Sync_status.t option) typ =
  enum "SyncStatus" ~doc:"Sync status of daemon"
    ~values:
    (List.map Sync_status.all ~f:(fun status ->
         enum_value
           (String.map ~f:Char.uppercase @@ Sync_status.to_string status)
           ~value:status ) )
