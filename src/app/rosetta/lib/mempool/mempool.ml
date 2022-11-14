module Scalars = Graphql_lib.Scalars
module Serializing = Graphql_lib.Serializing

module Get_all_transactions =
[%graphql
{|
    query all_transactions {
      initialPeers
      daemonStatus {
        chainId
      }
      pooledUserCommands(publicKey: null) {
        hash @ppxCustom(module: "Scalars.String_json")
      }
    }
|}]

module Get_transactions_by_hash =
[%graphql
{|
    query all_transactions_by_hash($hashes: [String!]) {
      initialPeers
      daemonStatus {
        chainId
        peers { host }
      }
      pooledUserCommands(hashes: $hashes) {
        hash @ppxCustom(module: "Scalars.String_json")
        amount @ppxCustom(module: "Scalars.UInt64")
        fee @ppxCustom(module: "Scalars.UInt64")
        kind
        feeToken @ppxCustom(module: "Serializing.Token_s")
        validUntil @ppxCustom(module: "Scalars.UInt32")
        memo
        feePayer {
          publicKey @ppxCustom(module: "Scalars.JSON")
        }
        nonce
        receiver {
          publicKey @ppxCustom(module: "Scalars.JSON")
        }
        source {
          publicKey @ppxCustom(module: "Scalars.JSON")
        }
        token @ppxCustom(module: "Serializing.Token_s")
      }
    }
|}]

(* Avoid shadowing graphql_ppx functions *)
open Core_kernel
open Async
open Rosetta_lib
open Rosetta_models
open Rosetta_graphql

