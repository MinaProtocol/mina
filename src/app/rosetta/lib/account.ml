open Core_kernel
open Async
open Block
open Rosetta_lib

(* Rosetta_models.Currency shadows our Currency so we "save" it as MinaCurrency first *)
module MinaCurrency = Currency
open Rosetta_models
module Scalars = Graphql_lib.Scalars

module Get_balance =
[%graphql
{|
    query get_balance($public_key: PublicKey!, $token_id: TokenId) {
      account(publicKey: $public_key, token: $token_id) {
        balance {
          blockHeight @ppxCustom(module: "Scalars.UInt32")
          stateHash @ppxCustom(module: "Scalars.String_json")
          liquid @ppxCustom(module: "Scalars.UInt64")
          total @ppxCustom(module: "Scalars.UInt64")
        }
        nonce @ppxCustom(module: "Scalars.String_json")
      }
    }
|}]

module Balance_info = struct
  type t = { liquid_balance : int64; total_balance : int64 } [@@deriving yojson]
end

module Sql = struct
  module Balance_from_last_relevant_command = struct
    let query_pending =
      Mina_caqti.find_opt_req
        Caqti_type.(t3 string int64 string)
        Caqti_type.(t2 (t4 int64 int64 int64 int64) int)
        {sql|
  WITH RECURSIVE pending_chain AS (

               (SELECT id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status

                FROM blocks b
                WHERE height = (select MAX(height) from blocks)
                ORDER BY timestamp ASC, state_hash ASC
                LIMIT 1)

                UNION ALL

                SELECT b.id, b.state_hash, b.parent_id, b.height, b.global_slot_since_genesis, b.timestamp, b.chain_status

                FROM blocks b
                INNER JOIN pending_chain
                ON b.id = pending_chain.parent_id AND pending_chain.id <> pending_chain.parent_id
                AND pending_chain.chain_status <> 'canonical'

              )

              SELECT DISTINCT full_chain.height,full_chain.global_slot_since_genesis AS block_global_slot_since_genesis,balance,nonce,timing_id

              FROM (SELECT
                    id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status
                    FROM pending_chain

                    UNION ALL

                    SELECT id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status

                    FROM blocks b
                    WHERE chain_status = 'canonical') AS full_chain

              INNER JOIN accounts_accessed aa ON full_chain.id = aa.block_id
              INNER JOIN account_identifiers ai on ai.id = aa.account_identifier_id
              INNER JOIN public_keys pks ON ai.public_key_id = pks.id
              INNER JOIN tokens t ON ai.token_id = t.id

              WHERE pks.value = $1
              AND full_chain.height <= $2
              AND t.value = $3

              ORDER BY full_chain.height DESC
              LIMIT 1
|sql}

    let query_canonical =
      Mina_caqti.find_opt_req
        Caqti_type.(t3 string int64 string)
        Caqti_type.(t2 (t4 int64 int64 int64 int64) int)
        {sql|
                SELECT b.height,b.global_slot_since_genesis AS block_global_slot_since_genesis,balance,nonce,timing_id

                FROM blocks b
                INNER JOIN accounts_accessed ac ON ac.block_id = b.id
                INNER JOIN account_identifiers ai on ai.id = ac.account_identifier_id
                INNER JOIN public_keys pks ON ai.public_key_id = pks.id
                INNER JOIN tokens t ON ai.token_id = t.id

                WHERE pks.value = $1
                AND b.height <= $2
                AND b.chain_status = 'canonical'
                AND t.value = $3

                ORDER BY (b.height) DESC
                LIMIT 1
|sql}

    let run (module Conn : Mina_caqti.CONNECTION) ~requested_block_height
        ~address ~token_id =
      let open Deferred.Result.Let_syntax in
      let%bind has_canonical_height =
        Sql.Block.run_has_canonical_height
          (module Conn)
          ~height:requested_block_height
      in
      Conn.find_opt
        (if has_canonical_height then query_canonical else query_pending)
        (address, requested_block_height, token_id)
  end

  let compute_incremental_balance
      (timing_info : Archive_lib.Processor.Timing_info.t) ~start_slot ~end_slot
      =
    let cliff_time =
      Mina_numbers.Global_slot_since_genesis.of_int
        (Int.of_int64_exn timing_info.cliff_time)
    in
    let cliff_amount = MinaCurrency.Amount.of_string timing_info.cliff_amount in
    let vesting_period =
      Mina_numbers.Global_slot_span.of_int
        (Int.of_int64_exn timing_info.vesting_period)
    in
    let vesting_increment =
      MinaCurrency.Amount.of_string timing_info.vesting_increment
    in
    let initial_minimum_balance =
      MinaCurrency.Balance.of_string timing_info.initial_minimum_balance
    in
    Mina_base.Account.incremental_balance_between_slots ~start_slot ~end_slot
      ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
      ~initial_minimum_balance

  let find_current_balance (module Conn : Mina_caqti.CONNECTION)
      ~requested_block_global_slot_since_genesis ~last_relevant_command_info
      ?timing_id () =
    let open Deferred.Result.Let_syntax in
    let open Unsigned in
    let ( _
        , last_relevant_command_global_slot_since_genesis
        , last_relevant_command_balance
        , nonce ) =
      last_relevant_command_info
    in
    let%bind timing_info_opt =
      match timing_id with
      | Some timing_id ->
          Archive_lib.Processor.Timing_info.load_opt (module Conn) timing_id
          |> Errors.Lift.sql ~context:"Finding timing info"
      | None ->
          return None
    in
    let end_slot =
      Mina_numbers.Global_slot_since_genesis.of_uint32
        (Unsigned.UInt32.of_int64 requested_block_global_slot_since_genesis)
    in
    let%bind liquid_balance, nonce =
      match timing_info_opt with
      | None ->
          (* This account has no special vesting, so just use its last
             known balance from the command.*)
          Deferred.Result.return
            (last_relevant_command_balance, UInt64.of_int64 nonce)
      | Some timing_info ->
          (* This block was in the genesis ledger and has been
             involved in at least one user or internal command. We need
             to compute the change in its balance between the most recent
             command and the start block (if it has vesting it may have
             changed). *)
          let incremental_balance_between_slots =
            compute_incremental_balance timing_info
              ~start_slot:
                (Mina_numbers.Global_slot_since_genesis.of_int
                   (Int.of_int64_exn
                      last_relevant_command_global_slot_since_genesis ) )
              ~end_slot
          in
          Deferred.Result.return
            ( UInt64.Infix.(
                UInt64.of_int64 last_relevant_command_balance
                + incremental_balance_between_slots)
              |> UInt64.to_int64
            , UInt64.of_int64 nonce )
    in
    let total_balance = last_relevant_command_balance in
    let balance_info : Balance_info.t = { liquid_balance; total_balance } in
    Deferred.Result.return (balance_info, nonce)

  let run (module Conn : Mina_caqti.CONNECTION) ~block_query ~address ~token_id
      =
    let open Deferred.Result.Let_syntax in
    (* First find the block referenced by the block identifier. Then
       find the latest block no later than it that has a user or
       internal command relevant to the address we're checking and
       pull the balance from it. For non-vesting accounts that
       balance will still be the balance at the block
       identifier. For vesting accounts we'll also compute how much
       extra balance has accumulated in between the blocks. *)
    let%bind ( requested_block_height
             , requested_block_global_slot_since_genesis
             , requested_block_hash ) =
      match%bind
        Sql.Block.run (module Conn) block_query
        |> Errors.Lift.sql ~context:"Finding specified block"
      with
      | None ->
          Deferred.Result.fail
            (Errors.create @@ `Block_missing (Block_query.to_string block_query))
      | Some { raw_block = block_info; _ } ->
          Deferred.Result.return
            ( block_info.height
            , block_info.global_slot_since_genesis
            , block_info.state_hash )
    in
    let%bind last_relevant_command_info_opt =
      Balance_from_last_relevant_command.run
        (module Conn)
        ~requested_block_height ~address ~token_id
      |> Errors.Lift.sql
           ~context:"Finding balance at last relevant internal or user command."
    in
    let requested_block_identifier =
      { Block_identifier.index = requested_block_height
      ; hash = requested_block_hash
      }
    in
    let%bind balance_info, nonce =
      match last_relevant_command_info_opt with
      | None ->
          (* account doesn' exist yet at the request block, return zero balance *)
          let nonce = Unsigned.UInt64.of_int 0 in
          Deferred.Result.return
            ({ Balance_info.liquid_balance = 0L; total_balance = 0L }, nonce)
      | Some (last_relevant_command_info, timing_id) ->
          find_current_balance
            (module Conn)
            ~requested_block_global_slot_since_genesis
            ~last_relevant_command_info ~timing_id ()
    in
    Deferred.Result.return (requested_block_identifier, balance_info, nonce)
end

module Balance = struct
  module Env = struct
    (* All side-effects go in the env so we can mock them out later *)
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql :
            ?token_id:string -> address:string -> unit -> ('gql, Errors.t) M.t
        ; db_block_identifier_and_balance_info :
               block_query:Block_query.t
            -> address:string
            -> token_id:string
            -> ( Block_identifier.t * Balance_info.t * Unsigned.UInt64.t
               , Errors.t )
               M.t
        ; validate_network_choice :
               network_identifier:Network_identifier.t
            -> minimum_user_command_fee:Mina_currency.Fee.t
            -> graphql_uri:Uri.t
            -> (unit, Errors.t) M.t
        }
    end

    (* The real environment does things asynchronously *)
    module Real = T (Deferred.Result)

    (* But for tests, we want things to go fast *)
    module Mock = T (Result)

    let real :
           with_db:_
        -> graphql_uri:Uri.t
        -> minimum_user_command_fee:Mina_currency.Fee.t
        -> 'gql Real.t =
     fun ~with_db ~graphql_uri ~minimum_user_command_fee ->
      { gql =
          (fun ?token_id ~address () ->
            Graphql.query ~minimum_user_command_fee
              Get_balance.(
                make
                @@ makeVariables ~public_key:(`String address)
                     ~token_id:
                       ( match token_id with
                       | Some s ->
                           `String s
                       | None ->
                           `Null )
                     ())
              graphql_uri )
      ; db_block_identifier_and_balance_info =
          (fun ~block_query ~address ~token_id ->
            with_db (fun ~db ->
                let (module Conn : Mina_caqti.CONNECTION) = db in
                Sql.run (module Conn) ~block_query ~address ~token_id
                |> Errors.Lift.wrap )
            |> Deferred.Result.map_error ~f:(function `App e -> e) )
      ; validate_network_choice = Network.Validate_choice.Real.validate
      }

    let dummy_block_identifier =
      Block_identifier.create (Int64.of_int_exn 4) "STATE_HASH_BLOCK"

    let mock : 'gql Mock.t =
      { gql =
          (fun ?token_id:_ ~address:_ () ->
            (* TODO: Add variants to cover every branch *)
            Result.return
            @@ { Get_balance.account =
                   Some
                     { balance =
                         { blockHeight = Unsigned.UInt32.of_int 3
                         ; stateHash = Some "STATE_HASH_TIP"
                         ; liquid = Some (Unsigned.UInt64.of_int 66_000)
                         ; total = Unsigned.UInt64.of_int 66_000
                         }
                     ; nonce = Some "2"
                     }
               } )
      ; db_block_identifier_and_balance_info =
          (fun ~block_query:_ ~address:_ ~token_id:_ ->
            let balance_info : Balance_info.t =
              { liquid_balance = 0L; total_balance = 0L }
            in
            Result.return
              (dummy_block_identifier, balance_info, Unsigned.UInt64.zero) )
      ; validate_network_choice = Network.Validate_choice.Mock.succeed
      }
  end

  module Impl (M : Monad_fail.S) = struct
    module E = Env.T (M)
    module Token_id = Amount_of.Token_id.T (M)
    module Query = Block_query.T (M)

    let handle :
           graphql_uri:Uri.t
        -> minimum_user_command_fee:Mina_currency.Fee.t
        -> env:'gql E.t
        -> Account_balance_request.t
        -> (Account_balance_response.t, Errors.t) M.t =
     fun ~graphql_uri ~minimum_user_command_fee ~env req ->
      let open M.Let_syntax in
      let address = req.account_identifier.address in
      let%bind token_id = Token_id.decode req.account_identifier.metadata in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~graphql_uri ~minimum_user_command_fee
      in
      let make_balance_amount ~liquid_balance ~total_balance =
        let amount =
          ( match token_id with
          | None ->
              Amount_of.mina
          | Some token_id ->
              Amount_of.token (`Token_id token_id) )
            total_balance
        in
        let locked_balance = Unsigned.UInt64.sub total_balance liquid_balance in
        let metadata =
          `Assoc
            [ ( "locked_balance"
              , `Intlit (Unsigned.UInt64.to_string locked_balance) )
            ; ( "liquid_balance"
              , `Intlit (Unsigned.UInt64.to_string liquid_balance) )
            ; ( "total_balance"
              , `Intlit (Unsigned.UInt64.to_string total_balance) )
            ]
        in
        { amount with metadata = Some metadata }
      in
      let%bind block_query =
        Query.of_partial_identifier' req.block_identifier
      in
      let%map ( block_identifier
              , liquid_balance
              , total_balance
              , nonce
              , created_via_historical_lookup ) =
        match block_query with
        | Some _ ->
            let%map block_identifier, { liquid_balance; total_balance }, nonce =
              env.db_block_identifier_and_balance_info ~block_query ~address
                ~token_id:
                  (Option.value token_id
                     ~default:Mina_base.Token_id.(to_string default) )
            in
            ( block_identifier
            , Unsigned.UInt64.of_int64 liquid_balance
            , Unsigned.UInt64.of_int64 total_balance
            , Unsigned.UInt64.to_string nonce
            , true )
        | None -> (
            let%bind gql_response = env.gql ?token_id ~address () in
            let%bind account =
              Option.value_map gql_response.Get_balance.account ~f:M.return
                ~default:(M.fail (Errors.create (`Account_not_found address)))
            in
            match account with
            | { balance =
                  { blockHeight
                  ; stateHash = Some state_hash
                  ; liquid = Some liquid
                  ; total
                  }
              ; nonce = Some nonce
              } ->
                let block_identifier =
                  Block_identifier.create
                    (Unsigned.UInt32.to_int64 blockHeight)
                    state_hash
                in
                M.return (block_identifier, liquid, total, nonce, false)
            | _ ->
                M.fail
                  (Errors.create
                     (`Exception
                       "Error getting balance from GraphQL (node still \
                        bootstrapping?)" ) ) )
      in

      { Account_balance_response.block_identifier
      ; balances = [ make_balance_amount ~liquid_balance ~total_balance ]
      ; metadata =
          Some
            (`Assoc
              [ ( "created_via_historical_lookup"
                , `Bool created_via_historical_lookup )
              ; ("nonce", `String nonce)
              ] )
      }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "balance" =
    ( module struct
      module Mock = Impl (Result)

      let%test_unit "account exists lookup" =
        Test.assert_ ~f:Account_balance_response.to_yojson
          ~expected:
            (Mock.handle
               ~graphql_uri:(Uri.of_string "http://minaprotocol.com")
               ~minimum_user_command_fee:Mina_currency.Fee.one ~env:Env.mock
               (Account_balance_request.create
                  (Network_identifier.create "x" "y")
                  (Account_identifier.create "x") ) )
          ~actual:
            (Result.return
               { Account_balance_response.block_identifier =
                   { Block_identifier.index = Int64.of_int 3
                   ; Block_identifier.hash = "STATE_HASH_TIP"
                   }
               ; balances =
                   [ { Amount.value = "66000"
                     ; currency =
                         { Currency.symbol = "MINA"
                         ; decimals = 9l
                         ; metadata = None
                         }
                     ; metadata =
                         Some
                           (`Assoc
                             [ ("locked_balance", `Intlit "0")
                             ; ("liquid_balance", `Intlit "66000")
                             ; ("total_balance", `Intlit "66000")
                             ] )
                     }
                   ]
               ; metadata =
                   Some
                     (`Assoc
                       [ ("created_via_historical_lookup", `Bool false)
                       ; ("nonce", `String "2")
                       ] )
               } )

      let%test_unit "account exists historical lookup" =
        Test.assert_ ~f:Account_balance_response.to_yojson
          ~expected:
            (Mock.handle
               ~graphql_uri:(Uri.of_string "http://minaprotocol.com")
               ~minimum_user_command_fee:Mina_currency.Fee.one ~env:Env.mock
               Account_balance_request.
                 { block_identifier =
                     Some
                       Partial_block_identifier.{ index = Some 4L; hash = None }
                 ; network_identifier = Network_identifier.create "x" "y"
                 ; account_identifier = Account_identifier.create "x"
                 ; currencies = []
                 } )
          ~actual:
            (Result.return
               { Account_balance_response.block_identifier =
                   { Block_identifier.index = Int64.of_int 4
                   ; Block_identifier.hash = "STATE_HASH_BLOCK"
                   }
               ; balances =
                   [ { Amount.value = "0"
                     ; currency =
                         { Currency.symbol = "MINA"
                         ; decimals = 9l
                         ; metadata = None
                         }
                     ; metadata =
                         Some
                           (`Assoc
                             [ ("locked_balance", `Intlit "0")
                             ; ("liquid_balance", `Intlit "0")
                             ; ("total_balance", `Intlit "0")
                             ] )
                     }
                   ]
               ; metadata =
                   Some
                     (`Assoc
                       [ ("created_via_historical_lookup", `Bool true)
                       ; ("nonce", `String "0")
                       ] )
               } )
    end )
end

let router ~graphql_uri ~minimum_user_command_fee ~logger ~with_db
    (route : string list) body =
  let open Async.Deferred.Result.Let_syntax in
  [%log debug] "Handling /account/ $route"
    ~metadata:[ ("route", `List (List.map route ~f:(fun s -> `String s))) ] ;
  [%log info] "Account query" ~metadata:[ ("query", body) ] ;
  match route with
  | [ "balance" ] ->
      let body =
        (* workaround: rosetta-cli with view:balance does not seem to have a way to submit the
           currencies list, so supply it here
        *)
        match body with
        | `Assoc items -> (
            match List.Assoc.find items "currencies" ~equal:String.equal with
            | Some _ ->
                body
            | None ->
                `Assoc
                  ( items
                  @ [ ( "currencies"
                      , `List
                          [ `Assoc
                              [ ("symbol", `String "MINA")
                              ; ("decimals", `Int 9)
                              ]
                          ] )
                    ] ) )
        | _ ->
            (* will fail on JSON parse below *)
            body
      in
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Account_balance_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Balance.Real.handle ~graphql_uri ~minimum_user_command_fee
          ~env:
            (Balance.Env.real ~with_db ~graphql_uri ~minimum_user_command_fee)
          req
        |> Errors.Lift.wrap
      in
      Account_balance_response.to_yojson res
  | _ ->
      Deferred.Result.fail `Page_not_found
