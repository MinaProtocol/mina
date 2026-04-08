open Core
open Async

let graphql_uri_flag =
  Command.Param.(
    flag "--graphql-uri"
      ~doc:"URI GraphQL endpoint URI (default: http://127.0.0.1:3085/graphql)"
      (optional_with_default "http://127.0.0.1:3085/graphql" string))

let node_password_flag =
  Command.Param.(
    flag "--node-password"
      ~doc:"PASSWORD Node wallet password (default: test password)"
      (optional_with_default Mina_graphql_client.Client.default_node_password
         string ))

let peer_command =
  Command.async ~summary:"Query peer ID and connected peers"
    (let%map_open.Command uri_str = graphql_uri_flag in
     fun () ->
       let logger = Logger.create () in
       let node_uri = Uri.of_string uri_str in
       let%map result =
         Mina_graphql_client.Client.get_peer_id ~logger node_uri
       in

       Yojson.Safe.pretty_to_channel Out_channel.stdout
         ( match result with
         | Ok (self_id, peer_ids) ->
             `Assoc
               [ ("peer_id", `String self_id)
               ; ( "connected_peers"
                 , `List (List.map peer_ids ~f:(fun p -> `String p)) )
               ]
         | Error e ->
             `Assoc [ ("error", Error_json.error_to_yojson e) ] ) )

let account_command =
  Command.async ~summary:"Query account balance and nonce"
    (let%map_open.Command uri_str = graphql_uri_flag
     and public_key_str =
       flag "--public-key" ~doc:"PUBLIC_KEY Public key of the account to query"
         (required string)
     in
     fun () ->
       let logger = Logger.create () in
       let node_uri = Uri.of_string uri_str in
       let public_key =
         Signature_lib.Public_key.Compressed.of_base58_check_exn public_key_str
       in
       let account_id =
         Mina_base.Account_id.create public_key Mina_base.Token_id.default
       in
       let%map result =
         Mina_graphql_client.Client.get_account_data ~logger node_uri
           ~account_id
       in
       Yojson.Safe.pretty_to_channel Out_channel.stdout
         ( match result with
         | Ok data ->
             `Assoc
               ( [ ("nonce", Mina_numbers.Account_nonce.to_yojson data.nonce)
                 ; ( "total_balance"
                   , Currency.Balance.to_yojson data.total_balance )
                 ]
               @ ( match data.liquid_balance_opt with
                 | Some bal ->
                     [ ("liquid_balance", Currency.Balance.to_yojson bal) ]
                 | None ->
                     [] )
               @
               match data.locked_balance_opt with
               | Some bal ->
                   [ ("locked_balance", Currency.Balance.to_yojson bal) ]
               | None ->
                   [] )
         | Error e ->
             `Assoc [ ("error", Error_json.error_to_yojson e) ] ) )

let best_chain_command =
  Command.async ~summary:"Query best chain blocks"
    (let%map_open.Command uri_str = graphql_uri_flag
     and max_length =
       flag "--max-length" ~doc:"N Maximum number of blocks to return"
         (optional int)
     in
     fun () ->
       let logger = Logger.create () in
       let node_uri = Uri.of_string uri_str in
       let%map result =
         Mina_graphql_client.Client.get_best_chain ?max_length ~logger node_uri
       in

       Yojson.Safe.pretty_to_channel Out_channel.stdout
         ( match result with
         | Ok blocks ->
             `List
               (List.map blocks
                  ~f:(fun (block : Mina_graphql_client.Types.best_chain_block)
                     ->
                    `Assoc
                      [ ("height", Mina_numbers.Length.to_yojson block.height)
                      ; ( "global_slot_since_hard_fork"
                        , Mina_numbers.Global_slot_since_hard_fork.to_yojson
                            block.global_slot_since_hard_fork )
                      ; ("state_hash", `String block.state_hash)
                      ; ("creator_pk", `String block.creator_pk)
                      ; ( "command_transaction_count"
                        , `Int block.command_transaction_count )
                      ] ) )
         | Error e ->
             `Assoc [ ("error", Error_json.error_to_yojson e) ] ) )

let metrics_command =
  Command.async ~summary:"Query daemon metrics"
    (let%map_open.Command uri_str = graphql_uri_flag in
     fun () ->
       let logger = Logger.create () in
       let node_uri = Uri.of_string uri_str in
       let%map result =
         Mina_graphql_client.Client.get_metrics ~logger node_uri
       in

       Yojson.Safe.pretty_to_channel Out_channel.stdout
         ( match result with
         | Ok metrics ->
             `Assoc
               [ ( "block_production_delay"
                 , `List
                     (List.map
                        ~f:(fun d -> `Int d)
                        metrics.block_production_delay ) )
               ; ("transaction_pool_size", `Int metrics.transaction_pool_size)
               ; ( "transactions_added_to_pool"
                 , `Int metrics.transactions_added_to_pool )
               ; ( "transaction_pool_diff_received"
                 , `Int metrics.transaction_pool_diff_received )
               ; ( "transaction_pool_diff_broadcasted"
                 , `Int metrics.transaction_pool_diff_broadcasted )
               ]
         | Error e ->
             `Assoc [ ("error", Error_json.error_to_yojson e) ] ) )

let slot_command =
  Command.async ~summary:"Query current global slot since hard fork"
    (let%map_open.Command uri_str = graphql_uri_flag in
     fun () ->
       let open Deferred.Let_syntax in
       let logger = Logger.create () in
       let node_uri = Uri.of_string uri_str in
       let%map result =
         Mina_graphql_client.Client.get_global_slot_since_hard_fork ~logger
           node_uri
       in

       Yojson.Safe.pretty_to_channel Out_channel.stdout
         ( match result with
         | Ok slot ->
             `Assoc
               [ ( "global_slot_since_hard_fork"
                 , Mina_numbers.Global_slot_since_hard_fork.to_yojson slot )
               ]
         | Error e ->
             `Assoc [ ("error", Error_json.error_to_yojson e) ] ) )

let send_payment_command =
  Command.async ~summary:"Send a payment (requires unlocked account on node)"
    (let%map_open.Command uri_str = graphql_uri_flag
     and node_password = node_password_flag
     and sender_str =
       flag "--sender" ~doc:"PUBLIC_KEY Sender public key" (required string)
     and receiver_str =
       flag "--receiver" ~doc:"PUBLIC_KEY Receiver public key" (required string)
     and amount_str =
       flag "--amount" ~doc:"AMOUNT Amount to send in mina" (required string)
     and fee_str =
       flag "--fee" ~doc:"FEE Transaction fee in mina" (required string)
     in
     fun () ->
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
       let%map result =
         Mina_graphql_client.Client.send_online_payment ~node_password ~logger
           node_uri ~sender_pub_key ~receiver_pub_key ~amount ~fee
       in

       Yojson.Safe.pretty_to_channel Out_channel.stdout
         ( match result with
         | Ok res ->
             `Assoc
               [ ("status", `String "success")
               ; ("id", `String res.id)
               ; ( "hash"
                 , `String
                     (Mina_transaction.Transaction_hash.to_base58_check res.hash)
                 )
               ; ("nonce", Mina_numbers.Account_nonce.to_yojson res.nonce)
               ]
         | Error e ->
             `Assoc [ ("error", Error_json.error_to_yojson e) ] ) )