module All = struct
  module Env = struct
    (* All side-effects go in the env so we can mock them out later *)
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql : unit -> ('gql, Errors.t) M.t
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

    let real : graphql_uri:Uri.t -> 'gql Real.t =
     fun ~graphql_uri ->
      { gql =
          (fun () -> Graphql.query (Get_all_transactions.make ()) graphql_uri)
      ; validate_network_choice = Network.Validate_choice.Real.validate
      }

    let mock : 'gql Mock.t =
      { gql =
          (fun () ->
            Result.return
              { Get_all_transactions.pooledUserCommands =
                  [| { hash = "TXN_1" }; { hash = "TXN_2" } |]
              ; initialPeers = [||]
              ; daemonStatus = { chainId = "dummy" }
              } )
      ; validate_network_choice = Network.Validate_choice.Mock.succeed
      }
  end

  module Impl (M : Monad_fail.S) = struct
    let handle :
           graphql_uri:Uri.t
        -> env:'gql Env.T(M).t
        -> Network_request.t
        -> (Mempool_response.t, Errors.t) M.t =
     fun ~graphql_uri ~env req ->
      let open M.Let_syntax in
      let%bind res = env.gql () in
      let%map () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~graphql_uri
      in
      let open Get_all_transactions in
      { Mempool_response.transaction_identifiers =
          res.pooledUserCommands |> Array.to_list
          |> List.map ~f:(fun cmd -> { Transaction_identifier.hash = cmd.hash })
      }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "mempool all" =
    ( module struct
      module Mock = Impl (Result)

      let%test_unit "succeeds" =
        Test.assert_ ~f:Mempool_response.to_yojson
          ~expected:
            (Mock.handle
               ~graphql_uri:(Uri.of_string "https://minaprotocol.com")
               ~env:Env.mock Network.dummy_network_request )
          ~actual:
            (Result.return
               { Mempool_response.transaction_identifiers =
                   [ { Transaction_identifier.hash = "TXN_1" }
                   ; { Transaction_identifier.hash = "TXN_2" }
                   ]
               } )
    end )
end

module Transaction = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql : hash:string -> ('gql, Errors.t) M.t
        ; validate_network_choice :
               network_identifier:Network_identifier.t
            -> graphql_uri:Uri.t
            -> (unit, Errors.t) M.t
        }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : graphql_uri:Uri.t -> 'gql Real.t =
     fun ~graphql_uri ->
      { gql =
          (fun ~hash ->
            Graphql.query
              Get_transactions_by_hash.(
                make @@ makeVariables ~hashes:[| hash |] ())
              graphql_uri )
      ; validate_network_choice = Network.Validate_choice.Real.validate
      }

    let obj_of_user_command_info (user_command_info : User_command_info.t) =
      object
        method hash = user_command_info.hash

        method amount =
          Option.value ~default:Unsigned.UInt64.zero user_command_info.amount

        method fee = user_command_info.fee

        method kind =
          match user_command_info.kind with
          | `Payment ->
              `String "PAYMENT"
          | `Delegation ->
              `String "STAKE_DELEGATION"

        method feeToken = user_command_info.fee_token

        method feePayer =
          object
            method publicKey =
              let (`Pk p) = user_command_info.fee_payer in
              `String p
          end

        method nonce = Unsigned.UInt32.to_int user_command_info.nonce

        method receiver =
          object
            method publicKey =
              let (`Pk p) = user_command_info.receiver in
              `String p
          end

        method source =
          object
            method publicKey =
              let (`Pk p) = user_command_info.source in
              `String p
          end

        method token = user_command_info.token
      end

    let mock : 'gql Mock.t =
      { gql =
          (fun ~hash:_ ->
            Result.return
            @@ object
                 method pooledUserCommands =
                   User_command_info.dummies
                   |> List.map ~f:(fun info ->
                          `UserCommand (obj_of_user_command_info info) )
                   |> List.to_array
               end )
      ; validate_network_choice = Network.Validate_choice.Mock.succeed
      }
  end

  module Impl (M : Monad_fail.S) = struct
    let user_command_info_of_obj obj =
      let open M.Let_syntax in
      let extract_public_key data =
        match data with
        | `String pk ->
            M.return (`Pk pk)
        | x ->
            M.fail
              (Errors.create
                 ~context:
                   (sprintf
                      "Received a public key of an unexpected shape %s when \
                       accessing the Mina GraphQL API."
                      (Yojson.Basic.pretty_to_string x) )
                 `Invariant_violation )
      in
      let%bind kind =
        match obj.Get_transactions_by_hash.kind with
        | `String "PAYMENT" ->
            M.return `Payment
        | `String "STAKE_DELEGATION" ->
            M.return `Delegation
        | kind ->
            M.fail
              (Errors.create
                 ~context:
                   (sprintf
                      "Received a user command of an unexpected kind %s when \
                       accessing the Mina GrpahQL API."
                      (Yojson.Basic.pretty_to_string kind) )
                 `Invariant_violation )
      in
      let%bind fee_payer = extract_public_key obj.feePayer.publicKey in
      let%bind source = extract_public_key obj.source.publicKey in
      let%map receiver = extract_public_key obj.receiver.publicKey in
      { User_command_info.kind
      ; fee_payer
      ; source
      ; token = obj.token
      ; fee = obj.fee
      ; receiver
      ; fee_token = obj.feeToken
      ; nonce = Unsigned.UInt32.of_int obj.nonce
      ; amount = Some obj.amount
      ; valid_until = Some obj.validUntil
      ; memo = (if String.equal obj.memo "" then None else Some obj.memo)
      ; failure_status = None
      ; hash = obj.hash
      }

    let handle :
           graphql_uri:Uri.t
        -> env:'gql Env.T(M).t
        -> Mempool_transaction_request.t
        -> (Mempool_transaction_response.t, Errors.t) M.t =
     fun ~graphql_uri ~env req ->
      let open M.Let_syntax in
      let%bind res = env.gql ~hash:req.transaction_identifier.hash in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~graphql_uri
      in
      let open Get_transactions_by_hash in
      let%bind user_command_obj =
        if Array.is_empty res.pooledUserCommands then
          M.fail
            (Errors.create
               (`Transaction_not_found req.transaction_identifier.hash) )
        else
          let cmd = res.pooledUserCommands.(0) in
          M.return cmd
      in
      let%map user_command_info = user_command_info_of_obj user_command_obj in
      { Mempool_transaction_response.transaction =
          { Transaction.transaction_identifier =
              { Transaction_identifier.hash = req.transaction_identifier.hash }
          ; operations = user_command_info |> User_command_info.to_operations'
          ; metadata = None
          }
      ; metadata = None
      }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "mempool transaction" =
    ( module struct
      module Mock = Impl (Result)

      (* This test intentionally fails as there has not been time to implement
         * it properly yet *)
      (*
      let%test_unit "all dummies" =
        Test.assert_ ~f:Mempool_transaction_response.to_yojson
          ~expected:
            (Mock.handle ~env:Env.mock
               (Mempool_transaction_request.create
                  (Network_identifier.create "x" "y")
                  (Transaction_identifier.create "x")))
          ~actual:(Result.fail (Errors.create (`Json_parse None)))
    *)
    end )
end

let router ~graphql_uri ~logger (route : string list) body =
  let open Async.Deferred.Result.Let_syntax in
  [%log debug] "Handling /mempool/ $route"
    ~metadata:[ ("route", `List (List.map route ~f:(fun s -> `String s))) ] ;
  [%log info] "Mempool query" ~metadata:[ ("query", body) ] ;
  match route with
  | [] | [ "" ] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request" @@ Network_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        All.Real.handle ~graphql_uri ~env:(All.Env.real ~graphql_uri) req
        |> Errors.Lift.wrap
      in
      Mempool_response.to_yojson res
  | [ "transaction" ] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Mempool_transaction_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Transaction.Real.handle ~graphql_uri
          ~env:(Transaction.Env.real ~graphql_uri)
          req
        |> Errors.Lift.wrap
      in
      Mempool_transaction_response.to_yojson res
  | _ ->
      Deferred.Result.fail `Page_not_found
