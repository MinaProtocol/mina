open Core_kernel
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
    initialPeers
  }
|}]

module Get_version = [%graphql {|
  query {
    version
  }
|}]

module Get_network =
[%graphql
{|
  query {
    daemonStatus {
      peers
    }
    initialPeers
  }
|}]

let genesis_block_query =
  Caqti_request.find Caqti_type.unit Caqti_type.string
    "SELECT state_hash FROM blocks WHERE height = 1 LIMIT 1"

let network_tag_of_graphql res =
  match res#initialPeers with
  | [||] ->
      if Array.is_empty (res#daemonStatus)#peers then "debug" else "testnet"
  | peers ->
      if
        Array.filter peers ~f:(fun p ->
            String.is_substring ~substring:"dev.o1test.net" p )
        |> Array.is_empty
      then "testnet"
      else "dev"

let router ~graphql_uri ~logger ~db (route : string list) body =
  let (module Db : Caqti_async.CONNECTION) = db in
  let open Async.Deferred.Result.Let_syntax in
  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
    "Handling /network/ $route"
    ~metadata:[("route", `List (List.map route ~f:(fun s -> `String s)))] ;
  match route with
  | ["list"] ->
      let%bind _meta = Errors.map_parse @@ Metadata_request.of_yojson body in
      let%map res = Graphql.query (Get_network.make ()) graphql_uri in
      (* HACK: If initialPeers + peers are both empty, assume we're on debug ; otherwise testnet or devnet *)
      let network = network_tag_of_graphql res in
      Network_list_response.to_yojson
        { Network_list_response.network_identifiers=
            [ { Network_identifier.blockchain= "coda"
              ; network
              ; sub_network_identifier= None } ] }
  | ["status"] ->
      let%bind network = Errors.map_parse @@ Network_request.of_yojson body in
      let%bind res = Graphql.query (Get_status.make ()) graphql_uri in
      let network_tag = network_tag_of_graphql res in
      let requested_tag = network.Network_request.network_identifier.network in
      let%bind () =
        if not (String.equal requested_tag network_tag) then
          Deferred.Result.fail
            (Errors.create ~retriable:false
               (Core_kernel.sprintf
                  !"You are requesting the status for the network %s but you \
                    are connected to the network %s\n"
                  requested_tag network_tag))
        else return ()
      in
      let%bind latest_block =
        Deferred.return
          ( match res#bestChain with
          | None | Some [||] ->
              Error
                (Errors.create
                   "Could not get chain information. This probably means you \
                    are bootstrapping -- bootstrapping is the process of \
                    synchronizing with peers that are way ahead of you on the \
                    chain. Try again in a few seconds.")
          | Some chain ->
              Ok (Array.last chain) )
      in
      let%map genesis_block_state_hash =
        Errors.map_sql @@ Db.find genesis_block_query ()
      in
      Network_status_response.to_yojson
        { Network_status_response.current_block_identifier=
            Block_identifier.create
              ((latest_block#protocolState)#consensusState)#blockHeight
              latest_block#stateHash
        ; current_block_timestamp=
            ((latest_block#protocolState)#blockchainState)#utcDate
        ; genesis_block_identifier=
            Block_identifier.create Int64.zero genesis_block_state_hash
        ; peers=
            (res#daemonStatus)#peers |> Array.to_list
            |> List.map ~f:Peer.create }
  | ["options"] ->
      let%bind _network = Errors.map_parse @@ Network_request.of_yojson body in
      let%map res = Graphql.query (Get_version.make ()) graphql_uri in
      Network_options_response.to_yojson
        { Network_options_response.version=
            Version.create "1.4.0"
              (Option.value ~default:"unknown" res#version)
            (* TODO: Fill in allow field *)
        ; allow= {Allow.operation_statuses= []; operation_types= []; errors= []}
        }
  | _ ->
      Deferred.return (Error `Page_not_found)
