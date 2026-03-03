open Core
open Async

let graphql_uri_flag =
  Command.Param.(
    flag "--graphql-uri" ~aliases:[ "graphql-uri" ]
      ~doc:"URI GraphQL endpoint URI (default: http://127.0.0.1:3085/graphql)"
      (optional_with_default "http://127.0.0.1:3085/graphql" string))

let node_password_flag =
  Command.Param.(
    flag "--node-password" ~aliases:[ "node-password" ]
      ~doc:"PASSWORD Node wallet password (default: test password)"
      (optional_with_default Mina_graphql_client.Client.default_node_password
         string ))

let status_command =
  Command.async ~summary:"Query daemon status (peer id, sync state)"
    (let open Command.Let_syntax in
    let%map_open uri_str = graphql_uri_flag in
    fun () ->
      let open Deferred.Let_syntax in
      let logger = Logger.create () in
      let node_uri = Uri.of_string uri_str in
      let%bind result =
        Mina_graphql_client.Client.get_peer_id ~logger node_uri
      in
      ( match result with
      | Ok (self_id, peer_ids) ->
          printf "Peer ID: %s\n" self_id ;
          printf "Connected peers (%d):\n" (List.length peer_ids) ;
          List.iter peer_ids ~f:(fun pid -> printf "  %s\n" pid)
      | Error e ->
          eprintf "Error: %s\n" (Error.to_string_hum e) ) ;
      return ())

let account_command =
  Command.async ~summary:"Query account balance and nonce"
    (let open Command.Let_syntax in
    let%map_open uri_str = graphql_uri_flag
    and public_key_str =
      flag "--public-key" ~aliases:[ "public-key" ]
        ~doc:"PUBLIC_KEY Public key of the account to query" (required string)
    in
    fun () ->
      let open Deferred.Let_syntax in
      let logger = Logger.create () in
      let node_uri = Uri.of_string uri_str in
      let public_key =
        Signature_lib.Public_key.Compressed.of_base58_check_exn public_key_str
      in
      let account_id =
        Mina_base.Account_id.create public_key Mina_base.Token_id.default
      in
      let%bind result =
        Mina_graphql_client.Client.get_account_data ~logger node_uri ~account_id
      in
      ( match result with
      | Ok data ->
          printf "Nonce: %s\n" (Mina_numbers.Account_nonce.to_string data.nonce) ;
          printf "Total balance: %s\n"
            (Currency.Balance.to_mina_string data.total_balance) ;
          Option.iter data.liquid_balance_opt ~f:(fun bal ->
              printf "Liquid balance: %s\n"
                (Currency.Balance.to_mina_string bal) ) ;
          Option.iter data.locked_balance_opt ~f:(fun bal ->
              printf "Locked balance: %s\n"
                (Currency.Balance.to_mina_string bal) )
      | Error e ->
          eprintf "Error: %s\n" (Error.to_string_hum e) ) ;
      return ())

let best_chain_command =
  Command.async ~summary:"Query best chain blocks"
    (let open Command.Let_syntax in
    let%map_open uri_str = graphql_uri_flag
    and max_length =
      flag "--max-length" ~aliases:[ "max-length" ]
        ~doc:"N Maximum number of blocks to return" (optional int)
    in
    fun () ->
      let open Deferred.Let_syntax in
      let logger = Logger.create () in
      let node_uri = Uri.of_string uri_str in
      let%bind result =
        Mina_graphql_client.Client.get_best_chain ?max_length ~logger node_uri
      in
      ( match result with
      | Ok blocks ->
          List.iter blocks
            ~f:(fun (block : Mina_graphql_client.Types.best_chain_block) ->
              printf "Block height=%s slot=%s hash=%s creator=%s txns=%d\n"
                (Mina_numbers.Length.to_string block.height)
                (Mina_numbers.Global_slot_since_hard_fork.to_string
                   block.global_slot_since_hard_fork )
                block.state_hash block.creator_pk
                block.command_transaction_count )
      | Error e ->
          eprintf "Error: %s\n" (Error.to_string_hum e) ) ;
      return ())

