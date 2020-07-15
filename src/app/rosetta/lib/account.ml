open Core_kernel
open Async
open Models

module Get_balance =
[%graphql
{|
    query get_balance($public_key: PublicKey!, $token_id: TokenId) {
      genesisBlock {
        stateHash
      }
      bestChain {
        stateHash
      }
      initialPeers
      daemonStatus {
        peers
      }
      account(publicKey: $public_key, token: $token_id) {
        balance {
          blockHeight @bsDecoder(fn: "Decoders.uint32")
          stateHash
          total @bsDecoder(fn: "Decoders.uint64")
        }
        nonce
      }
  }
|}]

module Balance = struct
  (* All side-effects go in the env so we can mock them out later *)
  module Env (M : Monad_fail.S) = struct
    type ('gql, 'err) t =
      { gql:
             ?token_id:string
          -> address:string
          -> unit
          -> ('gql, ([> `App of Errors.t] as 'err)) M.t
      ; validate_network_choice:
             network_identifier:Network_identifier.t
          -> gql_response:'gql
          -> (unit, ([> `App of Errors.t] as 'err)) M.t }
  end

  (* The real environment does things asynchronously *)
  module RealEnv = Env (Deferred.Result)

  (* But for tests, we want things to go fast *)
  module MockEnv = Env (Result)

  let realEnv : graphql_uri:Uri.t -> ('gql, 'err) RealEnv.t =
   fun ~graphql_uri ->
    { gql=
        (fun ?token_id:_ ~address () ->
          Graphql.query
            (Get_balance.make ~public_key:(`String address) ~token_id:`Null ())
            graphql_uri )
    ; validate_network_choice= Network.validate_network_choice }

  let mockEnv : [`Fail_validation | `Pass_validation] -> ('gql, 'err) MockEnv.t
      =
   fun validate_mode ->
    { gql=
        (fun ?token_id:_ ~address:_ () ->
          (* TODO: Add variants to cover every branch *)
          Result.return
          @@ object
               method genesisBlock =
                 object
                   method stateHash = "STATE_HASH_GENISIS"
                 end

               method bestChain =
                 Some
                   [| object
                        method stateHash = "STATE_HASH_TIP"
                      end |]

               method initialPeers = [|"dev.o1test.net"|]

               method daemonStatus =
                 object
                   method peers = [|"dev.o1test.net"|]
                 end

               method account =
                 Some
                   (object
                      method balance =
                        object
                          method blockHeight = Unsigned.UInt32.of_int 3

                          method stateHash = Some "STATE_HASH_TIP"

                          method total = Unsigned.UInt64.of_int 66_000
                        end

                      method nonce = Some "2"
                   end)
             end )
    ; validate_network_choice=
        (fun ~network_identifier ~gql_response ->
          match validate_mode with
          | `Pass_validation ->
              Result.return ()
          | `Fail_validation ->
              let network_tag = Network.network_tag_of_graphql gql_response in
              let requested_tag =
                network_identifier.Network_identifier.network
              in
              Result.fail
                (Errors.create
                   (`Network_doesn't_exist (requested_tag, network_tag))) ) }

  module Impl (M : Monad_fail.S) = struct
    module E = Env (M)

    let handle :
           env:('gql, 'err) E.t
        -> Account_balance_request.t
        -> (Account_balance_response.t, ([> `App of Errors.t] as 'err)) M.t =
     fun ~env req ->
      let open M.Let_syntax in
      let address = req.account_identifier.address in
      (* TODO: Support alternate tokens *)
      let%bind res = env.gql ~address () in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~gql_response:res
      in
      let%bind account =
        match res#account with
        | None ->
            M.fail (Errors.create (`Account_not_found address))
        | Some account ->
            M.return account
      in
      let%map state_hash =
        match (account#balance)#stateHash with
        | None ->
            M.fail
              (Errors.create
                 ~context:
                   "Failed accessing state hash from GraphQL communication \
                    with the Coda Daemon."
                 `Chain_info_missing)
        | Some state_hash ->
            M.return state_hash
      in
      { Account_balance_response.block_identifier=
          { Block_identifier.index=
              Unsigned.UInt32.to_int64 (account#balance)#blockHeight
          ; hash= state_hash }
      ; balances=
          [ { Amount.value= Unsigned.UInt64.to_string (account#balance)#total
            ; currency= {Currency.symbol= "CODA"; decimals= 9l; metadata= None}
            ; metadata= None } ]
      ; metadata=
          Option.map
            ~f:(fun nonce -> `Assoc [("nonce", `Intlit nonce)])
            account#nonce }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "balance" =
    ( module struct
      module Mock = Impl (Result)

      (* TODO: Add all the other branches *)

      let%test_unit "fails validation" =
        Test.assert_ ~f:Account_balance_response.to_yojson
          ~expected:
            (Mock.handle
               ~env:(mockEnv `Fail_validation)
               (Account_balance_request.create
                  (Network_identifier.create "x" "y")
                  (Account_identifier.create "x")))
          ~actual:
            (Result.fail (Errors.create (`Network_doesn't_exist ("y", "dev"))))
    end )
end

let router ~graphql_uri ~logger:_ ~db (route : string list) body =
  let (module Db : Caqti_async.CONNECTION) = db in
  let open Async.Deferred.Result.Let_syntax in
  match route with
  | ["balance"] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Account_balance_request.of_yojson body
      in
      let%map res =
        Balance.Real.handle ~env:(Balance.realEnv ~graphql_uri) req
      in
      Account_balance_response.to_yojson res
  | _ ->
      Deferred.Result.fail `Page_not_found
