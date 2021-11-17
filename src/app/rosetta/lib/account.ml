open Core_kernel
open Async
open Block
open Rosetta_lib

(* Rosetta_models.Currency shadows our Currency so we "save" it as MinaCurrency first *)
module MinaCurrency = Currency
open Rosetta_models
module Decoders = Graphql_lib.Decoders

module Get_balance =
[%graphql
{|
    query get_balance($public_key: PublicKey!, $token_id: TokenId) {
      account(publicKey: $public_key, token: $token_id) {
        balance {
          blockHeight @bsDecoder(fn: "Decoders.uint32")
          stateHash
          liquid @bsDecoder(fn: "Decoders.optional_uint64")
          total @bsDecoder(fn: "Decoders.uint64")
        }
        nonce
      }
    }
|}]

module Balance_info = struct
  type t = {liquid_balance: int64; total_balance: int64}
           [@@deriving yojson]
end

module Sql = struct
  module Balance_from_last_relevant_command = struct
    (* This is SQL is the common chunk shared between the query_recent and
     * query_old that retreives the relevant balance changes from transactions
     * at a block. *)
    let common_sql =
      {sql|
relevant_internal_block_balances AS (
  SELECT
    block_internal_command.block_id,
    block_internal_command.sequence_no,
    block_internal_command.secondary_sequence_no,
    receiver_balance.balance
  FROM blocks_internal_commands block_internal_command
  INNER JOIN balances receiver_balance ON block_internal_command.receiver_balance = receiver_balance.id
  INNER JOIN public_keys receiver_pk ON receiver_pk.id = receiver_balance.public_key_id
  WHERE receiver_pk.value = $1
),

relevant_user_block_fee_payer_balances AS (
  SELECT
    block_user_command.block_id,
    block_user_command.sequence_no,
    fee_payer_balance.balance
  FROM blocks_user_commands block_user_command

  INNER JOIN balances fee_payer_balance ON fee_payer_balance.id = block_user_command.fee_payer_balance

  INNER JOIN public_keys fee_payer_pk ON fee_payer_pk.id = fee_payer_balance.public_key_id
  WHERE fee_payer_pk.value = $1
),

relevant_user_block_source_balances AS (
  SELECT
    block_user_command.block_id,
    block_user_command.sequence_no,
    source_balance.balance
  FROM blocks_user_commands block_user_command

  INNER JOIN balances source_balance ON source_balance.id = block_user_command.source_balance

  INNER JOIN public_keys source_pk ON source_pk.id = source_balance.public_key_id
  WHERE source_pk.value = $1
),

relevant_user_block_receiver_balances AS (
  SELECT
    block_user_command.block_id,
    block_user_command.sequence_no,
    receiver_balance.balance
  FROM blocks_user_commands block_user_command

  INNER JOIN balances receiver_balance ON receiver_balance.id = block_user_command.receiver_balance

  INNER JOIN public_keys receiver_pk ON receiver_pk.id = receiver_balance.public_key_id
  WHERE receiver_pk.value = $1
),

relevant_user_block_balances AS (
  (SELECT block_id, sequence_no, balance FROM relevant_user_block_fee_payer_balances)
  UNION
  (SELECT block_id, sequence_no, balance FROM relevant_user_block_source_balances)
  UNION
  (SELECT block_id, sequence_no, balance FROM relevant_user_block_receiver_balances)
),

relevant_block_balances AS (
  (SELECT block_id, sequence_no, secondary_sequence_no, balance FROM relevant_internal_block_balances)
  UNION
  (SELECT block_id, sequence_no, 0 AS secondary_sequence_no, balance FROM relevant_user_block_balances)
)
      |sql}

    let query_recent =
      Caqti_request.find_opt
        Caqti_type.(tup2 string int64)
        Caqti_type.(tup2 int64 int64)
        (sprintf {sql|
WITH RECURSIVE chain AS (
  (SELECT id, state_hash, parent_id, height, global_slot_since_genesis, timestamp, chain_status
  FROM blocks b
  WHERE height = (select MAX(height) from blocks)
  ORDER BY timestamp ASC
  LIMIT 1)

  UNION ALL

  SELECT b.id, b.state_hash, b.parent_id, b.height, b.global_slot_since_genesis, b.timestamp, b.chain_status FROM blocks b
  INNER JOIN chain
  ON b.id = chain.parent_id AND chain.id <> chain.parent_id AND (chain.chain_status = 'orphaned' OR chain.chain_status IS NULL)
),

%s

SELECT
  chain.global_slot_since_genesis AS block_global_slot_since_genesis,
  balance
FROM
chain
JOIN relevant_block_balances rbb ON chain.id = rbb.block_id
WHERE chain.height <= $2
ORDER BY (chain.height, sequence_no, secondary_sequence_no) DESC
LIMIT 1
      |sql} common_sql)

    let query_old =
      Caqti_request.find_opt
        Caqti_type.(tup2 string int64)
        Caqti_type.(tup2 int64 int64)
