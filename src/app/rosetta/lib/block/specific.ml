open Core_kernel
open Async
open Rosetta_lib
open Rosetta_models
open Rosetta_graphql

module Env = struct
  (* All side-effects go in the env so we can mock them out later *)
  module T (M : Monad_fail.S) = struct
    type 'gql t =
      { gql : unit -> ('gql, Errors.t) M.t
      ; logger : Logger.t
      ; db_block : Block_query.t -> (Block_info.t, Errors.t) M.t
      ; validate_network_choice :
             network_identifier:Network_identifier.t
          -> graphql_uri:Uri.t
          -> (unit, Errors.t) M.t
      }
  end

  (* The real environment does things asynchronously *)
  module Real = T (Deferred.Result)

  (* But for tests, we want things to go fast *)
  module Mock = T (Result)

  let real :
         logger:Logger.t
      -> db:(module Caqti_async.CONNECTION)
      -> graphql_uri:Uri.t
      -> 'gql Real.t =
   fun ~logger ~db ~graphql_uri ->
    { gql =
        ( Memoize.build
        @@ fun ~graphql_uri () ->
        Graphql.query (Get_coinbase_and_genesis.make ()) graphql_uri )
          ~graphql_uri
    ; logger
    ; db_block =
        (fun query ->
          let (module Conn : Caqti_async.CONNECTION) = db in
          Sql.run (module Conn) query )
    ; validate_network_choice = Network.Validate_choice.Real.validate
    }

  let mock : logger:Logger.t -> 'gql Mock.t =
   fun ~logger ->
    { gql =
        (fun () ->
          Result.return
          @@ object
               method genesisBlock =
                 object
                   method stateHash = "STATE_HASH_GENESIS"
                 end
             end )
        (* TODO: Add variants to cover every branch *)
    ; logger
    ; db_block = (fun _query -> Result.return @@ Block_info.dummy)
    ; validate_network_choice = Network.Validate_choice.Mock.succeed
    }
end

module Impl (M : Monad_fail.S) = struct
  module Query = Block_query.T (M)
  module Internal_command_info_ops = Internal_command_info.T (M)

  let handle :
         graphql_uri:Uri.t
      -> env:'gql Env.T(M).t
      -> Block_request.t
      -> (Block_response.t, Errors.t) M.t =
   fun ~graphql_uri ~env req ->
    let open M.Let_syntax in
    let logger = env.logger in
    let%bind query = Query.of_partial_identifier req.block_identifier in
    let%bind res = env.gql () in
    let%bind () =
      env.validate_network_choice ~network_identifier:req.network_identifier
        ~graphql_uri
    in
    let genesisBlock = res.Get_coinbase_and_genesis.genesisBlock in
    let block_height =
      genesisBlock.protocolState.consensusState.blockHeight
      |> Unsigned.UInt32.to_int64
    in
    let%bind block_info =
      if Query.is_genesis ~block_height ~hash:genesisBlock.stateHash query then
        let genesis_block_identifier =
          { Block_identifier.index = block_height
          ; hash = genesisBlock.stateHash
          }
        in
        M.return
          { Block_info.block_identifier =
              genesis_block_identifier
              (* parent_block_identifier for genesis block should be the same as block identifier as described https://www.rosetta-api.org/docs/common_mistakes.html.correct-example *)
          ; parent_block_identifier = genesis_block_identifier
          ; creator = `Pk genesisBlock.creatorAccount.publicKey
          ; winner = `Pk genesisBlock.winnerAccount.publicKey
          ; timestamp =
              Int64.of_string genesisBlock.protocolState.blockchainState.date
          ; internal_info = []
          ; user_commands = []
          ; zkapp_commands = []
          ; zkapps_account_updates = []
          }
      else env.db_block query
    in
    let coinbase_receiver =
      List.find block_info.internal_info ~f:(fun info ->
          Internal_command_info.Kind.equal info.Internal_command_info.kind
            `Coinbase )
      |> Option.map ~f:(fun cmd -> cmd.Internal_command_info.receiver)
    in
    let%map internal_transactions =
      List.fold block_info.internal_info ~init:(M.return [])
        ~f:(fun macc info ->
          let%bind acc = macc in
          let%map operations =
            Internal_command_info_ops.to_operations ~coinbase_receiver info
          in
          [%log debug]
            ~metadata:[ ("info", Internal_command_info.to_yojson info) ]
            "Block internal received $info" ;
          { Transaction.transaction_identifier =
              (* prepend the sequence number, secondary sequence number and kind to the transaction hash
                 duplicate hashes are possible in the archive database, with differing
                 "type" fields, which correspond to the "kind" here
              *)
              { Transaction_identifier.hash =
                  sprintf "%s:%s:%s:%s"
                    (Internal_command_info.Kind.to_string info.kind)
                    (Int.to_string info.sequence_no)
                    (Int.to_string info.secondary_sequence_no)
                    info.hash
              }
          ; operations
          ; metadata = None
          }
          :: acc )
      |> M.map ~f:List.rev
    in
    { Block_response.block =
        Some
          { Rosetta_models.Block.block_identifier = block_info.block_identifier
          ; parent_block_identifier = block_info.parent_block_identifier
          ; timestamp = block_info.timestamp
          ; transactions =
              internal_transactions
              @ List.map block_info.user_commands ~f:(fun info ->
                    [%log debug]
                      ~metadata:[ ("info", User_command_info.to_yojson info) ]
                      "Block user received $info" ;
                    { Transaction.transaction_identifier =
                        { Transaction_identifier.hash = info.hash }
                    ; operations = User_command_info.to_operations' info
                    ; metadata =
                        Option.bind info.memo ~f:(fun base58_check ->
                            try
                              let memo =
                                let open Mina_base.Signed_command_memo in
                                base58_check |> of_base58_check_exn
                                |> to_string_hum
                              in
                              if String.is_empty memo then None
                              else Some (`Assoc [ ("memo", `String memo) ])
                            with _ -> None )
                    } )
          ; metadata = Some (Block_info.creator_metadata block_info)
          }
    ; other_transactions = []
    }
end

module Real = Impl (Deferred.Result)

let%test_module "blocks" =
  ( module struct
    module Mock = Impl (Result)

    (* This test intentionally fails as there has not been time to implement
     * it properly yet *)
    (*
      let%test_unit "all dummies" =
        Test.assert_ ~f:Block_response.to_yojson
          ~expected:
            (Mock.handle ~env:Env.mock
               (Block_request.create
                  (Network_identifier.create "x" "y")
                  (Partial_block_identifier.create ())))
          ~actual:(Result.fail (Errors.create (`Json_parse None)))
    *)
  end )
