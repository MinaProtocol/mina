open Core_kernel
open Async
open Models

module Get_all_transactions =
[%graphql
{|
    query all_transactions {
      initialPeers
      daemonStatus {
        peers
      }
      pooledUserCommands(publicKey: null) {
        id
      }
    }
|}]

module Get_transactions_by_pk =
[%graphql
{|
    query all_transactions_by_pk($publicKey: PublicKey!) {
      initialPeers
      daemonStatus {
        peers
      }
      pooledUserCommands(publicKey: $publicKey) {
        id
      }
    }
|}]

module All = struct
  module Env = struct
    (* All side-effects go in the env so we can mock them out later *)
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql: unit -> ('gql, Errors.t) M.t
        ; validate_network_choice: 'gql Network.Validate_choice.Impl(M).t }
    end

    (* The real environment does things asynchronously *)
    module Real = T (Deferred.Result)

    (* But for tests, we want things to go fast *)
    module Mock = T (Result)

    let real : graphql_uri:Uri.t -> 'gql Real.t =
     fun ~graphql_uri ->
      { gql=
          (fun () -> Graphql.query (Get_all_transactions.make ()) graphql_uri)
      ; validate_network_choice= Network.Validate_choice.Real.validate }

    let mock : 'gql Mock.t =
      { gql=
          (fun () ->
            (* TODO: Add variants to cover every branch *)
            Result.return
            @@ object
                 method pooledUserCommands =
                   [| `UserCommand
                        (object
                           method id = "TXN_1"
                        end)
                    ; `UserCommand
                        (object
                           method id = "TXN_2"
                        end) |]
               end )
      ; validate_network_choice= Network.Validate_choice.Mock.succeed }
  end

  module Impl (M : Monad_fail.S) = struct
    module E = Env.T (M)

    let handle :
        env:'gql E.t -> Network_request.t -> (Mempool_response.t, Errors.t) M.t
        =
     fun ~env req ->
      let open M.Let_syntax in
      (* TODO: Support alternate tokens *)
      let%bind res = env.gql () in
      let%map () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~gql_response:res
      in
      { Mempool_response.transaction_identifiers=
          res#pooledUserCommands |> Array.to_list
          |> List.map ~f:(fun (`UserCommand obj) ->
                 {Transaction_identifier.hash= obj#id} ) }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "mempool all" =
    ( module struct
      module Mock = Impl (Result)

      let%test_unit "succeeds" =
        Test.assert_ ~f:Mempool_response.to_yojson
          ~expected:(Mock.handle ~env:Env.mock Network.dummy_network_request)
          ~actual:
            (Result.return
               { Mempool_response.transaction_identifiers=
                   [ {Transaction_identifier.hash= "TXN_1"}
                   ; {Transaction_identifier.hash= "TXN_2"} ] })
    end )
end

module Transaction = struct
  module Env = struct
    (* All side-effects go in the env so we can mock them out later *)
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql: public_key:string -> ('gql, Errors.t) M.t
        ; validate_network_choice: 'gql Network.Validate_choice.Impl(M).t }
    end

    (* The real environment does things asynchronously *)
    module Real = T (Deferred.Result)

    (* But for tests, we want things to go fast *)
    module Mock = T (Result)

    let real : graphql_uri:Uri.t -> 'gql Real.t =
     fun ~graphql_uri ->
      { gql=
          (fun ~public_key ->
            Graphql.query
              (Get_transactions_by_pk.make ~publicKey:(`String public_key) ())
              graphql_uri )
      ; validate_network_choice= Network.Validate_choice.Real.validate }

    let mock : 'gql Mock.t =
      { gql=
          (fun ~public_key:_ ->
            (* TODO: Add variants to cover every branch *)
            Result.return
            @@ object
                 method pooledUserCommands =
                   [| `UserCommand
                        (object
                           method id = "TXN_1"
                        end)
                    ; `UserCommand
                        (object
                           method id = "TXN_2"
                        end) |]
               end )
      ; validate_network_choice= Network.Validate_choice.Mock.succeed }
  end

  module Impl (M : Monad_fail.S) = struct
    module E = Env.T (M)

    let handle :
           env:'gql E.t
        -> Mempool_transaction_request.t
        -> (Mempool_transaction_response.t, Errors.t) M.t =
     fun ~env req ->
      let open M.Let_syntax in
      let%bind res = env.gql ~public_key:"TODO" in
      let%map () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~gql_response:res
      in
      let _is_present_in_mempool =
        failwith "TODO: Find user command inside larger array"
      in
      failwith "TODO"
  end

  module Real = Impl (Deferred.Result)
end

let router ~graphql_uri ~logger:_ ~db (route : string list) body =
  let (module Db : Caqti_async.CONNECTION) = db in
  let open Async.Deferred.Result.Let_syntax in
  match route with
  | [] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request" @@ Network_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        All.Real.handle ~env:(All.Env.real ~graphql_uri) req
        |> Errors.Lift.wrap
      in
      Mempool_response.to_yojson res
  | ["transaction"] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Mempool_transaction_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Transaction.Real.handle ~env:(Transaction.Env.real ~graphql_uri) req
        |> Errors.Lift.wrap
      in
      Mempool_transaction_response.to_yojson res
  | _ ->
      Deferred.Result.fail `Page_not_found