(sprintf {sql|
WITH %s

SELECT
  b.global_slot_since_genesis AS block_global_slot_since_genesis,
  balance
FROM
blocks b
JOIN relevant_block_balances rbb ON b.id = rbb.block_id
WHERE b.height <= $2 AND b.chain_status = 'canonical'
ORDER BY (b.height, sequence_no, secondary_sequence_no) DESC
LIMIT 1
      |sql} common_sql)

    let run (module Conn : Caqti_async.CONNECTION) requested_block_height
        address =
      let open Deferred.Result.Let_syntax in
      (* buffer an epsilon of 5 just in case archive node isn't caught up *)
      let%bind is_old_height = Sql.Block.run_is_old_height (module Conn) ~height:requested_block_height in
      if is_old_height then
        Conn.find_opt query_old (address, requested_block_height)
      else
        match%bind
          Conn.find_opt query_recent (address, requested_block_height)
        with
        | None -> Conn.find_opt query_old (address, requested_block_height)
        | Some r -> return (Some r)
  end

  let run (module Conn : Caqti_async.CONNECTION) block_query address =
    let open Deferred.Result.Let_syntax in
    let%bind timing_info_opt =
      Archive_lib.Processor.Timing_info.find_by_pk_opt
        (module Conn)
        (Signature_lib.Public_key.Compressed.of_base58_check_exn address)
      |> Errors.Lift.sql ~context:"Finding timing info"
    in
    (* First find the block referenced by the block identifier. Then find the latest block no later than it that has a
     * user or internal command relevant to the address we're checking and pull the balance from it. For non-vesting
     * accounts that balance will still be the balance at the block identifier. For vesting accounts we'll also compute
     * how much extra balance has accumulated in between the blocks. *)
    let%bind ( requested_block_height
             , requested_block_global_slot_since_genesis
             , requested_block_hash ) =
      match%bind
        Sql.Block.run (module Conn) block_query
        |> Errors.Lift.sql ~context:"Finding specified block"
      with
      | None ->
          Deferred.Result.fail (Errors.create `Block_missing)
      | Some (_block_id, block_info, _) ->
          Deferred.Result.return
            ( block_info.height
            , block_info.global_slot_since_genesis
            , block_info.state_hash )
    in
    let requested_block_identifier =
      { Block_identifier.index= requested_block_height
      ; hash= requested_block_hash }
    in
    let%bind last_relevant_command_info_opt =
      Balance_from_last_relevant_command.run
        (module Conn)
        requested_block_height address
      |> Errors.Lift.sql
           ~context:
             "Finding balance at last relevant internal or user command."
    in
    let open Unsigned in
    let end_slot =
      UInt32.of_int
        (Int.of_int64_exn requested_block_global_slot_since_genesis)
    in
    let compute_incremental_balance
        (timing_info : Archive_lib.Processor.Timing_info.t) ~start_slot =
      let cliff_time =
        UInt32.of_int (Int.of_int64_exn timing_info.cliff_time)
      in
      let cliff_amount =
        MinaCurrency.Amount.of_int (Int.of_int64_exn timing_info.cliff_amount)
      in
      let vesting_period =
        UInt32.of_int (Int.of_int64_exn timing_info.vesting_period)
      in
      let vesting_increment =
        MinaCurrency.Amount.of_int
          (Int.of_int64_exn timing_info.vesting_increment)
      in
      let initial_minimum_balance =
        MinaCurrency.Balance.of_int
          (Int.of_int64_exn timing_info.initial_minimum_balance)
      in
      Mina_base.Account.incremental_balance_between_slots ~start_slot ~end_slot
        ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
        ~initial_minimum_balance
    in
    let%bind liquid_balance =
      match (last_relevant_command_info_opt, timing_info_opt) with
      | None, None ->
        (* We've never heard of this account, at least as of the block_identifier provided *)
        (* This means they requested a block from before account creation;
         * this is ambiguous in the spec but Coinbase confirmed we can return 0.
         * https://community.rosetta-api.org/t/historical-balance-requests-with-block-identifiers-from-before-account-was-created/369 *)
        Deferred.Result.return 0L
      | Some (_, last_relevant_command_balance), None ->
        (* This account has no special vesting, so just use its last known balance *)
          Deferred.Result.return last_relevant_command_balance
      | None, Some timing_info ->
          (* This account hasn't seen any transactions but was in the genesis ledger, so compute its balance at the start block *)
          let balance_at_genesis : int64 =
            Int64.(
              timing_info.initial_balance - timing_info.initial_minimum_balance)
          in
          let incremental_balance_since_genesis : UInt64.t =
            compute_incremental_balance timing_info
              ~start_slot:(UInt32.of_int 0)
          in
          Deferred.Result.return
            ( UInt64.Infix.(
                UInt64.of_int64 balance_at_genesis
                + incremental_balance_since_genesis)
            |> UInt64.to_int64 )
      | ( Some
            ( last_relevant_command_global_slot_since_genesis
            , last_relevant_command_balance )
        , Some timing_info ) ->
          (* This block was in the genesis ledger and has been involved in at least one user or internal command. We need
         * to compute the change in its balance between the most recent command and the start block (if it has vesting
         * it may have changed). *)
          let incremental_balance_between_slots =
            compute_incremental_balance timing_info
              ~start_slot:
                (UInt32.of_int
                   (Int.of_int64_exn
                      last_relevant_command_global_slot_since_genesis))
          in
          Deferred.Result.return
            ( UInt64.Infix.(
                UInt64.of_int64 last_relevant_command_balance
                + incremental_balance_between_slots)
            |> UInt64.to_int64 )
    in
    let%bind total_balance =
      match (last_relevant_command_info_opt, timing_info_opt) with
      | None, None ->
          (* We've never heard of this account, at least as of the block_identifier provided *)
          (* TODO: This means they requested a block from before account creation. Should it error instead? Need to clarify with Coinbase team. *)
          Deferred.Result.return 0L
      | Some (_, last_relevant_command_balance), _ ->
          (* This account was involved in a command and we don't care about its vesting, so just use the last known
         * balance from the command *)
          Deferred.Result.return last_relevant_command_balance
      | None, Some timing_info ->
          (* This account hasn't seen any transactions but was in the genesis ledger, so use its genesis balance  *)
          Deferred.Result.return timing_info.initial_balance
    in
    let balance_info : Balance_info.t = {liquid_balance; total_balance} in
    Deferred.Result.return (requested_block_identifier, balance_info)
end

module Balance = struct
  module Env = struct
    (* All side-effects go in the env so we can mock them out later *)
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql:
            ?token_id:string
          -> address:string
          -> unit
          -> ([`Successful of 'gql | `Failed of Errors.t], Errors.t) M.t
        ; logger: Logger.t
        ; db_block_identifier_and_balance_info:
               block_query:Block_query.t
            -> address:string
            -> (Block_identifier.t * Balance_info.t, Errors.t) M.t
        ; validate_network_choice: network_identifier:Network_identifier.t -> graphql_uri:Uri.t -> (unit, Errors.t) M.t }
    end

    (* The real environment does things asynchronously *)
    module Real = T (Deferred.Result)

    (* But for tests, we want things to go fast *)
    module Mock = T (Result)

    let real :
          db:(module Caqti_async.CONNECTION)
       -> logger:Logger.t
       -> graphql_uri:Uri.t
       -> 'gql Real.t
    =
     fun ~db ~logger ~graphql_uri ->
      { gql=
          (fun ?token_id ~address () ->
            Graphql.query_and_catch
              (Get_balance.make ~public_key:(`String address)
                 ~token_id:
                   (match token_id with Some s -> `String s | None -> `Null)
                 ())
              graphql_uri )
      ; logger
      ; db_block_identifier_and_balance_info=
          (fun ~block_query ~address ->
            let (module Conn : Caqti_async.CONNECTION) = db in
            Sql.run (module Conn) block_query address )
      ; validate_network_choice= Network.Validate_choice.Real.validate }

    let dummy_block_identifier =
      Block_identifier.create (Int64.of_int_exn 4) "STATE_HASH_BLOCK"

    let mock : 'gql Mock.t =
      { gql=
          (fun ?token_id:_ ~address:_ () ->
            (* TODO: Add variants to cover every branch *)
            Result.return
            @@ `Successful (object
                 method account =
                   Some
                     (object
                        method balance =
                          object
                            method blockHeight = Unsigned.UInt32.of_int 3

                            method stateHash = Some "STATE_HASH_TIP"

                            method liquid =
                              Some (Unsigned.UInt64.of_int 66_000)

                            method total = Unsigned.UInt64.of_int 66_000
                          end

                        method nonce = Some "2"
                     end)
               end ))
      ; logger = Logger.null ()
      ; db_block_identifier_and_balance_info=
          (fun ~block_query ~address ->
            ignore ((block_query, address) : Block_query.t * string) ;
            let balance_info : Balance_info.t =
              {liquid_balance= 0L; total_balance= 0L}
            in
            Result.return @@ (dummy_block_identifier, balance_info) )
      ; validate_network_choice= Network.Validate_choice.Mock.succeed }
  end

  module Impl (M : Monad_fail.S) = struct
    module E = Env.T (M)
    module Token_id = Amount_of.Token_id.T (M)
    module Query = Block_query.T (M)

    let handle :
            graphql_uri: Uri.t
        -> env:'gql E.t
        -> Account_balance_request.t
        -> (Account_balance_response.t, Errors.t) M.t =
     fun ~graphql_uri ~env req ->
      let open M.Let_syntax in
      let address = req.account_identifier.address in
      let%bind token_id = Token_id.decode req.account_identifier.metadata in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~graphql_uri
      in
      let make_balance_amount ~liquid_balance ~total_balance =
        let amount =
          ( match token_id with
          | None ->
              Amount_of.mina
          | Some token_id ->
              Amount_of.token token_id )
            total_balance
        in
        let locked_balance =
          Unsigned.UInt64.sub total_balance liquid_balance
        in
        let metadata =
          `Assoc
            [ ( "locked_balance"
              , `Intlit (Unsigned.UInt64.to_string locked_balance) )
            ; ( "liquid_balance"
              , `Intlit (Unsigned.UInt64.to_string liquid_balance) )
            ; ( "total_balance"
              , `Intlit (Unsigned.UInt64.to_string total_balance) ) ]
        in
        {amount with metadata= Some metadata}
      in
      let%bind block_query =
        Query.of_partial_identifier' req.block_identifier
      in
      let%map block_identifier, {liquid_balance; total_balance} =
        env.db_block_identifier_and_balance_info ~block_query ~address
      in
      { Account_balance_response.block_identifier
      ; balances=
          [ make_balance_amount
              ~liquid_balance:(Unsigned.UInt64.of_int64 liquid_balance)
              ~total_balance:(Unsigned.UInt64.of_int64 total_balance) ]
      ; metadata=Some (`Assoc [ ("created_via_historical_lookup", `Bool true ) ]) }
  end

  module Real = Impl (Deferred.Result)

  let%test_module "balance" =
    ( module struct
      module Mock = Impl (Result)

      let%test_unit "account exists lookup" =
        Test.assert_ ~f:Account_balance_response.to_yojson
          ~expected:
            (Mock.handle ~graphql_uri:(Uri.of_string "http://minaprotocol.com") ~env:Env.mock
               (Account_balance_request.create
                  (Network_identifier.create "x" "y")
                  (Account_identifier.create "x")))
          ~actual:
            (Result.return
               { Account_balance_response.block_identifier=
                   { Block_identifier.index= Int64.of_int 3
                   ; Block_identifier.hash= "STATE_HASH_TIP" }
               ; balances=
                   [ { Amount.value= "66000"
                     ; currency=
                         {Currency.symbol= "MINA"; decimals= 9l; metadata= None}
                     ; metadata=
                         Some
                           (`Assoc
                             [ ("locked_balance", `Intlit "0")
                             ; ("liquid_balance", `Intlit "66000")
                             ; ("total_balance", `Intlit "66000") ]) } ]
               ; metadata= Some (`Assoc [("nonce", `Intlit "2")]) })
    end )
end

let router ~graphql_uri ~logger ~with_db (route : string list) body =
  let open Async.Deferred.Result.Let_syntax in
  [%log debug] "Handling /account/ $route"
    ~metadata:[("route", `List (List.map route ~f:(fun s -> `String s)))] ;
  match route with
  | ["balance"] ->
      with_db (fun ~db ->
        let body =
          (* workaround: rosetta-cli with view:balance does not seem to have a way to submit the
             currencies list, so supply it here
          *)
          match body with
          | `Assoc items -> (
            match List.Assoc.find items "currencies" ~equal:String.equal with
                Some _ -> body
              | None ->
                `Assoc (items @ [("currencies",`List [`Assoc [("symbol",`String "MINA");("decimals", `Int 9)]])])
          )
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
            Balance.Real.handle ~graphql_uri ~env:(Balance.Env.real ~db ~logger ~graphql_uri) req
            |> Errors.Lift.wrap
          in
          Account_balance_response.to_yojson res)
  | _ ->
      Deferred.Result.fail `Page_not_found
