module Serializing = Graphql_lib.Serializing
module Scalars = Graphql_lib.Scalars

module Get_genesis_block_identifier =
[%graphql
{|
  query {
    genesisBlock {
      stateHash @ppxCustom(module: "Scalars.String_json")
      protocolState {
        consensusState {
          blockHeight
        }
      }
    }
  }
|}]

module Get_status =
[%graphql
{|
  query {
    bestChain(maxLength: 1) {
      stateHash @ppxCustom(module: "Scalars.String_json")
      protocolState {
        blockchainState {
          utcDate @ppxCustom(module: "Serializing.Int64")
        }
        consensusState {
          blockHeight @ppxCustom(module: "Serializing.Int64")
        }
      }
    }
    daemonStatus {
      peers { peerId }
    }
    syncStatus
    initialPeers
    networkID
  }
|}]

(** Open after GraphQL query, to avoid shadowing functions used by the PPX *)
open Core_kernel

open Async
open Rosetta_lib
open Rosetta_models

module Get_status_t = struct
  type t =
    { genesis_block_identifier : Get_genesis_block_identifier.t
    ; status : Get_status.t
    }

  module Get_genesis_block_identifier_memoized = struct
    let query =
      Memoize.build
      @@ fun ~graphql_uri () ->
      Graphql.query
        Get_genesis_block_identifier.(make @@ makeVariables ())
        graphql_uri
  end

  let query ~graphql_uri () =
    let open Deferred.Result.Let_syntax in
    let%bind genesis_block_identifier =
      Get_genesis_block_identifier_memoized.query ~graphql_uri ()
    in
    let%map status =
      Graphql.query Get_status.(make @@ makeVariables ()) graphql_uri
    in
    { genesis_block_identifier; status }
end

module Sql = struct
  let oldest_block_query =
    Caqti_request.find Caqti_type.unit
      Caqti_type.(tup2 int64 string)
      "SELECT height, state_hash FROM blocks ORDER BY timestamp ASC, \
       state_hash ASC LIMIT 1"

  let max_height_delta =
    match Sys.getenv "MINA_ROSETTA_MAX_HEIGHT_DELTA" with
    | Some n ->
        Int64.of_string n
    | None ->
        0L

  let latest_block_query =
    Caqti_request.find Caqti_type.unit
      Caqti_type.(tup3 int64 string int64)
      (sprintf
         {sql| SELECT height, state_hash, timestamp FROM blocks b
                     WHERE height = (select MAX(height) - %Ld FROM blocks)
                     ORDER BY timestamp ASC, state_hash ASC
                     LIMIT 1
               |sql}
         max_height_delta )
end

let sync_status_to_string = function
  | `BOOTSTRAP ->
      "Bootstrap"
  | `CATCHUP ->
      "Catchup"
  | `CONNECTING ->
      "Connecting"
  | `LISTENING ->
      "Listening"
  | `OFFLINE ->
      "Offline"
  | `SYNCED ->
      "Synced"

let is_synced = function
  | `SYNCED ->
      true
  | `BOOTSTRAP | `CATCHUP | `CONNECTING | `LISTENING | `OFFLINE ->
      false

module Get_version = [%graphql {|
  query {
    version
  }
|}]

module Get_network = [%graphql {|
  query {
    networkID
  }
|}]

module Get_network_memoized = struct
  let query =
    Memoize.build
    @@ fun ~graphql_uri () ->
    Graphql.query Get_network.(make @@ makeVariables ()) graphql_uri
end

