(** An agent that pokes at Coda and peeks at Rosetta to see if things look alright *)

open Core_kernel
open Lib
open Async
open Models

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

let direct_graphql_payment_through_block ~logger ~rosetta_uri ~graphql_uri
    ~network_response =
  let open Core.Time in
  let open Deferred.Result.Let_syntax in
  (* Unlock the account *)
  let%bind _ = Poke.Account.unlock ~graphql_uri in
  (* Send a payment *)
  let%bind hash =
    Poke.SendTransaction.payment ~fee:(`Int 2_000_000_000)
      ~amount:(`Int 5_000_000_000) ~to_:(`String other_pk) ~graphql_uri ()
  in
  let%bind () = wait (Span.of_sec 1.0) in
  (* Grab the mempool and find the payment inside *)
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
                  String.equal ident.Transaction_identifier.hash hash ) )
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
    Peek.Mempool.transaction ~rosetta_uri ~network_response ~logger ~hash
  in
  [%log debug]
    ~metadata:
      [ ( "operations"
        , mempool_res.transaction.operations |> [%to_yojson: Operation.t list]
        ) ]
    "Mempool operations: $operations" ;
  let expected_mempool_ops =
    Operation_expectation.
      [ { amount= Some (-5_000_000_000)
        ; account=
            Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
        ; status= "Pending"
        ; _type= "payment_source_dec" }
      ; { amount= Some (-2_000_000_000)
        ; account=
            Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
        ; status= "Pending"
        ; _type= "fee_payer_dec" }
      ; { amount= Some 5_000_000_000
        ; account=
            Some {Account.pk= other_pk; token_id= Unsigned.UInt64.of_int 1}
        ; status= "Pending"
        ; _type= "payment_receiver_inc" } ]
  in
  let%bind () =
    Operation_expectation.assert_similar_operations
      ~expected:expected_mempool_ops ~actual:mempool_res.transaction.operations
      ~situation:"mempool"
  in
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
  (* Start staking so we get blocks *)
  let%bind _res = Poke.Staking.enable ~graphql_uri in
  (* Wait until the newest-block is at least index>last_block_index *)
  let%bind block =
    keep_trying
      ~step:(fun () ->
        let%map block_r =
          Peek.Block.newest_block ~rosetta_uri ~network_response ~logger
        in
        match
          Result.map block_r ~f:(fun block ->
              if
                Int64.(
                  (Option.value_exn block.Block_response.block)
                    .block_identifier
                    .index > last_block_index)
              then Some block
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
  (* Stop noisy block production *)
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  let succesful (x : Operation_expectation.t) = {x with status= "Success"} in
  Logger.info logger "GOT BLOCK $block" ~module_:__MODULE__ ~location:__LOC__
    ~metadata:[("block", Block_response.to_yojson block)] ;
  Operation_expectation.assert_similar_operations
    ~expected:
      ( List.map ~f:succesful expected_mempool_ops
      @ Operation_expectation.
          [ { amount= Some 20_000_000_000
            ; account=
                Some {Account.pk= Poke.pk; token_id= Unsigned.UInt64.of_int 1}
            ; status= "Success"
            ; _type= "coinbase_inc" } ] )
    ~actual:
      ( List.map (Option.value_exn block.block).transactions ~f:(fun txn ->
            txn.operations )
      |> List.join )
    ~situation:"block"

let construction_api_payment_through_mempool ~logger ~rosetta_uri
    ~graphql_uri:_ ~network_response =
  let open Deferred.Result.Let_syntax in
  let keys =
    Signer.Keys.of_private_key_box
      {| {"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"8jGuTAxw3zxtWasVqcD1H6rEojHLS1yJmG3aHHd","pwsalt":"AiUCrMJ6243h3TBmZ2rqt3Voim1Y","pwdiff":[134217728,6],"ciphertext":"DbAy736GqEKWe9NQWT4yaejiZUo9dJ6rsK7cpS43APuEf5AH1Qw6xb1s35z8D2akyLJBrUr6m"} |}
  in
  let%bind derive_res =
    Offline.Derive.req ~logger ~rosetta_uri ~network_response
      ~public_key_hex_bytes:keys.public_key_hex_bytes
  in
  let operations =
    Poke.SendTransaction.payment_operations ~from:derive_res.address
      ~fee:(Unsigned.UInt64.of_int 3_000_000_000)
      ~amount:(Unsigned.UInt64.of_int 10_000_000_000)
      ~to_:other_pk
  in
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
  let%bind parse_res =
    Offline.Parse.req ~logger ~rosetta_uri ~network_response
      ~transaction:
        (`Unsigned
          payloads_res.Construction_payloads_response.unsigned_transaction)
  in
  if not ([%equal: Operation.t list] operations parse_res.operations) then (
    [%log debug]
      ~metadata:
        [ ("expected", [%to_yojson: Operation.t list] operations)
        ; ("actual", [%to_yojson: Operation.t list] parse_res.operations) ]
      "Construction_parse : Expected $expected, after payloads+parse $actual" ;
    failwith "Operations are not equal before and after payloads+parse" ) ;
  return ()

(* TODO: Break up this function in the next PR *)
let check_new_account_payment ~logger ~rosetta_uri ~graphql_uri =
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
  let%bind () =
    direct_graphql_payment_through_block ~logger ~rosetta_uri ~graphql_uri
      ~network_response
  in
  (* Stop staking so we can rely on things being in the mempool again *)
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  (* Follow the full construction API flow and make sure the submitted
       * transaction appears in the mempool *)
  let%bind () =
    construction_api_payment_through_mempool ~logger ~rosetta_uri ~graphql_uri
      ~network_response
  in
  (* Succeed! (for now) *)
  return ()

let run ~logger ~rosetta_uri ~graphql_uri =
  let open Deferred.Result.Let_syntax in
  let%bind () = check_new_account_payment ~logger ~rosetta_uri ~graphql_uri in
  [%log info] "Finished running test-agent" ;
  return ()

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
  in
  let open Deferred.Let_syntax in
  fun () ->
    let logger = Logger.create () in
    Cli.logger_setup log_json log_level ;
    [%log info] "Rosetta test-agent starting" ;
    match%bind run ~logger ~rosetta_uri ~graphql_uri with
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
