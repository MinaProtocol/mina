open Core
open Async
open Models

let make_error ?(code = 400) ?(retriable = true) message =
  `Error {Models.Error.code= Int32.of_int_exn code; message; retriable}

let handle_parse res = Deferred.return (Result.map_error ~f:make_error res)

let router ~graphql_uri route body =
  print_endline graphql_uri ;
  let open Async.Deferred.Result.Let_syntax in
  match route with
  | ["list"] ->
      let%map _meta = handle_parse @@ Metadata_request.of_yojson body in
      Network_list_response.to_yojson
        { Network_list_response.network_identifiers=
            [ { Network_identifier.blockchain= "coda"
              ; network= "testnet"
              ; sub_network_identifier= None } ] }
  | ["status"] ->
      let%map _network = handle_parse @@ Network_request.of_yojson body in
      Network_status_response.to_yojson
        { Network_status_response.current_block_identifier=
            Block_identifier.create Int64.one "???"
        ; current_block_timestamp= Int64.one
        ; genesis_block_identifier= Block_identifier.create Int64.one "???"
        ; peers= [] }
  | ["options"] ->
      let%map _network = handle_parse @@ Network_request.of_yojson body in
      Network_options_response.to_yojson
        { Network_options_response.version= Version.create "1.3.1" "???"
        ; allow= {Allow.operation_statuses= []; operation_types= []; errors= []}
        }
  | _ ->
      Deferred.return (Error `Page_not_found)
