open Core
open Graphql_async

type context_typ = Mina_lib.t

open Schema

let sync_status : (context_typ, Sync_status.t option) typ =
  enum "SyncStatus" ~doc:"Sync status of daemon"
    ~values:
      (List.map Sync_status.all ~f:(fun status ->
           enum_value
             (String.map ~f:Char.uppercase @@ Sync_status.to_string status)
             ~value:status))
