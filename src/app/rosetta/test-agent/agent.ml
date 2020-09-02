(** An agent that pokes at Coda and peeks at Rosetta to see if things look alright *)

open Core_kernel
open Async
open Rosetta_models
open Rosetta_lib
open Lib

module Error = struct
  include Error

  let equal e1 e2 = Yojson.Safe.equal (Error.to_yojson e1) (Error.to_yojson e2)
end

let other_pk = "B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv"

let wait span = Async.after span |> Deferred.map ~f:Result.return

(* Keep trying to run `step` `retry_count` many times initially waiting for `initial_delay` and each time waiting `each_delay` *)
let keep_trying ~step ~retry_count ~initial_delay ~each_delay ~failure_reason =
  let open Deferred.Result.Let_syntax in
  let rec go = function
    | 0 ->
        Deferred.Result.fail
          (Errors.create ~context:failure_reason `Invariant_violation)
    | i -> (
        match%bind step () with
        | `Succeeded a ->
            return a
        | `Failed ->
            let%bind () = wait each_delay in
            go (i - 1) )
  in
  let%bind () = wait initial_delay in
  go retry_count

let verify_in_mempool_and_block ~logger ~rosetta_uri ~graphql_uri
    ~network_response ~txn_hash ~operation_expectations
    ~plus_further_mempool_expecations =
  let open Core.Time in
  let open Deferred.Result.Let_syntax in
  let%bind () = wait (Span.of_sec 1.0) in
  (* Grab the mempool and find the user command inside *)
  let%bind () =
    keep_trying
      ~step:(fun () ->
        let%map mempool_r =
          Peek.Mempool.mempool ~rosetta_uri ~network_response ~logger
        in
        match
          Result.map mempool_r ~f:(fun mempool ->
              List.find mempool.Mempool_response.transaction_identifiers
                ~f:(fun ident ->
                  String.equal ident.Transaction_identifier.hash txn_hash ) )
        with
        | Error _ ->
            `Failed
        | Ok None ->
            `Failed
        | Ok (Some _) ->
            `Succeeded () )
      ~retry_count:5 ~initial_delay:(Span.of_ms 100.0)
      ~each_delay:(Span.of_sec 1.0)
      ~failure_reason:"Took too long to appear in mempool"
  in
  (* Pull specific account out of mempool *)
  let%bind mempool_res =
    Peek.Mempool.transaction ~rosetta_uri ~network_response ~logger
      ~hash:txn_hash
  in
  [%log debug]
    ~metadata:
      [ ( "operations"
        , mempool_res.transaction.operations |> [%to_yojson: Operation.t list]
        ) ]
    "Mempool operations: $operations" ;
  let%bind () =
    Operation_expectation.assert_similar_operations ~logger
      ~expected:(operation_expectations @ plus_further_mempool_expecations)
      ~actual:mempool_res.transaction.operations ~situation:"mempool"
  in
  [%log info] "Verified mempool operations" ;
  let%bind last_block_index =
    keep_trying
      ~step:(fun () ->
        let%map block_r =
          Peek.Block.newest_block ~rosetta_uri ~network_response ~logger
        in
        match
          Result.map block_r ~f:(fun block ->
              (Option.value_exn block.Block_response.block).block_identifier
                .index )
        with
        | Error _ ->
            `Failed
        | Ok index ->
            `Succeeded index )
      ~retry_count:10 ~initial_delay:(Span.of_ms 0.0)
      ~each_delay:(Span.of_ms 250.0)
      ~failure_reason:"Took too long for the last block to be fetched"
  in
  [%log debug]
    ~metadata:[("index", `Intlit (Int64.to_string last_block_index))]
    "Found block index $index" ;
  (* Start staking so we get blocks *)
  let%bind _res = Poke.Staking.enable ~graphql_uri in
  (* Wait until the newest-block is at least index>last_block_index and there is at least not a coinbase *)
  let%bind block =
    keep_trying
      ~step:(fun () ->
        let%map block_r =
          Peek.Block.newest_block ~rosetta_uri ~network_response ~logger
        in
        match
          Result.map block_r ~f:(fun block ->
              let newer_block : bool =
                Int64.(
                  (Option.value_exn block.Block_response.block)
                    .block_identifier
                    .index > last_block_index)
              in
              let at_least_txn_not_coinbase : bool =
                Int.(
                  List.length
                    (Option.value_exn block.Block_response.block).transactions
                  > 1)
              in
              if newer_block && at_least_txn_not_coinbase then Some block
              else None )
        with
        | Error _ ->
            `Failed
        | Ok None ->
            `Failed
        | Ok (Some block) ->
            `Succeeded block )
      ~retry_count:10 ~initial_delay:(Span.of_ms 50.0)
      ~each_delay:(Span.of_ms 250.0)
      ~failure_reason:"Took too long for a block to be created"
  in
  [%log debug]
    ~metadata:
      [ ( "index"
        , `Intlit
            (Int64.to_string
               (Option.value_exn block.Block_response.block).block_identifier
                 .index) ) ]
    "Waited for the next block index $index" ;
  (* Stop noisy block production *)
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  let succesful (x : Operation_expectation.t) = {x with status= "Success"} in
  [%log debug]
    ~metadata:
      [ ( "transactions"
        , [%to_yojson: Rosetta_models.Transaction.t list]
            (Option.value_exn block.block).transactions ) ]
    "Asserting that operations are similar in block. Transactions $transactions" ;
  Operation_expectation.assert_similar_operations ~logger
    ~expected:
      ( List.map ~f:succesful operation_expectations
      @ Operation_expectation.
          [ { amount= Some 20_000_000_000
            ; account=
                Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
            ; status= "Success"
            ; _type= "coinbase_inc"
            ; target= None } ] )
    ~actual:
      ( List.map (Option.value_exn block.block).transactions ~f:(fun txn ->
            txn.operations )
      |> List.join )
    ~situation:"block"

let direct_graphql_payment_through_block ~logger ~rosetta_uri ~graphql_uri
    ~network_response =
  let open Deferred.Result.Let_syntax in
  (* Unlock the account *)
  let%bind _ = Poke.Account.unlock ~graphql_uri in
  (* Send a payment *)
  let%bind hash =
    Poke.SendTransaction.payment ~fee:(`Int 2_000_000_000)
      ~amount:(`Int 5_000_000_000) ~to_:(`String other_pk) ~graphql_uri ()
  in
  verify_in_mempool_and_block ~logger ~rosetta_uri ~graphql_uri ~txn_hash:hash
    ~network_response
    ~operation_expectations:
      Operation_expectation.
        [ { amount= Some (-5_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "payment_source_dec"
          ; target= None }
        ; { amount= Some 5_000_000_000
          ; account=
              Some {Account.pk= other_pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "payment_receiver_inc"
          ; target= None }
        ; { amount= Some (-2_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None } ]
    ~plus_further_mempool_expecations:
      Operation_expectation.
        [ { amount= Some (-2_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None } ]

let direct_graphql_delegation_through_block ~logger ~rosetta_uri ~graphql_uri
    ~network_response =
  let open Deferred.Result.Let_syntax in
  (* Unlock the account *)
  let%bind _ = Poke.Account.unlock ~graphql_uri in
  (* Delegate stake *)
  let%bind hash =
    Poke.SendTransaction.delegation ~fee:(`Int 2_000_000_000)
      ~to_:(`String other_pk) ~graphql_uri ()
  in
  verify_in_mempool_and_block ~logger ~rosetta_uri ~graphql_uri ~txn_hash:hash
    ~network_response
    ~operation_expectations:
      Operation_expectation.
        [ { amount= None
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "delegate_change"
          ; target= Some other_pk } ]
    ~plus_further_mempool_expecations:
      Operation_expectation.
        [ { amount= Some (-2_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None } ]

let direct_graphql_create_token_through_block ~logger ~rosetta_uri ~graphql_uri
    ~network_response =
  let open Deferred.Result.Let_syntax in
  (* Unlock the sender account *)
  let%bind _ = Poke.Account.unlock ~graphql_uri in
  (* create token *)
  let%bind hash =
    Poke.SendTransaction.create_token ~fee:(`Int 2_000_000_000)
      ~receiver:(`String other_pk) ~graphql_uri ()
  in
  verify_in_mempool_and_block ~logger ~rosetta_uri ~graphql_uri ~txn_hash:hash
    ~network_response
    ~operation_expectations:
      Operation_expectation.
        [ { amount= Some (-2_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None }
        ; { amount= None
          ; account= None
          ; status= "Pending"
          ; _type= "create_token"
          ; target= None } ]

let direct_graphql_create_token_account_through_block ~logger ~rosetta_uri
    ~graphql_uri ~network_response =
  let open Deferred.Result.Let_syntax in
  (* Unlock the account *)
  let%bind _ = Poke.Account.unlock ~graphql_uri in
  (* Create token account *)
  let%bind hash =
    Poke.SendTransaction.create_token_account ~fee:(`Int 2_000_000_000)
      ~receiver:other_pk ~token:(`String "2") ~graphql_uri ()
  in
  verify_in_mempool_and_block ~logger ~rosetta_uri ~graphql_uri ~txn_hash:hash
    ~network_response
    ~operation_expectations:
      Operation_expectation.
        [ { amount= Some (-2_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None } ]

let direct_graphql_mint_tokens_through_block ~logger ~rosetta_uri ~graphql_uri
    ~network_response =
  let open Deferred.Result.Let_syntax in
  (* Unlock the sender account *)
  let%bind _ = Poke.Account.unlock ~graphql_uri in
  (* mint tokens; relies on earlier create_tokens so we have a valid token id *)
  let%bind hash =
    Poke.SendTransaction.mint_tokens ~fee:(`Int 2_000_000_000)
      ~receiver:Poke.pk ~token:(`String "2") ~amount:(`Int 1_000_000_000)
      ~graphql_uri ()
  in
  verify_in_mempool_and_block ~logger ~rosetta_uri ~graphql_uri ~txn_hash:hash
    ~network_response
    ~operation_expectations:
      Operation_expectation.
        [ { amount= Some (-2_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None }
        ; { amount= Some 1_000_000_000
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 2}
          ; status= "Pending"
          ; _type= "mint_tokens"
          ; target= Some Poke.pk } ]

let construction_api_transaction_through_mempool ~logger ~rosetta_uri
    ~graphql_uri ~network_response ~operation_expectations
    ~plus_further_mempool_expecations ~operations =
  let open Deferred.Result.Let_syntax in
  let keys =
    Signer.Keys.of_private_key_box
      {| {"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"8jGuTAxw3zxtWasVqcD1H6rEojHLS1yJmG3aHHd","pwsalt":"AiUCrMJ6243h3TBmZ2rqt3Voim1Y","pwdiff":[134217728,6],"ciphertext":"DbAy736GqEKWe9NQWT4yaejiZUo9dJ6rsK7cpS43APuEf5AH1Qw6xb1s35z8D2akyLJBrUr6m"} |}
  in
  let%bind derive_res =
    Offline.Derive.req ~logger ~rosetta_uri ~network_response
      ~public_key_hex_bytes:keys.public_key_hex_bytes
  in
  let operations = operations derive_res.address in
  let%bind preprocess_res =
    Offline.Preprocess.req ~logger ~rosetta_uri ~network_response
      ~max_fee:(Unsigned.UInt64.of_int 100_000_000_000)
      ~operations
  in
  let%bind metadata_res =
    Peek.Construction.metadata ~rosetta_uri ~network_response ~logger
      ~options:(Option.value_exn preprocess_res.options)
  in
  [%log debug]
    ~metadata:[("res", Construction_metadata_response.to_yojson metadata_res)]
    "Construction_metadata result $res" ;
  let%bind payloads_res =
    Offline.Payloads.req ~logger ~rosetta_uri ~network_response ~operations
      ~metadata:metadata_res.metadata
  in
  let%bind payloads_parse_res =
    Offline.Parse.req ~logger ~rosetta_uri ~network_response
      ~transaction:
        (`Unsigned
          payloads_res.Construction_payloads_response.unsigned_transaction)
  in
  if not ([%equal: Operation.t list] operations payloads_parse_res.operations)
  then (
    [%log debug]
      ~metadata:
        [ ("expected", [%to_yojson: Operation.t list] operations)
        ; ( "actual"
          , [%to_yojson: Operation.t list] payloads_parse_res.operations ) ]
      "Construction_parse : Expected $expected, after payloads+parse $actual" ;
    failwith "Operations are not equal before and after payloads+parse" ) ;
  let%bind signature =
    Signer.sign ~keys
      ~unsigned_transaction_string:payloads_res.unsigned_transaction
    |> Deferred.return
  in
  let%bind combine_res =
    Offline.Combine.req ~logger ~rosetta_uri ~network_response ~signature
      ~unsigned_transaction:payloads_res.unsigned_transaction
      ~public_key_hex_bytes:keys.public_key_hex_bytes
      ~address:derive_res.address
  in
  let%bind combine_parse_res =
    Offline.Parse.req ~logger ~rosetta_uri ~network_response
      ~transaction:
        (`Signed combine_res.Construction_combine_response.signed_transaction)
  in
  if not ([%equal: Operation.t list] operations combine_parse_res.operations)
  then (
    [%log debug]
      ~metadata:
        [ ("expected", [%to_yojson: Operation.t list] operations)
        ; ( "actual"
          , [%to_yojson: Operation.t list] combine_parse_res.operations ) ]
      "Construction_combine : Expected $expected, after combine+parse $actual" ;
    failwith "Operations are not equal before and after combine+parse" ) ;
  let%bind hash_res =
    Offline.Hash.req ~logger ~rosetta_uri ~network_response
      ~signed_transaction:combine_res.signed_transaction
  in
  let%bind verified_bool =
    Signer.verify ~public_key_hex_bytes:keys.public_key_hex_bytes
      ~signed_transaction_string:combine_res.signed_transaction
    |> Deferred.return
  in
  let%bind () =
    if verified_bool then return ()
    else
      Deferred.Result.fail
        (Errors.create ~context:"Bad signature created during construction"
           `Invariant_violation)
  in
  let%bind submit_res =
    Peek.Construction.submit ~logger ~rosetta_uri ~network_response
      ~signed_transaction:combine_res.signed_transaction
  in
  assert (
    String.equal hash_res.Construction_hash_response.transaction_hash
      submit_res.transaction_identifier.hash ) ;
  [%log debug] "Construction_submit is finalized" ;
  verify_in_mempool_and_block ~logger ~rosetta_uri ~graphql_uri
    ~txn_hash:hash_res.transaction_hash ~network_response
    ~operation_expectations ~plus_further_mempool_expecations

let construction_api_payment_through_mempool =
  construction_api_transaction_through_mempool
    ~operations:(fun address ->
      Poke.SendTransaction.payment_operations ~from:address
        ~fee:(Unsigned.UInt64.of_int 3_000_000_000)
        ~amount:(Unsigned.UInt64.of_int 10_000_000_000)
        ~to_:other_pk )
    ~operation_expectations:
      Operation_expectation.
        [ { amount= Some (-10_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "payment_source_dec"
          ; target= None }
        ; { amount= Some 10_000_000_000
          ; account=
              Some {Account.pk= other_pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "payment_receiver_inc"
          ; target= None }
        ; { amount= Some (-3_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None } ]
    ~plus_further_mempool_expecations:
      Operation_expectation.
        [ { amount= Some (-3_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None } ]

let construction_api_delegation_through_mempool =
  construction_api_transaction_through_mempool
    ~operations:(fun address ->
      Poke.SendTransaction.delegation_operations ~from:address
        ~fee:(Unsigned.UInt64.of_int 5_000_000_000)
        ~to_:other_pk )
    ~operation_expectations:
      Operation_expectation.
        [ { amount= None
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "delegate_change"
          ; target= Some other_pk } ]
    ~plus_further_mempool_expecations:
      Operation_expectation.
        [ { amount= Some (-5_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None } ]

let construction_api_create_token_through_mempool =
  construction_api_transaction_through_mempool
    ~operations:(fun address ->
      Poke.SendTransaction.create_token_operations ~sender:address
        ~fee:(Unsigned.UInt64.of_int 5_000_000_000) )
    ~operation_expectations:
      Operation_expectation.
        [ { amount= Some (-5_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None }
        ; { amount= None
          ; account= None
          ; status= "Pending"
          ; _type= "create_token"
          ; target= None } ]

let construction_api_create_token_account_through_mempool =
  construction_api_transaction_through_mempool
    ~operations:(fun address ->
      Poke.SendTransaction.create_token_operations ~sender:address
        ~fee:(Unsigned.UInt64.of_int 5_000_000_000) )
    ~operation_expectations:
      Operation_expectation.
        [ { amount= Some (-5_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None } ]

let construction_api_mint_tokens_through_mempool =
  construction_api_transaction_through_mempool
    ~operations:(fun address ->
      Poke.SendTransaction.mint_tokens_operations ~sender:address
        ~receiver:address
        ~amount:(Unsigned.UInt64.of_int 1_000_000_000)
        ~fee:(Unsigned.UInt64.of_int 3_000_000_000) )
    ~operation_expectations:
      Operation_expectation.
        [ { amount= Some (-3_000_000_000)
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
          ; status= "Pending"
          ; _type= "fee_payer_dec"
          ; target= None }
        ; { amount= Some 1_000_000_000
          ; account=
              Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 2}
          ; status= "Pending"
          ; _type= "mint_tokens"
          ; target= Some Poke.pk } ]

(* for each possible user command, run the command via GraphQL, check that
    the command is in the transaction pool
*)
let check_new_account_user_commands ~logger ~rosetta_uri ~graphql_uri =
  let open Core.Time in
  let open Deferred.Result.Let_syntax in
  (* Stop staking so we can rely on things being in the mempool *)
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  (* Figure out our network identifier *)
  let%bind network_response = Peek.Network.list ~rosetta_uri ~logger in
  (* Wait until we are "synced" -- on debug nets this is when block production begins *)
  let%bind () =
    keep_trying
      ~step:(fun () ->
        let status_r_dr =
          Peek.Network.status ~rosetta_uri ~network_response ~logger
        in
        let%map status_r = status_r_dr in
        if
          [%eq: (string option, Error.t) result]
            (Result.map status_r ~f:(fun status ->
                 Option.bind status.Network_status_response.sync_status
                   ~f:(fun sync_status -> sync_status.stage) ))
            (Ok (Some "Synced"))
        then `Succeeded ()
        else `Failed )
      ~retry_count:15 ~initial_delay:(Span.of_sec 0.5)
      ~each_delay:(Span.of_sec 1.0) ~failure_reason:"Took too long to sync"
  in
  (* Directly create a payment in graphql and make sure it's in the mempool
       * properly, and then in a block properly *)
  [%log info] "Starting payment check" ;
  let%bind () =
    direct_graphql_payment_through_block ~logger ~rosetta_uri ~graphql_uri
      ~network_response
  in
  [%log info] "Created payment and waited" ;
  (* Stop staking so we can rely on things being in the mempool again *)
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  (* Follow the full construction API flow and make sure the submitted
   * transaction appears in the mempool *)
  [%log info] "Starting construction payment check" ;
  let%bind () =
    construction_api_payment_through_mempool ~logger ~rosetta_uri ~graphql_uri
      ~network_response
  in
  [%log info] "Created construction payment and waited" ;
  (* Stop staking *)
  [%log info] "Starting delegation check" ;
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  let%bind () =
    direct_graphql_delegation_through_block ~logger ~rosetta_uri ~graphql_uri
      ~network_response
  in
  [%log info] "Created graphql delegation and waited" ;
  (* Stop staking *)
  [%log info] "Starting construction delegation check" ;
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  let%bind () =
    construction_api_delegation_through_mempool ~logger ~rosetta_uri
      ~graphql_uri ~network_response
  in
  [%log info] "Created construction delegation and waited" ;
  (* Stop staking *)
  [%log info] "Starting create token check" ;
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  let%bind () =
    direct_graphql_create_token_through_block ~logger ~rosetta_uri ~graphql_uri
      ~network_response
  in
  [%log info] "Created token via graphql and waited" ;
  [%log info] "Starting create token construction check" ;
  let%bind () =
    construction_api_create_token_through_mempool ~logger ~rosetta_uri
      ~graphql_uri ~network_response
  in
  [%log info] "Created token using construction and waited" ;
  (* Stop staking *)
  [%log info] "Starting create token account check" ;
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  let%bind () =
    direct_graphql_create_token_account_through_block ~logger ~rosetta_uri
      ~graphql_uri ~network_response
  in
  [%log info] "Created token account and waited" ;
  [%log info] "Starting construction create token account check" ;
  let%bind () =
    construction_api_create_token_account_through_mempool ~logger ~rosetta_uri
      ~graphql_uri ~network_response
  in
  [%log info] "Created token account using construction and waited" ;
  (* Stop staking *)
  [%log info] "Starting mint tokens check" ;
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  let%bind () =
    direct_graphql_mint_tokens_through_block ~logger ~rosetta_uri ~graphql_uri
      ~network_response
  in
  [%log info] "Minted tokens and waited" ;
  [%log info] "Starting construction mint tokens check" ;
  let%bind () =
    construction_api_mint_tokens_through_mempool ~logger ~rosetta_uri
      ~graphql_uri ~network_response
  in
  [%log info] "Minted tokens using construction and waited" ;
  (* Success *)
  return ()

let run ~logger ~rosetta_uri ~graphql_uri ~don't_exit =
  let open Core.Time in
  let open Deferred.Result.Let_syntax in
  let%bind () =
    check_new_account_user_commands ~logger ~rosetta_uri ~graphql_uri
  in
  [%log info] "Finished running test-agent" ;
  if don't_exit then (
    let%bind _res = Poke.Staking.enable ~graphql_uri in
    [%log info] "Running forever with more blocks" ;
    let rec go () =
      let%bind () = wait (Span.of_sec 1.0) in
      go ()
    in
    go () )
  else (
    [%log info] "Exiting" ;
    return () )

let command =
  let open Command.Let_syntax in
  let%map_open rosetta_uri =
    flag "rosetta-uri" ~doc:"URI of Rosetta endpoint to connect to"
      Cli.required_uri
  and graphql_uri =
    flag "graphql-uri" ~doc:"URI of Coda GraphQL endpoint to connect to"
      Cli.required_uri
  and log_json =
    flag "log-json" ~doc:"Print log output as JSON (default: plain text)"
      no_arg
  and log_level =
    flag "log-level" ~doc:"Set log level (default: Info)" Cli.log_level
  and don't_exit =
    flag "dont-exit" ~doc:"Don't exit after tests finish (default: do exit)"
      no_arg
  in
  let open Deferred.Let_syntax in
  fun () ->
    let logger = Logger.create () in
    Cli.logger_setup log_json log_level ;
    [%log info] "Rosetta test-agent starting" ;
    match%bind run ~logger ~rosetta_uri ~graphql_uri ~don't_exit with
    | Ok () ->
        [%log info] "Rosetta test-agent stopping successfully" ;
        return ()
    | Error e ->
        [%log error] "Rosetta test-agent stopping with a failure: %s"
          (Errors.show e) ;
        exit 1

let () =
  Command.run
    (Command.async ~summary:"Run agent to poke at Coda and peek at Rosetta"
       command)
