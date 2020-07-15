open Core_kernel
open Async
open Models

module Get_status =
[%graphql
{|
  query {
    genesisBlock {
      stateHash
    }
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

module Get_version =
[%graphql
{|
  query {
    version
    daemonStatus {
      peers
    }
    initialPeers
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

(* TODO: Make genesis block at height 0 see #5361 *)
let genesis_block_query =
  Caqti_request.find Caqti_type.unit Caqti_type.string
    "SELECT state_hash FROM blocks WHERE height = 1 LIMIT 1"

let oldest_block_query =
  Caqti_request.find Caqti_type.unit
    (Caqti_type.tup2 Caqti_type.int64 Caqti_type.string)
    "SELECT height, state_hash FROM blocks ORDER BY timestamp ASC LIMIT 1"

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

let validate_network_choice ~network_identifier ~gql_response =
  let open Async.Deferred.Result.Let_syntax in
  let network_tag = network_tag_of_graphql gql_response in
  let requested_tag = network_identifier.Network_identifier.network in
  if not (String.equal requested_tag network_tag) then
    Deferred.Result.fail
      (Errors.create (`Network_doesn't_exist (requested_tag, network_tag)))
  else return ()

let router ~graphql_uri ~logger ~db (route : string list) body =
  let (module Db : Caqti_async.CONNECTION) = db in
  let open Async.Deferred.Result.Let_syntax in
  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
    "Handling /network/ $route"
    ~metadata:[("route", `List (List.map route ~f:(fun s -> `String s)))] ;
  match route with
  | ["list"] ->
      let%bind _meta =
        Errors.Lift.parse ~context:"Request" @@ Metadata_request.of_yojson body
      in
      let%map res = Graphql.query (Get_network.make ()) graphql_uri in
      (* HACK: If initialPeers + peers are both empty, assume we're on debug ; otherwise testnet or devnet *)
      let network = network_tag_of_graphql res in
      Network_list_response.to_yojson
        { Network_list_response.network_identifiers=
            [ { Network_identifier.blockchain= "coda"
              ; network
              ; sub_network_identifier= None } ] }
  | ["status"] ->
      let%bind network =
        Errors.Lift.parse ~context:"Request" @@ Network_request.of_yojson body
      in
      let%bind res = Graphql.query (Get_status.make ()) graphql_uri in
      let%bind () =
        validate_network_choice ~gql_response:res
          ~network_identifier:network.network_identifier
      in
      let%bind latest_block =
        Deferred.return
          ( match res#bestChain with
          | None | Some [||] ->
              Error (Errors.create `Chain_info_missing)
          | Some chain ->
              Ok (Array.last chain) )
      in
      let genesis_block_state_hash = (res#genesisBlock)#stateHash in
      let%map oldest_block =
        Errors.Lift.sql ~context:"Oldest block query"
        @@ Db.find oldest_block_query ()
      in
      Network_status_response.to_yojson
        { Network_status_response.current_block_identifier=
            Block_identifier.create
              ((latest_block#protocolState)#consensusState)#blockHeight
              latest_block#stateHash
        ; current_block_timestamp=
            ((latest_block#protocolState)#blockchainState)#utcDate
        ; genesis_block_identifier=
            (* TODO: Also change this to zero when #5361 finishes *)
            Block_identifier.create Int64.one genesis_block_state_hash
        ; oldest_block_identifier=
            ( if String.equal (snd oldest_block) genesis_block_state_hash then
              None
            else
              Some
                (Block_identifier.create (fst oldest_block) (snd oldest_block))
            )
        ; peers=
            (res#daemonStatus)#peers |> Array.to_list
            |> List.map ~f:Peer.create }
  | ["options"] ->
      let%bind network =
        Errors.Lift.parse ~context:"Request" @@ Network_request.of_yojson body
      in
      let%bind res = Graphql.query (Get_version.make ()) graphql_uri in
      let%map () =
        validate_network_choice ~gql_response:res
          ~network_identifier:network.network_identifier
      in
      Network_options_response.to_yojson
        { Network_options_response.version=
            Version.create "1.4.0"
              (Option.value ~default:"unknown" res#version)
            (* TODO: Fill in allow field *)
        ; allow=
            { Allow.operation_statuses= []
            ; operation_types= []
            ; errors= []
            ; historical_balance_lookup= false } }
  | _ ->
      Deferred.Result.fail `Page_not_found