let metrics_command =
  Command.async ~summary:"Query daemon metrics"
    (let open Command.Let_syntax in
    let%map_open uri_str = graphql_uri_flag in
    fun () ->
      let open Deferred.Let_syntax in
      let logger = Logger.create () in
      let node_uri = Uri.of_string uri_str in
      let%bind result =
        Mina_graphql_client.Client.get_metrics ~logger node_uri
      in
      ( match result with
      | Ok metrics ->
          printf "Block production delay: [%s]\n"
            (String.concat ~sep:", "
               (List.map ~f:string_of_int metrics.block_production_delay) ) ;
          printf "Transaction pool size: %d\n" metrics.transaction_pool_size ;
          printf "Transactions added to pool: %d\n"
            metrics.transactions_added_to_pool ;
          printf "Transaction pool diff received: %d\n"
            metrics.transaction_pool_diff_received ;
          printf "Transaction pool diff broadcasted: %d\n"
            metrics.transaction_pool_diff_broadcasted
      | Error e ->
          eprintf "Error: %s\n" (Error.to_string_hum e) ) ;
      return ())

let slot_command =
  Command.async ~summary:"Query current global slot since hard fork"
    (let open Command.Let_syntax in
    let%map_open uri_str = graphql_uri_flag in
    fun () ->
      let open Deferred.Let_syntax in
      let logger = Logger.create () in
      let node_uri = Uri.of_string uri_str in
      let%bind result =
        Mina_graphql_client.Client.get_global_slot_since_hard_fork ~logger
          node_uri
      in
      ( match result with
      | Ok slot ->
          printf "Global slot since hard fork: %s\n"
            (Mina_numbers.Global_slot_since_hard_fork.to_string slot)
      | Error e ->
          eprintf "Error: %s\n" (Error.to_string_hum e) ) ;
      return ())

let send_payment_command =
  Command.async ~summary:"Send a payment (requires unlocked account on node)"
    (let open Command.Let_syntax in
    let%map_open uri_str = graphql_uri_flag
    and node_password = node_password_flag
    and sender_str =
      flag "--sender" ~aliases:[ "sender" ] ~doc:"PUBLIC_KEY Sender public key"
        (required string)
    and receiver_str =
      flag "--receiver" ~aliases:[ "receiver" ]
        ~doc:"PUBLIC_KEY Receiver public key" (required string)
    and amount_str =
      flag "--amount" ~aliases:[ "amount" ] ~doc:"AMOUNT Amount to send in mina"
        (required string)
    and fee_str =
      flag "--fee" ~aliases:[ "fee" ] ~doc:"FEE Transaction fee in mina"
        (required string)
    in
    fun () ->
      let open Deferred.Let_syntax in
      let logger = Logger.create () in
      let node_uri = Uri.of_string uri_str in
      let sender_pub_key =
        Signature_lib.Public_key.Compressed.of_base58_check_exn sender_str
      in
      let receiver_pub_key =
        Signature_lib.Public_key.Compressed.of_base58_check_exn receiver_str
      in
      let amount = Currency.Amount.of_mina_string_exn amount_str in
      let fee = Currency.Fee.of_mina_string_exn fee_str in
      let%bind result =
        Mina_graphql_client.Client.send_online_payment ~node_password ~logger
          node_uri ~sender_pub_key ~receiver_pub_key ~amount ~fee
      in
      ( match result with
      | Ok res ->
          printf "Payment sent successfully\n" ;
          printf "  ID: %s\n" res.id ;
          printf "  Hash: %s\n"
            (Mina_transaction.Transaction_hash.to_base58_check res.hash) ;
          printf "  Nonce: %s\n"
            (Mina_numbers.Account_nonce.to_string res.nonce)
      | Error e ->
          eprintf "Error: %s\n" (Error.to_string_hum e) ) ;
      return ())