module Validate_choice = struct
  module Real = struct
    let validate ~network_identifier ~graphql_uri =
      let open Deferred.Result.Let_syntax in
      let%bind gql_response = Get_network_memoized.query ~graphql_uri () in
      let network_tag = gql_response.networkID in
      let requested_tag =
        Format.sprintf "%s:%s" network_identifier.Network_identifier.blockchain
          network_identifier.Network_identifier.network
      in
      if not (String.equal network_tag requested_tag) then
        Deferred.Result.fail
          (Errors.create (`Network_doesn't_exist (requested_tag, network_tag)))
      else Deferred.Result.return ()
  end

  module Mock = struct
    let succeed ~network_identifier:_ ~graphql_uri:_ = Result.return ()
  end
end

module List_ = struct
  module Env = struct
    module Make (M : Monad_fail.S) = struct
      type t = unit -> (string, Errors.t) M.t
    end

    module Real = Make (Deferred.Result)

    let real ~graphql_uri : Real.t =
     fun () ->
      let open Deferred.Result.Let_syntax in
      let%map resp = Get_network_memoized.query ~graphql_uri () in
      resp.networkID
  end

  module Impl (M : Monad_fail.S) = struct
    let handle ~(env : Env.Make(M).t) =
      let open M.Let_syntax in
      let%bind network_tag = env () in
      match String.split ~on:':' network_tag with
      | [ blockchain; network ] ->
          return
            { Network_list_response.network_identifiers =
                [ { Network_identifier.blockchain
                  ; network
                  ; sub_network_identifier = None
                  }
                ]
            }
      | _ ->
          M.fail (Errors.create (`Graphql_mina_query "Invalid network tag"))
  end

  module Real = Impl (Deferred.Result)
end

let dummy_network_request =
  Network_request.create (Network_identifier.create "x" "y")

