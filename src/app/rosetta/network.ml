open Core
open Async
open Models

module Get_status =
[%graphql
{|
  query {
    bestChain {
      stateHash
      protocolState {
        blockchainState {
          utcDate @bsDecoder(fn: "Int64.of_string")
        }
        consensusState {
          blockHeight @bsDecoder(fn: "Graphql.Decoders.int64")
        }
      }
    }
    daemonStatus {
      peers
    }
  }
|}]

module Get_version = [%graphql {|
  query {
    version
  }
|}]

let map_parse res = Deferred.return (Result.map_error ~f:Errors.create res)

let router ~graphql_uri route body =
  let open Async.Deferred.Result.Let_syntax in
  match route with
  | ["list"] ->
      let%map _meta = map_parse @@ Metadata_request.of_yojson body in
      Network_list_response.to_yojson
        { Network_list_response.network_identifiers=
            [ { Network_identifier.blockchain= "coda"
              ; network= "testnet"
              ; sub_network_identifier= None } ] }
  | ["status"] ->
      let%bind _network = map_parse @@ Network_request.of_yojson body in
      let%bind res = Graphql.query (Get_status.make ()) graphql_uri in
      let%map latest_block =
        Deferred.return
          ( match res#bestChain with
          | Some [||] ->
              Error (Errors.create "No blocks in chain")
          | Some chain ->
              Ok chain.(0)
          | None ->
              Error (Errors.create "Could not get chain information") )
      in
      Network_status_response.to_yojson
        { Network_status_response.current_block_identifier=
            Block_identifier.create
              ((latest_block#protocolState)#consensusState)#blockHeight
              latest_block#stateHash
        ; current_block_timestamp=
            ((latest_block#protocolState)#blockchainState)#utcDate
        ; genesis_block_identifier= Block_identifier.create Int64.one "???"
        ; peers=
            (res#daemonStatus)#peers |> Array.to_list
            |> List.map ~f:Peer.create }
  | ["options"] ->
      let%bind _network = map_parse @@ Network_request.of_yojson body in
      let%map res = Graphql.query (Get_version.make ()) graphql_uri in
      Network_options_response.to_yojson
        { Network_options_response.version=
            Version.create "1.3.1"
              (Option.value ~default:"unknown" res#version)
        ; allow= {Allow.operation_statuses= []; operation_types= []; errors= []}
        }
  | _ ->
      Deferred.return (Error `Page_not_found)