let delegation_command =
  Command.async ~summary:"Send a stake delegation (requires unlocked account)"
    (let open Command.Let_syntax in
    let%map_open uri_str = graphql_uri_flag
    and node_password = node_password_flag
    and sender_str =
      flag "--sender" ~aliases:[ "sender" ]
        ~doc:"PUBLIC_KEY Delegator public key" (required string)
    and receiver_str =
      flag "--receiver" ~aliases:[ "receiver" ]
        ~doc:"PUBLIC_KEY Delegate-to public key" (required string)
    and fee_str =
      flag "--fee" ~aliases:[ "fee" ] ~doc:"FEE Transaction fee in mina"
        (required string)
    in
    fun () ->
      let open Deferred.Let_syntax in
      let logger = Logger.create () in
      let node_uri = Uri.of_string uri_str in
      let sender_pub_key =
        Signature_lib.Public_key.Compressed.of_base58_check_exn sender_str
      in
      let receiver_pub_key =
        Signature_lib.Public_key.Compressed.of_base58_check_exn receiver_str
      in
      let fee = Currency.Fee.of_mina_string_exn fee_str in
      let%bind result =
        Mina_graphql_client.Client.send_delegation ~node_password ~logger
          node_uri ~sender_pub_key ~receiver_pub_key ~fee
      in
      ( match result with
      | Ok res ->
          printf "Delegation sent successfully\n" ;
          printf "  ID: %s\n" res.id ;
          printf "  Hash: %s\n"
            (Mina_transaction.Transaction_hash.to_base58_check res.hash) ;
          printf "  Nonce: %s\n"
            (Mina_numbers.Account_nonce.to_string res.nonce)
      | Error e ->
          eprintf "Error: %s\n" (Error.to_string_hum e) ) ;
      return ())

let set_snark_worker_command =
  Command.async ~summary:"Set the SNARK worker key"
    (let open Command.Let_syntax in
    let%map_open uri_str = graphql_uri_flag
    and public_key_str =
      flag "--public-key" ~aliases:[ "public-key" ]
        ~doc:"PUBLIC_KEY SNARK worker public key" (required string)
    in
    fun () ->
      let open Deferred.Let_syntax in
      let logger = Logger.create () in
      let node_uri = Uri.of_string uri_str in
      let new_snark_pub_key =
        Signature_lib.Public_key.Compressed.of_base58_check_exn public_key_str
      in
      let%bind result =
        Mina_graphql_client.Client.set_snark_worker ~logger node_uri
          ~new_snark_pub_key
      in
      ( match result with
      | Ok () ->
          printf "SNARK worker key updated\n"
      | Error e ->
          eprintf "Error: %s\n" (Error.to_string_hum e) ) ;
      return ())

let set_snark_fee_command =
  Command.async ~summary:"Set the SNARK work fee"
    (let open Command.Let_syntax in
    let%map_open uri_str = graphql_uri_flag
    and fee =
      flag "--fee" ~aliases:[ "fee" ] ~doc:"FEE SNARK work fee in nanomina"
        (required int)
    in
    fun () ->
      let open Deferred.Let_syntax in
      let logger = Logger.create () in
      let node_uri = Uri.of_string uri_str in
      let%bind result =
        Mina_graphql_client.Client.set_snark_work_fee ~logger node_uri
          ~new_snark_work_fee:fee
      in
      ( match result with
      | Ok () ->
          printf "SNARK work fee updated\n"
      | Error e ->
          eprintf "Error: %s\n" (Error.to_string_hum e) ) ;
      return ())

let () =
  Command.run
    (Command.group ~summary:"Mina GraphQL client utility"
       [ ("status", status_command)
       ; ("account", account_command)
       ; ("best-chain", best_chain_command)
       ; ("metrics", metrics_command)
       ; ("slot", slot_command)
       ; ("send-payment", send_payment_command)
       ; ("delegation", delegation_command)
       ; ("set-snark-worker", set_snark_worker_command)
       ; ("set-snark-fee", set_snark_fee_command)
       ] )