module Status = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql : unit -> ('gql, Errors.t) M.t
        ; db_oldest_block : unit -> (int64 * string, Errors.t) M.t
        ; db_latest_block : unit -> (int64 * string * int64, Errors.t) M.t
        ; validate_network_choice :
               network_identifier:Network_identifier.t
            -> graphql_uri:Uri.t
            -> (unit, Errors.t) M.t
        }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let oldest_block_ref = ref None

    let real :
        db:(module Caqti_async.CONNECTION) -> graphql_uri:Uri.t -> 'gql Real.t =
     fun ~db ~graphql_uri ->
      let (module Db : Caqti_async.CONNECTION) = db in
      { gql = Get_status_t.query ~graphql_uri
      ; db_oldest_block =
          (fun () ->
            match !oldest_block_ref with
            | Some oldest_block ->
                Deferred.Result.return oldest_block
            | None ->
                let%map result =
                  Errors.Lift.sql ~context:"Oldest block query"
                  @@ Db.find Sql.oldest_block_query ()
                in
                Result.iter result ~f:(fun oldest_block ->
                    oldest_block_ref := Some oldest_block ) ;
                result )
      ; db_latest_block =
          (fun () ->
            Errors.Lift.sql ~context:"Latest db block query"
            @@ Db.find Sql.latest_block_query () )
      ; validate_network_choice = Validate_choice.Real.validate
      }
  end

  module Impl (M : Monad_fail.S) = struct
    let handle ~graphql_uri ~(env : 'gql Env.T(M).t)
        (network : Network_request.t) =
      let open M.Let_syntax in
      let%bind res = env.gql () in
      let%bind () =
        env.validate_network_choice ~graphql_uri
          ~network_identifier:network.network_identifier
      in
      let%bind latest_node_block =
        match res.Get_status_t.status.bestChain with
        | None | Some [||] ->
            M.fail (Errors.create `Chain_info_missing)
        | Some chain ->
            M.return (Array.last chain)
      in
      let genesis_block_height =
        res.genesis_block_identifier.genesisBlock.protocolState.consensusState
          .blockHeight |> Unsigned.UInt32.to_int64
      in
      let genesis_block_state_hash =
        res.genesis_block_identifier.genesisBlock.stateHash
      in
      let%bind ( latest_db_block_height
               , latest_db_block_hash
               , latest_db_block_timestamp ) =
        env.db_latest_block ()
      in
      let%map oldest_db_block_height, oldest_db_block_hash =
        env.db_oldest_block ()
      in
      { Network_status_response.current_block_identifier =
          Block_identifier.create latest_db_block_height latest_db_block_hash
      ; current_block_timestamp = latest_db_block_timestamp
      ; genesis_block_identifier =
          Block_identifier.create genesis_block_height genesis_block_state_hash
      ; oldest_block_identifier =
          ( if String.equal oldest_db_block_hash genesis_block_state_hash then
            None
          else
            Some
              (Block_identifier.create oldest_db_block_height
                 oldest_db_block_hash ) )
      ; peers =
          (let peer_objs = res.status.daemonStatus.peers |> Array.to_list in
           List.map peer_objs ~f:(fun po -> po.peerId |> Peer.create) )
      ; sync_status =
          Some
            { Sync_status.current_index =
                Some latest_node_block.protocolState.consensusState.blockHeight
            ; target_index = None
            ; stage = Some (sync_status_to_string res.status.syncStatus)
            ; synced = Some (is_synced res.status.syncStatus)
            }
      }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "status" =
    ( module struct
      module Mock = Impl (Result)

      let build ~best_chain_missing =
        { Get_status_t.genesis_block_identifier =
            { genesisBlock =
                { stateHash = "GENESIS_HASH"
                ; protocolState =
                    { consensusState = { blockHeight = Unsigned.UInt32.one } }
                }
            }
        ; status =
            { bestChain =
                ( if best_chain_missing then None
                else
                  Some
                    [| { stateHash = "STATE_HASH_TIP"
                       ; protocolState =
                           { blockchainState =
                               { utcDate = Int64.of_int_exn 1_594_854_566 }
                           ; consensusState =
                               { blockHeight = Int64.of_int_exn 4 }
                           }
                       }
                    |] )
            ; daemonStatus = { peers = [| { peerId = "dev.o1test.net" } |] }
            ; syncStatus = `SYNCED
            ; initialPeers = [||]
            ; networkID = "mina:testnet"
            }
        }

      let no_chain_info_env : 'gql Env.Mock.t =
        { gql = (fun () -> Result.return @@ build ~best_chain_missing:true)
        ; validate_network_choice = Validate_choice.Mock.succeed
        ; db_oldest_block =
            (fun () -> Result.return (Int64.of_int_exn 1, "GENESIS_HASH"))
        ; db_latest_block =
            (fun () ->
              Result.return
                (Int64.max_value, "LATEST_BLOCK_HASH", Int64.max_value) )
        }

      let%test_unit "chain info missing" =
        Test.assert_ ~f:Network_status_response.to_yojson
          ~actual:
            (Mock.handle
               ~graphql_uri:(Uri.of_string "https://minaprotocol.com")
               ~env:no_chain_info_env dummy_network_request )
          ~expected:(Result.fail (Errors.create `Chain_info_missing))

      let oldest_block_is_genesis_env : 'gql Env.Mock.t =
        { gql = (fun () -> Result.return @@ build ~best_chain_missing:false)
        ; validate_network_choice = Validate_choice.Mock.succeed
        ; db_oldest_block =
            (fun () -> Result.return (Int64.of_int_exn 1, "GENESIS_HASH"))
        ; db_latest_block =
            (fun () ->
              Result.return
                (Int64.of_int_exn 4, "LATEST_BLOCK_HASH", Int64.max_value) )
        }

      let%test_unit "oldest block is genesis" =
        Test.assert_ ~f:Network_status_response.to_yojson
          ~actual:
            (Mock.handle
               ~graphql_uri:(Uri.of_string "https://minaprotocol.com")
               ~env:oldest_block_is_genesis_env dummy_network_request )
          ~expected:
            ( Result.return
            @@ { Network_status_response.current_block_identifier =
                   { Block_identifier.index = Int64.of_int_exn 4
                   ; hash = "LATEST_BLOCK_HASH"
                   }
               ; current_block_timestamp = Int64.max_value
               ; genesis_block_identifier =
                   { Block_identifier.index = Int64.of_int_exn 1
                   ; hash = "GENESIS_HASH"
                   }
               ; peers =
                   [ { Peer.peer_id = "dev.o1test.net"; metadata = None } ]
               ; oldest_block_identifier = None
               ; sync_status =
                   Some
                     { Sync_status.current_index = Some (Int64.of_int_exn 4)
                     ; target_index = None
                     ; stage = Some "Synced"
                     ; synced = Some true
                     }
               } )

      let oldest_block_is_different_env : 'gql Env.Mock.t =
        { gql = (fun () -> Result.return @@ build ~best_chain_missing:false)
        ; validate_network_choice = Validate_choice.Mock.succeed
        ; db_oldest_block =
            (fun () -> Result.return (Int64.of_int_exn 3, "SOME_HASH"))
        ; db_latest_block =
            (fun () ->
              Result.return
                (Int64.of_int_exn 10000, "ANOTHER_HASH", Int64.of_int_exn 20000)
              )
        }

      let%test_unit "oldest block is different" =
        Test.assert_ ~f:Network_status_response.to_yojson
          ~actual:
            (Mock.handle
               ~graphql_uri:(Uri.of_string "https://minaprotocol.com")
               ~env:oldest_block_is_different_env dummy_network_request )
          ~expected:
            ( Result.return
            @@ { Network_status_response.current_block_identifier =
                   { Block_identifier.index = Int64.of_int_exn 10_000
                   ; hash = "ANOTHER_HASH"
                   }
               ; current_block_timestamp = Int64.of_int_exn 20_000
               ; genesis_block_identifier =
                   { Block_identifier.index = Int64.of_int_exn 1
                   ; hash = "GENESIS_HASH"
                   }
               ; peers =
                   [ { Peer.peer_id = "dev.o1test.net"; metadata = None } ]
               ; oldest_block_identifier =
                   Some
                     { Block_identifier.index = Int64.of_int_exn 3
                     ; hash = "SOME_HASH"
                     }
               ; sync_status =
                   Some
                     { Sync_status.current_index = Some (Int64.of_int_exn 4)
                     ; target_index = None
                     ; stage = Some "Synced"
                     ; synced = Some true
                     }
               } )
    end )
end

module Options = struct
  module Impl (M : Monad_fail.S) = struct
    (* Currently, mainnet, testnet, devnet etc don't affect Rosetta options *)
    let handle (_network : Network_request.t) =
      M.return
      @@ { Network_options_response.version = Version.create "1.4.9" "1.0.0"
         ; allow =
             { Allow.operation_statuses = Lazy.force Operation_statuses.all
             ; operation_types = Lazy.force Operation_types.all
             ; errors = Lazy.force Errors.all_errors
             ; historical_balance_lookup =
                 true
                 (* TODO: #6872 We should expose info for the timestamp_start_index via GraphQL then consume it here *)
             ; timestamp_start_index =
                 None
                 (* If we implement the /call endpoint we'll need to list its supported methods here *)
             ; call_methods = []
             ; balance_exemptions = []
             ; mempool_coins = false
             ; block_hash_case = Some `Case_sensitive
             ; transaction_hash_case = Some `Case_sensitive
             }
         }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "options" =
    ( module struct
      module Mock = Impl (Result)

      let%test_unit "options succeeds" =
        Test.assert_ ~f:Network_options_response.to_yojson
          ~actual:(Mock.handle dummy_network_request)
          ~expected:
            ( Result.return
            @@ { Network_options_response.version =
                   Version.create "1.4.9" "1.0.0"
               ; allow =
                   { Allow.operation_statuses =
                       Lazy.force Operation_statuses.all
                   ; operation_types = Lazy.force Operation_types.all
                   ; errors = Lazy.force Errors.all_errors
                   ; historical_balance_lookup = true
                   ; timestamp_start_index = None
                   ; call_methods = []
                   ; balance_exemptions = []
                   ; mempool_coins = false
                   ; block_hash_case = Some `Case_sensitive
                   ; transaction_hash_case = Some `Case_sensitive
                   }
               } )
    end )
end

let router ~get_graphql_uri_or_error ~logger ~with_db (route : string list) body
    =
  let open Async.Deferred.Result.Let_syntax in
  [%log debug] "Handling /network/ $route"
    ~metadata:[ ("route", `List (List.map route ~f:(fun s -> `String s))) ] ;
  [%log info] "Network query" ~metadata:[ ("query", body) ] ;
  match route with
  | [ "list" ] ->
      let%bind graphql_uri = get_graphql_uri_or_error () in
      let%bind _meta =
        Errors.Lift.parse ~context:"Request" @@ Metadata_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        List_.Real.handle ~env:(List_.Env.real ~graphql_uri) |> Errors.Lift.wrap
      in
      Network_list_response.to_yojson res
  | [ "status" ] ->
      let%bind graphql_uri = get_graphql_uri_or_error () in
      let%bind network =
        Errors.Lift.parse ~context:"Request" @@ Network_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%bind res =
        with_db (fun ~db ->
            Status.Real.handle ~graphql_uri
              ~env:(Status.Env.real ~graphql_uri ~db)
              network
            |> Errors.Lift.wrap )
      in
      return @@ Network_status_response.to_yojson res
  | [ "options" ] ->
      let%bind network =
        Errors.Lift.parse ~context:"Request" @@ Network_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res = Options.Real.handle network |> Errors.Lift.wrap in
      Network_options_response.to_yojson res
  | _ ->
      Deferred.Result.fail `Page_not_found
