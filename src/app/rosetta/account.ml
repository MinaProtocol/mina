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

let router ~graphql_uri ~logger:_ ~db (route : string list) body =
  let (module Db : Caqti_async.CONNECTION) = db in
  let open Async.Deferred.Result.Let_syntax in
  match route with
  | ["balance"] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Account_balance_request.of_yojson body
      in
      let address = req.account_identifier.address in
      (* TODO: Support alternate tokens *)
      let%bind res =
        Graphql.query
          (Get_balance.make ~public_key:(`String address) ~token_id:`Null ())
          graphql_uri
      in
      let%bind () =
        Network.validate_network_choice
          ~network_identifier:req.network_identifier ~gql_response:res
      in
      let%bind account =
        match res#account with
        | None ->
            Deferred.Result.fail (Errors.create (`Account_not_found address))
        | Some account ->
            Deferred.Result.return account
      in
      let%map state_hash =
        match (account#balance)#stateHash with
        | None ->
            Deferred.Result.fail
              (Errors.create
                 ~context:
                   "Failed accessing state hash from GraphQL communication \
                    with the Coda Daemon."
                 `Chain_info_missing)
        | Some state_hash ->
            Deferred.Result.return state_hash
      in
      Account_balance_response.to_yojson
        { Account_balance_response.block_identifier=
            { Block_identifier.index=
                Unsigned.UInt32.to_int64 (account#balance)#blockHeight
            ; hash= state_hash }
        ; balances=
            [ { Amount.value= Unsigned.UInt64.to_string (account#balance)#total
              ; currency=
                  {Currency.symbol= "CODA"; decimals= 9l; metadata= None}
              ; metadata= None } ]
        ; metadata=
            Option.map
              ~f:(fun nonce -> `Assoc [("nonce", `Intlit nonce)])
              account#nonce }
  | _ ->
      Deferred.Result.fail `Page_not_found