let delegation_command =
  Command.async ~summary:"Send a stake delegation (requires unlocked account)"
    (let%map_open.Command uri_str = graphql_uri_flag
     and node_password = node_password_flag
     and sender_str =
       flag "--sender" ~doc:"PUBLIC_KEY Delegator public key" (required string)
     and receiver_str =
       flag "--receiver" ~doc:"PUBLIC_KEY Delegate-to public key"
         (required string)
     and fee_str =
       flag "--fee" ~doc:"FEE Transaction fee in mina" (required string)
     in
     fun () ->
       let logger = Logger.create () in
       let node_uri = Uri.of_string uri_str in
       let sender_pub_key =
         Signature_lib.Public_key.Compressed.of_base58_check_exn sender_str
       in
       let receiver_pub_key =
         Signature_lib.Public_key.Compressed.of_base58_check_exn receiver_str
       in
       let fee = Currency.Fee.of_mina_string_exn fee_str in
       let%map result =
         Mina_graphql_client.Client.send_delegation ~node_password ~logger
           node_uri ~sender_pub_key ~receiver_pub_key ~fee
       in

       Yojson.Safe.pretty_to_channel Out_channel.stdout
         ( match result with
         | Ok res ->
             `Assoc
               [ ("status", `String "success")
               ; ("id", `String res.id)
               ; ( "hash"
                 , `String
                     (Mina_transaction.Transaction_hash.to_base58_check res.hash)
                 )
               ; ("nonce", Mina_numbers.Account_nonce.to_yojson res.nonce)
               ]
         | Error e ->
             `Assoc [ ("error", Error_json.error_to_yojson e) ] ) )

let set_snark_worker_command =
  Command.async ~summary:"Set the SNARK worker key"
    (let%map_open.Command uri_str = graphql_uri_flag
     and public_key_str =
       flag "--public-key" ~doc:"PUBLIC_KEY SNARK worker public key"
         (required string)
     in
     fun () ->
       let logger = Logger.create () in
       let node_uri = Uri.of_string uri_str in
       let new_snark_pub_key =
         Signature_lib.Public_key.Compressed.of_base58_check_exn public_key_str
       in
       let%map result =
         Mina_graphql_client.Client.set_snark_worker ~logger node_uri
           ~new_snark_pub_key
       in

       Yojson.Safe.pretty_to_channel Out_channel.stdout
         ( match result with
         | Ok () ->
             `Assoc [ ("status", `String "success") ]
         | Error e ->
             `Assoc [ ("error", Error_json.error_to_yojson e) ] ) )

let set_snark_fee_command =
  Command.async ~summary:"Set the SNARK work fee"
    (let%map_open.Command uri_str = graphql_uri_flag
     and fee_str =
       flag "--fee" ~doc:"FEE SNARK work fee in mina" (required string)
     in
     fun () ->
       let logger = Logger.create () in
       let node_uri = Uri.of_string uri_str in
       let fee = Currency.Fee.of_mina_string_exn fee_str in
       let fee_nanomina = Currency.Fee.to_nanomina_int fee in
       let%map result =
         Mina_graphql_client.Client.set_snark_work_fee ~logger node_uri
           ~new_snark_work_fee:fee_nanomina
       in

       Yojson.Safe.pretty_to_channel Out_channel.stdout
         ( match result with
         | Ok () ->
             `Assoc [ ("status", `String "success") ]
         | Error e ->
             `Assoc [ ("error", Error_json.error_to_yojson e) ] ) )

let () =
  Command.run
    (Command.group ~summary:"Mina GraphQL client utility"
       [ ("peer", peer_command)
       ; ("account", account_command)
       ; ("best-chain", best_chain_command)
       ; ("metrics", metrics_command)
       ; ("slot", slot_command)
       ; ("send-payment", send_payment_command)
       ; ("delegation", delegation_command)
       ; ("set-snark-worker", set_snark_worker_command)
       ; ("set-snark-fee", set_snark_fee_command)
       ] )
