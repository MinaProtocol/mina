open Core
open Async
open Signature_lib
open Mina_base
open Mina_transaction

module Client = Graphql_lib.Client.Make (struct
  let preprocess_variables_string = Fn.id

  let headers = String.Map.empty
end)

module Args = struct
  open Command.Param

  let zip2 = map2 ~f:(fun arg1 arg2 -> (arg1, arg2))

  let zip3 = map3 ~f:(fun arg1 arg2 arg3 -> (arg1, arg2, arg3))

  let zip4 arg1 arg2 arg3 arg4 =
    return (fun a b c d -> (a, b, c, d)) <*> arg1 <*> arg2 <*> arg3 <*> arg4

  let zip5 arg1 arg2 arg3 arg4 arg5 =
    return (fun a b c d e -> (a, b, c, d, e))
    <*> arg1 <*> arg2 <*> arg3 <*> arg4 <*> arg5

  let zip6 arg1 arg2 arg3 arg4 arg5 arg6 =
    return (fun a b c d e f -> (a, b, c, d, e, f))
    <*> arg1 <*> arg2 <*> arg3 <*> arg4 <*> arg5 <*> arg6

  let zip7 arg1 arg2 arg3 arg4 arg5 arg6 arg7 =
    return (fun a b c d e f g -> (a, b, c, d, e, f, g))
    <*> arg1 <*> arg2 <*> arg3 <*> arg4 <*> arg5 <*> arg6 <*> arg7
end

let or_error_str ~f_ok ~error = function
  | Ok x ->
      f_ok x
  | Error e ->
      sprintf "%s\n%s\n" error (Error.to_string_hum e)

let stop_daemon =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  let open Command.Param in
  Command.async ~summary:"Stop the daemon"
    (Cli_lib.Background_daemon.rpc_init (return ()) ~f:(fun port () ->
         let%map res = Daemon_rpcs.Client.dispatch Stop_daemon.rpc () port in
         printf "%s"
           (or_error_str res
              ~f_ok:(fun _ -> "Daemon stopping\n")
              ~error:"Daemon likely stopped" ) ) )

let get_balance_graphql =
  let open Command.Param in
  let pk_flag =
    flag "--public-key" ~aliases:[ "public-key" ]
      ~doc:"PUBLICKEY Public key for which you want to check the balance"
      (required Cli_lib.Arg_type.public_key_compressed)
  in
  let token_flag =
    flag "--token" ~aliases:[ "token" ]
      ~doc:"TOKEN_ID The token ID for the account"
      (optional_with_default Token_id.default Cli_lib.Arg_type.token_id)
  in
  Command.async ~summary:"Get balance associated with a public key"
    (Cli_lib.Background_daemon.graphql_init (Args.zip2 pk_flag token_flag)
       ~f:(fun graphql_endpoint (public_key, token) ->
         let%map response =
           Graphql_client.query_exn
             Graphql_queries.Get_tracked_account.(
               make @@ makeVariables ~public_key ~token ())
             graphql_endpoint
         in
         match response.account with
         | Some account ->
             if Token_id.(equal default) token then
               printf "Balance: %s mina\n"
                 (Currency.Balance.to_mina_string account.balance.total)
             else
               printf "Balance: %s tokens\n"
                 (Currency.Balance.to_mina_string account.balance.total)
         | None ->
             printf "There are no funds in this account\n" ) )

let get_tokens_graphql =
  let open Command.Param in
  let pk_flag =
    flag "--public-key" ~aliases:[ "public-key" ]
      ~doc:"PUBLICKEY Public key for which you want to find accounts"
      (required Cli_lib.Arg_type.public_key_compressed)
  in
  Command.async ~summary:"Get all token IDs that a public key has accounts for"
    (Cli_lib.Background_daemon.graphql_init pk_flag
       ~f:(fun graphql_endpoint public_key ->
         let%map response =
           Graphql_client.query_exn
             Graphql_queries.Get_all_accounts.(
               make @@ makeVariables ~public_key ())
             graphql_endpoint
         in
         printf "Accounts are held for token IDs:\n" ;
         Array.iter response.accounts ~f:(fun account ->
             printf "%s " (Token_id.to_string account.tokenId) ) ) )

let get_time_offset_graphql =
  Command.async
    ~summary:
      "Get the time offset in seconds used by the daemon to convert real time \
       into blockchain time"
    (Cli_lib.Background_daemon.graphql_init (Command.Param.return ())
       ~f:(fun graphql_endpoint () ->
         let%map response =
           Graphql_client.query_exn
             Graphql_queries.Time_offset.(make @@ makeVariables ())
             graphql_endpoint
         in
         let time_offset = response.timeOffset in
         printf
           "Current time offset:\n\
            %i\n\n\
            Start other daemons with this offset by setting the \
            MINA_TIME_OFFSET environment variable in the shell before \
            executing them:\n\
            export MINA_TIME_OFFSET=%i\n"
           time_offset time_offset ) )

let print_trust_statuses statuses json =
  if json then
    printf "%s\n"
      (Yojson.Safe.to_string
         (`List
           (List.map
              ~f:(fun (peer, status) ->
                `List
                  [ Network_peer.Peer.to_yojson peer
                  ; Trust_system.Peer_status.to_yojson status
                  ] )
              statuses ) ) )
  else
    let ban_status status =
      match status.Trust_system.Peer_status.banned with
      | Unbanned ->
          "Unbanned"
      | Banned_until tm ->
          sprintf "Banned_until %s" (Time.to_string_abs tm ~zone:Time.Zone.utc)
    in
    List.fold ~init:()
      ~f:(fun () (peer, status) ->
        printf "%s, %0.04f, %s\n"
          (Network_peer.Peer.to_multiaddr_string peer)
          status.trust (ban_status status) )
      statuses

let round_trust_score trust_status =
  let open Trust_system.Peer_status in
  let trust = Float.round_decimal trust_status.trust ~decimal_digits:4 in
  { trust_status with trust }

let get_trust_status =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let address_flag =
    flag "--ip-address" ~aliases:[ "ip-address" ]
      ~doc:
        "IP An IPv4 or IPv6 address for which you want to query the trust \
         status"
      (required Cli_lib.Arg_type.ip_address)
  in
  let json_flag = Cli_lib.Flag.json in
  let flags = Args.zip2 address_flag json_flag in
  Command.async ~summary:"Get the trust status associated with an IP address"
    (Cli_lib.Background_daemon.rpc_init flags ~f:(fun port (ip_address, json) ->
         match%map
           Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_trust_status.rpc
             ip_address port
         with
         | Ok statuses ->
             print_trust_statuses
               (List.map
                  ~f:(fun (peer, status) -> (peer, round_trust_score status))
                  statuses )
               json
         | Error e ->
             printf "Failed to get trust status %s\n" (Error.to_string_hum e) )
    )

let ip_trust_statuses_to_yojson ip_trust_statuses =
  let items =
    List.map ip_trust_statuses ~f:(fun (ip_addr, status) ->
        `Assoc
          [ ("ip", `String (Unix.Inet_addr.to_string ip_addr))
          ; ("status", Trust_system.Peer_status.to_yojson status)
          ] )
  in
  `List items

let get_trust_status_all =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let nonzero_flag =
    flag "--nonzero-only" ~aliases:[ "nonzero-only" ] no_arg
      ~doc:"Only show trust statuses whose trust score is nonzero"
  in
  let json_flag = Cli_lib.Flag.json in
  let flags = Args.zip2 nonzero_flag json_flag in
  Command.async
    ~summary:"Get trust statuses for all peers known to the trust system"
    (Cli_lib.Background_daemon.rpc_init flags ~f:(fun port (nonzero, json) ->
         match%map
           Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_trust_status_all.rpc ()
             port
         with
         | Ok ip_trust_statuses ->
             (* always round the trust scores for display *)
             let ip_rounded_trust_statuses =
               List.map ip_trust_statuses ~f:(fun (ip_addr, status) ->
                   (ip_addr, round_trust_score status) )
             in
             let filtered_ip_trust_statuses =
               if nonzero then
                 List.filter ip_rounded_trust_statuses
                   ~f:(fun (_ip_addr, status) ->
                     not Float.(equal status.trust zero) )
               else ip_rounded_trust_statuses
             in
             print_trust_statuses filtered_ip_trust_statuses json
         | Error e ->
             printf "Failed to get trust statuses %s\n" (Error.to_string_hum e) )
    )

let reset_trust_status =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let address_flag =
    flag "--ip-address" ~aliases:[ "ip-address" ]
      ~doc:
        "IP An IPv4 or IPv6 address for which you want to reset the trust \
         status"
      (required Cli_lib.Arg_type.ip_address)
  in
  let json_flag = Cli_lib.Flag.json in
  let flags = Args.zip2 address_flag json_flag in
  Command.async ~summary:"Reset the trust status associated with an IP address"
    (Cli_lib.Background_daemon.rpc_init flags ~f:(fun port (ip_address, json) ->
         match%map
           Daemon_rpcs.Client.dispatch Daemon_rpcs.Reset_trust_status.rpc
             ip_address port
         with
         | Ok status ->
             print_trust_statuses status json
         | Error e ->
             printf "Failed to reset trust status %s\n" (Error.to_string_hum e) )
    )

let get_public_keys =
  let open Daemon_rpcs in
  let open Command.Param in
  let with_details_flag =
    flag "--with-details" ~aliases:[ "with-details" ] no_arg
      ~doc:"Show extra details (eg. balance, nonce) in addition to public keys"
  in
  let error_ctx = "Failed to get public-keys" in
  Command.async ~summary:"Get public keys"
    (Cli_lib.Background_daemon.rpc_init
       (Args.zip2 with_details_flag Cli_lib.Flag.json)
       ~f:(fun port (is_balance_included, json) ->
         if is_balance_included then
           Daemon_rpcs.Client.dispatch_pretty_message ~json
             ~join_error:Or_error.join ~error_ctx
             (module Cli_lib.Render.Public_key_with_details)
             Get_public_keys_with_details.rpc () port
         else
           Daemon_rpcs.Client.dispatch_pretty_message ~json
             ~join_error:Or_error.join ~error_ctx
             (module Cli_lib.Render.String_list_formatter)
             Get_public_keys.rpc () port ) )

let read_json filepath ~flag =
  let%map res =
    Deferred.Or_error.try_with ~here:[%here] (fun () ->
        let%map json_contents = Reader.file_contents filepath in
        Ok (Yojson.Safe.from_string json_contents) )
  in
  match res with
  | Ok c ->
      c
  | Error e ->
      Or_error.errorf "Could not read %s at %s\n%s" flag filepath
        (Error.to_string_hum e)

let verify_receipt =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let proof_path_flag =
    flag "--proof-path" ~aliases:[ "proof-path" ]
      ~doc:"PROOFFILE File to read json version of payment receipt"
      (required string)
  in
  let payment_path_flag =
    flag "--payment-path" ~aliases:[ "payment-path" ]
      ~doc:"PAYMENTPATH File to read json version of verifying payment"
      (required string)
  in
  let address_flag =
    flag "--address" ~aliases:[ "address" ]
      ~doc:"PUBLICKEY Public-key address of sender"
      (required public_key_compressed)
  in
  let token_flag =
    flag "--token" ~aliases:[ "token" ]
      ~doc:"TOKEN_ID The token ID for the account"
      (optional_with_default Token_id.default Cli_lib.Arg_type.token_id)
  in
  Command.async ~summary:"Verify a receipt of a sent payment"
    (Cli_lib.Background_daemon.rpc_init
       (Args.zip4 payment_path_flag proof_path_flag address_flag token_flag)
       ~f:(fun port (payment_path, proof_path, pk, token_id) ->
         let account_id = Account_id.create pk token_id in
         let dispatch_result =
           let open Deferred.Or_error.Let_syntax in
           let%bind payment_json =
             read_json payment_path ~flag:"payment-path"
           in
           let%bind proof_json = read_json proof_path ~flag:"proof-path" in
           let to_deferred_or_error result ~error =
             Result.map_error result ~f:(fun s ->
                 Error.of_string (sprintf "%s: %s" error s) )
             |> Deferred.return
           in
           let%bind payment =
             User_command.of_yojson payment_json
             |> to_deferred_or_error
                  ~error:
                    (sprintf "Payment file %s has invalid json format"
                       payment_path )
           and proof =
             [%of_yojson: Receipt.Chain_hash.t * User_command.t list] proof_json
             |> to_deferred_or_error
                  ~error:
                    (sprintf "Proof file %s has invalid json format" proof_path)
           in
           Daemon_rpcs.Client.dispatch Verify_proof.rpc
             (account_id, payment, proof)
             port
         in
         match%map dispatch_result with
         | Ok (Ok ()) ->
             printf "Payment is valid on the existing blockchain!\n"
         | Error e | Ok (Error e) ->
             eprintf "Error verifying the receipt: %s\n" (Error.to_string_hum e) )
    )

let get_nonce :
       rpc:(Account_id.t, Account.Nonce.t option Or_error.t) Rpc.Rpc.t
    -> Account_id.t
    -> Host_and_port.t
    -> (Account.Nonce.t, string) Deferred.Result.t =
 fun ~rpc account_id port ->
  let open Deferred.Let_syntax in
  let%map res = Daemon_rpcs.Client.dispatch rpc account_id port in
  match Or_error.join res with
  | Ok (Some n) ->
      Ok n
  | Ok None ->
      Error "No account found at that public_key"
  | Error e ->
      Error (Error.to_string_hum e)

let get_nonce_cmd =
  let open Command.Param in
  (* Ignores deprecation of public_key type for backwards compatibility *)
  let[@warning "-3"] address_flag =
    flag "--address" ~aliases:[ "address" ]
      ~doc:"PUBLICKEY Public-key address you want the nonce for"
      (required Cli_lib.Arg_type.public_key_compressed)
  in
  let token_flag =
    flag "--token" ~aliases:[ "token" ]
      ~doc:"TOKEN_ID The token ID for the account"
      (optional_with_default Token_id.default Cli_lib.Arg_type.token_id)
  in
  let flags = Args.zip2 address_flag token_flag in
  Command.async ~summary:"Get the current nonce for an account"
    (Cli_lib.Background_daemon.rpc_init flags ~f:(fun port (pk, token_flag) ->
         let account_id = Account_id.create pk token_flag in
         match%bind
           get_nonce ~rpc:Daemon_rpcs.Get_nonce.rpc account_id port
         with
         | Error e ->
             eprintf "Failed to get nonce\n%s\n" e ;
             exit 2
         | Ok nonce ->
             printf "%s\n" (Account.Nonce.to_string nonce) ;
             exit 0 ) )

let status =
  let open Daemon_rpcs in
  let flag = Args.zip2 Cli_lib.Flag.json Cli_lib.Flag.performance in
  Command.async ~summary:"Get running daemon status"
    (Cli_lib.Background_daemon.rpc_init flag ~f:(fun port (json, performance) ->
         Daemon_rpcs.Client.dispatch_pretty_message ~json ~join_error:Fn.id
           ~error_ctx:"Failed to get status"
           (module Daemon_rpcs.Types.Status)
           Get_status.rpc
           (if performance then `Performance else `None)
           port ) )

let status_clear_hist =
  let open Daemon_rpcs in
  let flag = Args.zip2 Cli_lib.Flag.json Cli_lib.Flag.performance in
  Command.async ~summary:"Clear histograms reported in status"
    (Cli_lib.Background_daemon.rpc_init flag ~f:(fun port (json, performance) ->
         Daemon_rpcs.Client.dispatch_pretty_message ~json ~join_error:Fn.id
           ~error_ctx:"Failed to clear histograms reported in status"
           (module Daemon_rpcs.Types.Status)
           Clear_hist_status.rpc
           (if performance then `Performance else `None)
           port ) )

let get_nonce_exn ~rpc public_key port =
  match%bind get_nonce ~rpc public_key port with
  | Error e ->
      eprintf "Failed to get nonce\n%s\n" e ;
      exit 3
  | Ok nonce ->
      return nonce

let unwrap_user_command (`UserCommand x) = x

let batch_send_payments =
  let module Payment_info = struct
    type t =
      { receiver : string
      ; amount : Currency.Amount.t
      ; fee : Currency.Fee.t
      ; valid_until : Mina_numbers.Global_slot_since_genesis.t option
            [@sexp.option]
      }
    [@@deriving sexp]
  end in
  let payment_path_flag = Command.Param.(anon @@ ("payments-file" %: string)) in
  let get_infos payments_path =
    match%bind
      Reader.load_sexp payments_path [%of_sexp: Payment_info.t list]
    with
    | Ok x ->
        return x
    | Error _ ->
        let sample_info () : Payment_info.t =
          let keypair = Keypair.create () in
          { Payment_info.receiver =
              Public_key.(
                Compressed.to_base58_check (compress keypair.public_key))
          ; valid_until =
              Some (Mina_numbers.Global_slot_since_genesis.random ())
          ; amount = Currency.Amount.of_nanomina_int_exn (Random.int 100)
          ; fee = Currency.Fee.of_nanomina_int_exn (Random.int 100)
          }
        in
        eprintf "Could not read payments from %s.\n" payments_path ;
        eprintf
          "The file should be a sexp list of payments with optional expiry \
           slot number \"valid_until\". Here is an example file:\n\
           %s\n"
          (Sexp.to_string_hum
             ([%sexp_of: Payment_info.t list]
                (List.init 3 ~f:(fun _ -> sample_info ())) ) ) ;
        exit 5
  in
  let main port (privkey_path, payments_path) =
    let open Deferred.Let_syntax in
    let%bind keypair =
      Secrets.Keypair.Terminal_stdin.read_exn ~which:"Mina keypair" privkey_path
    and infos = get_infos payments_path in
    let ts : User_command_input.t list =
      List.map infos ~f:(fun { receiver; valid_until; amount; fee } ->
          let signer_pk = Public_key.compress keypair.public_key in
          let receiver_pk =
            Public_key.of_base58_check_decompress_exn receiver
          in
          User_command_input.create ~signer:signer_pk ~fee
            ~fee_payer_pk:signer_pk ~memo:Signed_command_memo.empty ~valid_until
            ~body:(Payment { receiver_pk; amount })
            ~sign_choice:(User_command_input.Sign_choice.Keypair keypair) () )
    in
    Daemon_rpcs.Client.dispatch_with_message Daemon_rpcs.Send_user_commands.rpc
      ts port
      ~success:(fun _ -> "Successfully enqueued payments in pool")
      ~error:(fun e ->
        sprintf "Failed to send payments %s" (Error.to_string_hum e) )
      ~join_error:Or_error.join
  in
  Command.async ~summary:"Send multiple payments from a file"
    (Cli_lib.Background_daemon.rpc_init
       (Args.zip2 Cli_lib.Flag.privkey_read_path payment_path_flag)
       ~f:main )

let transaction_id_to_string id =
  Yojson.Basic.to_string (Graphql_lib.Scalars.TransactionId.serialize id)

let send_payment_graphql =
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let receiver_flag =
    flag "--receiver" ~aliases:[ "receiver" ]
      ~doc:"PUBLICKEY Public key to which you want to send money"
      (required public_key_compressed)
  in
  let amount_flag =
    flag "--amount" ~aliases:[ "amount" ]
      ~doc:"VALUE Payment amount you want to send" (required txn_amount)
  in
  let args =
    Args.zip3 Cli_lib.Flag.signed_command_common receiver_flag amount_flag
  in
  Command.async ~summary:"Send payment to an address"
    (Cli_lib.Background_daemon.graphql_init args
       ~f:(fun
            graphql_endpoint
            ({ Cli_lib.Flag.sender; fee; nonce; memo }, receiver, amount)
          ->
         let%map response =
           let input =
             Mina_graphql.Types.Input.SendPaymentInput.make_input ~to_:receiver
               ~from:sender ~amount ~fee ?memo ?nonce ()
           in
           Graphql_client.query_exn
             Graphql_queries.Send_payment.(make @@ makeVariables ~input ())
             graphql_endpoint
         in
         printf "Dispatched payment with ID %s\n"
           (transaction_id_to_string response.sendPayment.payment.id) ) )

let delegate_stake_graphql =
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let receiver_flag =
    flag "--receiver" ~aliases:[ "receiver" ]
      ~doc:"PUBLICKEY Public key to which you want to delegate your stake"
      (required public_key_compressed)
  in
  let args = Args.zip2 Cli_lib.Flag.signed_command_common receiver_flag in
  Command.async ~summary:"Delegate your stake to another public key"
    (Cli_lib.Background_daemon.graphql_init args
       ~f:(fun
            graphql_endpoint
            ({ Cli_lib.Flag.sender; fee; nonce; memo }, receiver)
          ->
         let%map response =
           Graphql_client.query_exn
             Graphql_queries.Send_delegation.(
               make
               @@ makeVariables ~receiver ~sender
                    ~fee:(Currency.Fee.to_uint64 fee)
                    ?nonce ?memo ())
             graphql_endpoint
         in
         printf "Dispatched stake delegation with ID %s\n"
           (transaction_id_to_string response.sendDelegation.delegation.id) ) )

let cancel_transaction_graphql =
  let txn_id_flag =
    Command.Param.(
      flag "--id" ~aliases:[ "id" ] ~doc:"ID Transaction ID to be cancelled"
        (required Cli_lib.Arg_type.user_command))
  in
  Command.async
    ~summary:
      "Cancel a transaction -- this submits a replacement transaction with a \
       fee larger than the cancelled transaction."
    (Cli_lib.Background_daemon.graphql_init txn_id_flag
       ~f:(fun graphql_endpoint user_command ->
         let receiver_pk = Signed_command.receiver_pk user_command in
         let cancel_sender_pk = Signed_command.fee_payer_pk user_command in
         let open Deferred.Let_syntax in
         let cancel_fee =
           let fee = Currency.Fee.to_uint64 (Signed_command.fee user_command) in
           let replace_fee =
             Currency.Fee.to_uint64 Network_pool.Indexed_pool.replace_fee
           in
           let open Unsigned.UInt64.Infix in
           (* fee amount "inspired by" network_pool/indexed_pool.ml *)
           Currency.Fee.of_uint64 (fee + replace_fee)
         in
         printf "Fee to cancel transaction is %s coda.\n"
           (Currency.Fee.to_mina_string cancel_fee) ;
         let cancel_query =
           let input =
             Mina_graphql.Types.Input.SendPaymentInput.make_input
               ~to_:receiver_pk ~from:cancel_sender_pk
               ~amount:Currency.Amount.zero ~fee:cancel_fee
               ~nonce:(Signed_command.nonce user_command)
               ()
           in
           Graphql_queries.Send_payment.(make @@ makeVariables ~input ())
         in
         let%map cancel_response =
           Graphql_client.query_exn cancel_query graphql_endpoint
         in
         printf "🛑 Cancelled transaction! Cancel ID: %s\n"
           (transaction_id_to_string cancel_response.sendPayment.payment.id) )
    )

let send_rosetta_transactions_graphql =
  Command.async
    ~summary:
      "Dispatch one or more transactions, provided to stdin in rosetta format"
    (Cli_lib.Background_daemon.graphql_init (Command.Param.return ())
       ~f:(fun graphql_endpoint () ->
         let lexbuf = Lexing.from_channel In_channel.stdin in
         let lexer = Yojson.init_lexer () in
         match%bind
           Deferred.Or_error.try_with ~here:[%here] (fun () ->
               Deferred.repeat_until_finished () (fun () ->
                   try
                     let transaction_json =
                       Yojson.Basic.from_lexbuf ~stream:true lexer lexbuf
                     in
                     let%map response =
                       Graphql_client.query_exn
                         Graphql_queries.Send_rosetta_transaction.(
                           make
                           @@ makeVariables ~transaction:transaction_json ())
                         graphql_endpoint
                     in
                     printf "Dispatched command with TRANSACTION_ID %s\n"
                       (transaction_id_to_string
                          response.sendRosettaTransaction.userCommand.id ) ;
                     `Repeat ()
                   with Yojson.End_of_input -> return (`Finished ()) ) )
         with
         | Ok () ->
             Deferred.return ()
         | Error err ->
             Format.eprintf "@[<v>Error:@,%a@,@]@."
               (Yojson.Safe.pretty_print ?std:None)
               (Error_json.error_to_yojson err) ;
             Core_kernel.exit 1 ) )

module Export_logs = struct
  let pp_export_result tarfile = printf "Exported logs to %s\n%!" tarfile

  let tarfile_flag =
    let open Command.Param in
    flag "--tarfile" ~aliases:[ "tarfile" ]
      ~doc:"STRING Basename of the tar archive (default: date_time)"
      (optional string)

  let export_via_graphql =
    Command.async ~summary:"Export daemon logs to tar archive"
      (Cli_lib.Background_daemon.graphql_init tarfile_flag
         ~f:(fun graphql_endpoint basename ->
           let%map response =
             Graphql_client.query_exn
               Graphql_queries.Export_logs.(make @@ makeVariables ?basename ())
               graphql_endpoint
           in
           pp_export_result response.exportLogs.exportLogs.tarfile ) )

  let export_locally =
    let run ~tarfile ~conf_dir =
      let open Mina_lib in
      let conf_dir = Conf_dir.compute_conf_dir conf_dir in
      fun () ->
        match%map Conf_dir.export_logs_to_tar ?basename:tarfile ~conf_dir with
        | Ok result ->
            pp_export_result result
        | Error err ->
            failwithf "Error when exporting logs: %s"
              (Error_json.error_to_yojson err |> Yojson.Safe.to_string)
              ()
    in
    let open Command.Let_syntax in
    Command.async ~summary:"Export local logs (no daemon) to tar archive"
      (let%map tarfile = tarfile_flag and conf_dir = Cli_lib.Flag.conf_dir in
       run ~tarfile ~conf_dir )
end

let wrap_key =
  Command.async ~summary:"Wrap a private key into a private key file"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_write_path in
    Cli_lib.Exceptions.handle_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let%bind privkey =
      Secrets.Password.hidden_line_or_env "Private key: " ~env:"CODA_PRIVKEY"
    in
    let pk = Private_key.of_base58_check_exn (Bytes.to_string privkey) in
    let kp = Keypair.of_private_key_exn pk in
    Secrets.Keypair.Terminal_stdin.write_exn kp ~privkey_path)

let dump_keypair =
  Command.async ~summary:"Print out a keypair from a private key file"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_read_path in
    Cli_lib.Exceptions.handle_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let%map kp =
      Secrets.Keypair.Terminal_stdin.read_exn ~which:"Mina keypair" privkey_path
    in
    printf "Public key: %s\nPrivate key: %s\n"
      ( kp.public_key |> Public_key.compress
      |> Public_key.Compressed.to_base58_check )
      (kp.private_key |> Private_key.to_base58_check))

let handle_export_ledger_response ~json = function
  | Error e ->
      Daemon_rpcs.Client.print_rpc_error e ;
      exit 1
  | Ok (Error e) ->
      printf !"Ledger not found: %s\n" (Error.to_string_hum e) ;
      exit 1
  | Ok (Ok accounts) ->
      if json then (
        Yojson.Safe.pretty_print Format.std_formatter
          (Runtime_config.Accounts.to_yojson
             (List.map accounts ~f:(fun a ->
                  Genesis_ledger_helper.Accounts.Single.of_account a None ) ) ) ;
        printf "\n" )
      else printf !"%{sexp:Account.t list}\n" accounts ;
      return ()

let export_ledger =
  let state_hash_flag =
    Command.Param.(
      flag "--state-hash" ~aliases:[ "state-hash" ]
        ~doc:
          "STATE-HASH State hash, if printing a staged ledger (default: state \
           hash for the best tip)"
        (optional string))
  in
  let ledger_kind =
    let available_ledgers =
      [ "staged-ledger"
      ; "snarked-ledger"
      ; "staking-epoch-ledger"
      ; "next-epoch-ledger"
      ]
    in
    let t =
      Command.Param.Arg_type.of_alist_exn
        (List.map available_ledgers ~f:(fun s -> (s, s)))
    in
    let ledger_args = String.concat ~sep:"|" available_ledgers in
    Command.Param.(anon (ledger_args %: t))
  in
  let plaintext_flag = Cli_lib.Flag.plaintext in
  let flags = Args.zip3 state_hash_flag plaintext_flag ledger_kind in
  Command.async
    ~summary:
      "Print the specified ledger (default: staged ledger at the best tip). \
       Note: Exporting snarked ledger is an expensive operation and can take a \
       few seconds"
    (Cli_lib.Background_daemon.rpc_init flags
       ~f:(fun port (state_hash, plaintext, ledger_kind) ->
         let check_for_state_hash () =
           if Option.is_some state_hash then (
             Format.eprintf "A state hash should not be given for %s@."
               ledger_kind ;
             Core_kernel.exit 1 )
         in
         let response =
           match ledger_kind with
           | "staged-ledger" ->
               let state_hash =
                 Option.map ~f:State_hash.of_base58_check_exn state_hash
               in
               Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_ledger.rpc state_hash
                 port
           | "snarked-ledger" ->
               let state_hash =
                 Option.map ~f:State_hash.of_base58_check_exn state_hash
               in
               printf
                 "Generating snarked ledger(this may take a few seconds)...\n" ;
               Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_snarked_ledger.rpc
                 state_hash port
           | "staking-epoch-ledger" ->
               check_for_state_hash () ;
               Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_staking_ledger.rpc
                 Daemon_rpcs.Get_staking_ledger.Current port
           | "next-epoch-ledger" ->
               check_for_state_hash () ;
               Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_staking_ledger.rpc
                 Daemon_rpcs.Get_staking_ledger.Next port
           | _ ->
               (* unreachable *)
               failwithf "Unknown ledger kind: %s" ledger_kind ()
         in
         response >>= handle_export_ledger_response ~json:(not plaintext) ) )

let hash_ledger =
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Print the Merkle root of the ledger contained in the specified file"
    (let%map ledger_file =
       Command.Param.(
         flag "--ledger-file"
           ~doc:"LEDGER-FILE File containing an exported ledger"
           (required string))
     and plaintext = Cli_lib.Flag.plaintext in
     fun () ->
       let process_accounts accounts =
         let constraint_constants =
           Genesis_constants.Constraint_constants.compiled
         in
         let packed_ledger =
           Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
             ~depth:constraint_constants.ledger_depth accounts
         in
         let ledger = Lazy.force @@ Genesis_ledger.Packed.t packed_ledger in
         Format.printf "%s@."
           (Mina_ledger.Ledger.merkle_root ledger |> Ledger_hash.to_base58_check)
       in
       Deferred.return
       @@
       if plaintext then
         In_channel.with_file ledger_file ~f:(fun in_channel ->
             let sexp = In_channel.input_all in_channel |> Sexp.of_string in
             let accounts =
               lazy
                 (List.map
                    ([%of_sexp: Account.t list] sexp)
                    ~f:(fun acct -> (None, acct)) )
             in
             process_accounts accounts )
       else
         let json = Yojson.Safe.from_file ledger_file in
         match Runtime_config.Accounts.of_yojson json with
         | Ok runtime_accounts ->
             let accounts =
               lazy (Genesis_ledger_helper.Accounts.to_full runtime_accounts)
             in
             process_accounts accounts
         | Error err ->
             Format.eprintf "Could not parse JSON in file %s: %s@" ledger_file
               err ;
             ignore (exit 1 : 'a Deferred.t) )

let currency_in_ledger =
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Print the total currency for each token present in the ledger contained \
       in the specified file"
    (let%map ledger_file =
       Command.Param.(
         flag "--ledger-file"
           ~doc:"LEDGER-FILE File containing an exported ledger"
           (required string))
     and plaintext = Cli_lib.Flag.plaintext in
     fun () ->
       let process_accounts accounts =
         (* track currency total for each token
            use uint64 to make arithmetic simple
         *)
         let currency_tbl : Unsigned.UInt64.t Token_id.Table.t =
           Token_id.Table.create ()
         in
         List.iter accounts ~f:(fun (acct : Account.t) ->
             let token_id = Account.token acct in
             let balance = acct.balance |> Currency.Balance.to_uint64 in
             match Token_id.Table.find currency_tbl token_id with
             | None ->
                 Token_id.Table.add_exn currency_tbl ~key:token_id ~data:balance
             | Some total ->
                 let new_total = Unsigned.UInt64.add total balance in
                 Token_id.Table.set currency_tbl ~key:token_id ~data:new_total ) ;
         let tokens =
           Token_id.Table.keys currency_tbl
           |> List.dedup_and_sort ~compare:Token_id.compare
         in
         List.iter tokens ~f:(fun token ->
             let total =
               Token_id.Table.find_exn currency_tbl token
               |> Currency.Balance.of_uint64 |> Currency.Balance.to_mina_string
             in
             if Token_id.equal token Token_id.default then
               Format.printf "MINA: %s@." total
             else
               Format.printf "TOKEN %s: %s@." (Token_id.to_string token) total )
       in
       Deferred.return
       @@
       if plaintext then
         In_channel.with_file ledger_file ~f:(fun in_channel ->
             let sexp = In_channel.input_all in_channel |> Sexp.of_string in
             let accounts = [%of_sexp: Account.t list] sexp in
             process_accounts accounts )
       else
         let json = Yojson.Safe.from_file ledger_file in
         match Runtime_config.Accounts.of_yojson json with
         | Ok runtime_accounts ->
             let accounts =
               Genesis_ledger_helper.Accounts.to_full runtime_accounts
               |> List.map ~f:(fun (_sk_opt, acct) -> acct)
             in
             process_accounts accounts
         | Error err ->
             Format.eprintf "Could not parse JSON in file %s: %s@" ledger_file
               err ;
             ignore (exit 1 : 'a Deferred.t) )

let constraint_system_digests =
  Command.async ~summary:"Print MD5 digest of each SNARK constraint"
    (Command.Param.return (fun () ->
         (* TODO: Allow these to be configurable. *)
         let proof_level = Genesis_constants.Proof_level.compiled in
         let constraint_constants =
           Genesis_constants.Constraint_constants.compiled
         in
         let all =
           Transaction_snark.constraint_system_digests ~constraint_constants ()
           @ Blockchain_snark.Blockchain_snark_state.constraint_system_digests
               ~proof_level ~constraint_constants ()
         in
         let all =
           List.sort ~compare:(fun (k1, _) (k2, _) -> String.compare k1 k2) all
         in
         List.iter all ~f:(fun (k, v) -> printf "%s\t%s\n" k (Md5.to_hex v)) ;
         Deferred.unit ) )

let snark_job_list =
  let open Deferred.Let_syntax in
  let open Command.Param in
  Command.async
    ~summary:
      "List of snark jobs in JSON format that are yet to be included in the \
       blocks"
    (Cli_lib.Background_daemon.rpc_init (return ()) ~f:(fun port () ->
         match%map
           Daemon_rpcs.Client.dispatch_join_errors
             Daemon_rpcs.Snark_job_list.rpc () port
         with
         | Ok str ->
             printf "%s" str
         | Error e ->
             Daemon_rpcs.Client.print_rpc_error e ) )

let snark_pool_list =
  let open Command.Param in
  Command.async ~summary:"List of snark works in the snark pool in JSON format"
    (Cli_lib.Background_daemon.graphql_init (return ())
       ~f:(fun graphql_endpoint () ->
         Deferred.map
           (Graphql_client.query_exn
              Graphql_queries.Snark_pool.(make @@ makeVariables ())
              graphql_endpoint )
           ~f:(fun response ->
             let lst =
               [%to_yojson: Cli_lib.Graphql_types.Completed_works.t]
                 (Array.to_list
                    (Array.map
                       ~f:(fun w ->
                         { Cli_lib.Graphql_types.Completed_works.Work.work_ids =
                             Array.to_list w.work_ids
                         ; fee = w.fee
                         ; prover = w.prover
                         } )
                       response.snarkPool ) )
             in
             print_string (Yojson.Safe.to_string lst) ) ) )

let pooled_user_commands =
  let public_key_flag =
    Command.Param.(
      anon @@ maybe @@ ("public-key" %: Cli_lib.Arg_type.public_key_compressed))
  in
  Command.async
    ~summary:"Retrieve all the user commands that are pending inclusion"
    (Cli_lib.Background_daemon.graphql_init public_key_flag
       ~f:(fun graphql_endpoint public_key ->
         let module Q = Graphql_queries.Pooled_user_commands in
         let graphql = Q.(make @@ makeVariables ?public_key ()) in
         let%map response = Graphql_client.query_exn graphql graphql_endpoint in
         let json_response = Q.serialize response |> Q.toJson in
         print_string (Yojson.Basic.to_string json_response) ) )

let pooled_zkapp_commands =
  let public_key_flag =
    Command.Param.(
      anon @@ maybe @@ ("public-key" %: Cli_lib.Arg_type.public_key_compressed))
  in
  Command.async
    ~summary:"Retrieve all the zkApp commands that are pending inclusion"
    (Cli_lib.Background_daemon.graphql_init public_key_flag
       ~f:(fun graphql_endpoint maybe_public_key ->
         let public_key =
           Yojson.Safe.to_basic
           @@ [%to_yojson: Public_key.Compressed.t option] maybe_public_key
         in
         let graphql =
           Graphql_queries.Pooled_zkapp_commands.(
             make @@ makeVariables ~public_key ())
         in
         let%bind raw_response =
           Graphql_client.query_json_exn graphql graphql_endpoint
         in
         let%map json_response =
           try
             let kvs = Yojson.Safe.Util.to_assoc raw_response in
             List.hd_exn kvs |> snd |> return
           with _ ->
             eprintf "Failed to read result of pooled zkApp commands" ;
             exit 1
         in
         print_string (Yojson.Safe.to_string json_response) ) )

let to_signed_fee_exn sign magnitude =
  let sgn = match sign with `PLUS -> Sgn.Pos | `MINUS -> Neg in
  Currency.Fee.Signed.create ~sgn ~magnitude

let pending_snark_work =
  let open Command.Param in
  Command.async
    ~summary:
      "List of snark works in JSON format that are not available in the pool \
       yet"
    (Cli_lib.Background_daemon.graphql_init (return ())
       ~f:(fun graphql_endpoint () ->
         Deferred.map
           (Graphql_client.query_exn
              Graphql_queries.Pending_snark_work.(make @@ makeVariables ())
              graphql_endpoint )
           ~f:(fun response ->
             let lst =
               [%to_yojson: Cli_lib.Graphql_types.Pending_snark_work.t]
                 (Array.map
                    ~f:(fun bundle ->
                      Array.map bundle.workBundle ~f:(fun w ->
                          let f = w.fee_excess in
                          { Cli_lib.Graphql_types.Pending_snark_work.Work
                            .work_id = w.work_id
                          ; fee_excess =
                              Currency.Amount.Signed.of_fee
                                (to_signed_fee_exn f.sign
                                   (Currency.Amount.to_fee f.fee_magnitude) )
                          ; supply_increase = w.supply_change.fee_magnitude
                          ; source_first_pass_ledger_hash =
                              w.source_first_pass_ledger_hash
                          ; target_first_pass_ledger_hash =
                              w.target_first_pass_ledger_hash
                          ; source_second_pass_ledger_hash =
                              w.source_second_pass_ledger_hash
                          ; target_second_pass_ledger_hash =
                              w.target_second_pass_ledger_hash
                          } ) )
                    response.pendingSnarkWork )
             in
             print_string (Yojson.Safe.to_string lst) ) ) )

let start_tracing =
  let open Deferred.Let_syntax in
  let open Command.Param in
  Command.async
    ~summary:"Start async tracing to $config-directory/trace/$pid.trace"
    (Cli_lib.Background_daemon.rpc_init (return ()) ~f:(fun port () ->
         match%map
           Daemon_rpcs.Client.dispatch Daemon_rpcs.Start_tracing.rpc () port
         with
         | Ok () ->
             print_endline "Daemon started tracing!"
         | Error e ->
             Daemon_rpcs.Client.print_rpc_error e ) )

let stop_tracing =
  let open Deferred.Let_syntax in
  let open Command.Param in
  Command.async ~summary:"Stop async tracing"
    (Cli_lib.Background_daemon.rpc_init (return ()) ~f:(fun port () ->
         match%map
           Daemon_rpcs.Client.dispatch Daemon_rpcs.Stop_tracing.rpc () port
         with
         | Ok () ->
             print_endline "Daemon stopped printing!"
         | Error e ->
             Daemon_rpcs.Client.print_rpc_error e ) )

let start_internal_tracing =
  let open Deferred.Let_syntax in
  let open Command.Param in
  Command.async
    ~summary:
      "Start internal tracing to \
       $config-directory/internal-tracing/internal-trace.jsonl"
    (Cli_lib.Background_daemon.rpc_init (return ()) ~f:(fun port () ->
         match%map
           Daemon_rpcs.Client.dispatch Daemon_rpcs.Start_internal_tracing.rpc ()
             port
         with
         | Ok () ->
             print_endline "Daemon internal started tracing!"
         | Error e ->
             Daemon_rpcs.Client.print_rpc_error e ) )

let stop_internal_tracing =
  let open Deferred.Let_syntax in
  let open Command.Param in
  Command.async ~summary:"Stop internal tracing"
    (Cli_lib.Background_daemon.rpc_init (return ()) ~f:(fun port () ->
         match%map
           Daemon_rpcs.Client.dispatch Daemon_rpcs.Stop_internal_tracing.rpc ()
             port
         with
         | Ok () ->
             print_endline "Daemon internal tracing stopped!"
         | Error e ->
             Daemon_rpcs.Client.print_rpc_error e ) )

let set_coinbase_receiver_graphql =
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let pk_flag =
    choose_one ~if_nothing_chosen:Raise
      [ flag "--public-key" ~aliases:[ "public-key" ]
          ~doc:"PUBLICKEY Public key of account to send coinbase rewards to"
          (optional public_key_compressed)
        |> map ~f:(Option.map ~f:Option.some)
      ; flag "--block-producer" ~aliases:[ "block-producer" ]
          ~doc:"Send coinbase rewards to the block producer's public key" no_arg
        |> map ~f:(function true -> Some None | false -> None)
      ]
  in
  Command.async ~summary:"Set the coinbase receiver"
    (Cli_lib.Background_daemon.graphql_init pk_flag
       ~f:(fun graphql_endpoint public_key ->
         let print_pk_opt () = function
           | None ->
               "block producer"
           | Some pk ->
               "public key " ^ Public_key.Compressed.to_base58_check pk
         in
         let%map result =
           Graphql_client.query_exn
             Graphql_queries.Set_coinbase_receiver.(
               make @@ makeVariables ?public_key ())
             graphql_endpoint
         in
         printf
           "Was sending coinbases to the %a\nNow sending coinbases to the %a\n"
           print_pk_opt result.setCoinbaseReceiver.lastCoinbaseReceiver
           print_pk_opt result.setCoinbaseReceiver.currentCoinbaseReceiver ) )

let set_snark_worker =
  let open Command.Param in
  let public_key_flag =
    flag "--address" ~aliases:[ "address" ]
      ~doc:
        (sprintf
           "PUBLICKEY Public-key address you wish to start snark-working on; \
            null to stop doing any snark work. %s"
           Cli_lib.Default.receiver_key_warning )
      (optional Cli_lib.Arg_type.public_key_compressed)
  in
  Command.async
    ~summary:"Set key you wish to snark work with or disable snark working"
    (Cli_lib.Background_daemon.graphql_init public_key_flag
       ~f:(fun graphql_endpoint optional_public_key ->
         let graphql =
           Graphql_queries.Set_snark_worker.(
             make @@ makeVariables ?public_key:optional_public_key ())
         in
         Deferred.map (Graphql_client.query_exn graphql graphql_endpoint)
           ~f:(fun response ->
             ( match optional_public_key with
             | Some public_key ->
                 printf
                   !"New snark worker public key : %s\n"
                   (Public_key.Compressed.to_base58_check public_key)
             | None ->
                 printf "Will stop doing snark work\n" ) ;
             printf "Previous snark worker public key : %s\n"
               (Option.value_map response.setSnarkWorker.lastSnarkWorker
                  ~default:"None" ~f:Public_key.Compressed.to_base58_check ) ) )
    )

let set_snark_work_fee =
  Command.async ~summary:"Set fee reward for doing transaction snark work"
  @@ Cli_lib.Background_daemon.graphql_init
       Command.Param.(anon @@ ("fee" %: Cli_lib.Arg_type.txn_fee))
       ~f:(fun graphql_endpoint fee ->
         let graphql =
           Graphql_queries.Set_snark_work_fee.(
             make @@ makeVariables ~fee:(Currency.Fee.to_uint64 fee) ())
         in
         Deferred.map (Graphql_client.query_exn graphql graphql_endpoint)
           ~f:(fun response ->
             printf
               !"Updated snark work fee: %i\nOld snark work fee: %i\n"
               (Currency.Fee.to_nanomina_int fee)
               (Currency.Fee.to_nanomina_int response.setSnarkWorkFee.lastFee) )
         )

let import_key =
  Command.async
    ~summary:
      "Import a password protected private key to be tracked by the daemon.\n\
       Set MINA_PRIVKEY_PASS environment variable to use non-interactively \
       (key will be imported using the same password)."
    (let%map_open.Command access_method =
       choose_one
         ~if_nothing_chosen:(Default_to `None)
         [ Cli_lib.Flag.Uri.Client.rest_graphql_opt
           |> map ~f:(Option.map ~f:(fun port -> `GraphQL port))
         ; Cli_lib.Flag.conf_dir
           |> map ~f:(Option.map ~f:(fun conf_dir -> `Conf_dir conf_dir))
         ]
     and privkey_path = Cli_lib.Flag.privkey_read_path in
     fun () ->
       let open Deferred.Let_syntax in
       let initial_password = ref None in
       let do_graphql graphql_endpoint =
         let%bind password =
           match Sys.getenv Secrets.Keypair.env with
           | Some password ->
               Deferred.return (Bytes.of_string password)
           | None ->
               let password =
                 Secrets.Password.read_hidden_line ~error_help_message:""
                   "Secret key password: "
               in
               initial_password := Some password ;
               password
         in
         let graphql =
           Graphql_queries.Import_account.(
             make
             @@ makeVariables ~path:privkey_path
                  ~password:(Bytes.to_string password) ())
         in
         match%map Graphql_client.query graphql graphql_endpoint with
         | Ok res ->
             let res = res.importAccount in
             if res.already_imported then Ok (`Already_imported res.public_key)
             else Ok (`Imported res.public_key)
         | Error (`Failed_request _ as err) ->
             Error err
         | Error (`Graphql_error _ as err) ->
             Ok err
       in
       let do_local conf_dir =
         let wallets_disk_location = conf_dir ^/ "wallets" in
         let%bind ({ Keypair.public_key; _ } as keypair) =
           let rec go () =
             match !initial_password with
             | None ->
                 Secrets.Keypair.Terminal_stdin.read_exn ~which:"mina keypair"
                   privkey_path
             | Some password -> (
                 (* We've already asked for the password once for a failed
                    GraphQL query, try that one instead of asking again.
                 *)
                 match%bind
                   Secrets.Keypair.read ~privkey_path
                     ~password:(Lazy.return password)
                 with
                 | Ok res ->
                     return res
                 | Error `Incorrect_password_or_corrupted_privkey ->
                     printf "Wrong password! Please try again\n" ;
                     initial_password := None ;
                     go ()
                 | Error err ->
                     Secrets.Privkey_error.raise ~which:"mina keypair" err )
           in
           go ()
         in
         let pk = Public_key.compress public_key in
         let%bind wallets =
           Secrets.Wallets.load ~logger:(Logger.create ())
             ~disk_location:wallets_disk_location
         in
         (* Either we already are tracking it *)
         match Secrets.Wallets.check_locked wallets ~needle:pk with
         | Some _ ->
             Deferred.return (`Already_imported pk)
         | None ->
             (* Or we import it *)
             let%map pk =
               Secrets.Wallets.import_keypair_terminal_stdin wallets keypair
             in
             `Imported pk
       in
       let print_result = function
         | `Already_imported public_key ->
             printf
               !"Key already present, no need to import : %s\n"
               (Public_key.Compressed.to_base58_check public_key)
         | `Imported public_key ->
             printf
               !"\n😄 Imported account!\nPublic key: %s\n"
               (Public_key.Compressed.to_base58_check public_key)
         | `Graphql_error _ as e ->
             don't_wait_for (Graphql_lib.Client.Connection_error.ok_exn e)
       in
       match access_method with
       | `GraphQL graphql_endpoint -> (
           match%map do_graphql graphql_endpoint with
           | Ok res ->
               print_result res
           | Error err ->
               don't_wait_for (Graphql_lib.Client.Connection_error.ok_exn err) )
       | `Conf_dir conf_dir ->
           let%map res = do_local conf_dir in
           print_result res
       | `None -> (
           let default_graphql_endpoint =
             Cli_lib.Flag.(Uri.Client.{ Types.name; value = default })
           in
           match%bind do_graphql default_graphql_endpoint with
           | Ok res ->
               Deferred.return (print_result res)
           | Error _res ->
               let conf_dir = Mina_lib.Conf_dir.compute_conf_dir None in
               eprintf
                 "%sWarning: Could not connect to a running daemon.\n\
                  Importing to local directory %s%s\n"
                 Bash_colors.orange conf_dir Bash_colors.none ;
               let%map res = do_local conf_dir in
               print_result res ) )

let export_key =
  let privkey_path = Cli_lib.Flag.privkey_write_path in
  let pk_flag =
    let open Command.Param in
    flag "--public-key" ~aliases:[ "public-key" ]
      ~doc:"PUBLICKEY Public key of account to be exported"
      (required Cli_lib.Arg_type.public_key_compressed)
  in
  let conf_dir = Cli_lib.Flag.conf_dir in
  let flags = Args.zip3 privkey_path pk_flag conf_dir in
  Command.async
    ~summary:
      "Export a tracked account so that it can be saved or transferred between \
       machines.\n\
      \ Set MINA_PRIVKEY_PASS environment variable to use non-interactively \
       (key will be exported using the same password)."
    (Cli_lib.Background_daemon.graphql_init flags
       ~f:(fun _ (export_path, pk, conf_dir) ->
         let open Deferred.Let_syntax in
         let%bind home = Sys.home_directory () in
         let conf_dir =
           Option.value
             ~default:(home ^/ Cli_lib.Default.conf_dir_name)
             conf_dir
         in
         let wallets_disk_location = conf_dir ^/ "wallets" in
         let%bind wallets =
           Secrets.Wallets.load ~logger:(Logger.create ())
             ~disk_location:wallets_disk_location
         in
         let password =
           lazy
             (Secrets.Password.hidden_line_or_env
                "Password for exported account: " ~env:Secrets.Keypair.env )
         in
         let%bind account =
           let open Deferred.Result.Let_syntax in
           let%bind _ = Secrets.Wallets.unlock wallets ~needle:pk ~password in
           Secrets.Wallets.find_identity wallets ~needle:pk
           |> Result.of_option ~error:`Not_found
           |> Deferred.return
         in
         let kp =
           match account with
           | Ok (`Keypair kp) ->
               Ok kp
           | Ok (`Hd_index i) ->
               Error
                 (sprintf
                    !"account is an HD account (hardware wallet), the \
                      associated index is %{Unsigned.UInt32}"
                    i )
           | Error `Bad_password ->
               Error
                 (sprintf
                    !"wrong password provided for account \
                      %{Public_key.Compressed.to_base58_check}"
                    pk )
           | Error (`Key_read_error e) ->
               Error
                 (sprintf
                    !"Error reading the secret key file for account \
                      %{Public_key.Compressed.to_base58_check}: %s"
                    pk
                    (Secrets.Privkey_error.to_string e) )
           | Error `Not_found ->
               Error
                 (sprintf
                    !"account not found corresponding to account \
                      %{Public_key.Compressed.to_base58_check}"
                    pk )
         in
         match kp with
         | Ok kp ->
             let%bind () =
               Secrets.Keypair.Terminal_stdin.write_exn kp
                 ~privkey_path:export_path
             in
             printf
               !"😄 Account exported to %s: %s\n"
               export_path
               (Public_key.Compressed.to_base58_check pk) ;
             Deferred.unit
         | Error e ->
             printf "❌ Export failed -- %s\n" e ;
             Deferred.unit ) )

let list_accounts =
  Command.async ~summary:"List all owned accounts"
    (let%map_open.Command access_method =
       choose_one
         ~if_nothing_chosen:(Default_to `None)
         [ Cli_lib.Flag.Uri.Client.rest_graphql_opt
           |> map ~f:(Option.map ~f:(fun port -> `GraphQL port))
         ; Cli_lib.Flag.conf_dir
           |> map ~f:(Option.map ~f:(fun conf_dir -> `Conf_dir conf_dir))
         ]
     in
     fun () ->
       let do_graphql graphql_endpoint =
         match%map
           Graphql_client.query
             Graphql_queries.Get_tracked_accounts.(make @@ makeVariables ())
             graphql_endpoint
         with
         | Ok response -> (
             match response.trackedAccounts with
             | [||] ->
                 printf
                   "😢 You have no tracked accounts!\n\
                    You can make a new one using `mina accounts create`\n" ;
                 Ok ()
             | accounts ->
                 Array.iteri accounts ~f:(fun i w ->
                     printf
                       "Account .%d:\n\
                       \  Public key: %s\n\
                       \  Balance: %s\n\
                       \  Locked: %b\n"
                       (i + 1)
                       (Public_key.Compressed.to_base58_check w.public_key)
                       (Currency.Balance.to_mina_string w.balance.total)
                       (Option.value ~default:true w.locked) ) ;
                 Ok () )
         | Error (`Failed_request _ as err) ->
             Error err
         | Error (`Graphql_error _ as err) ->
             don't_wait_for (Graphql_lib.Client.Connection_error.ok_exn err) ;
             Ok ()
       in
       let do_local conf_dir =
         let wallets_disk_location = conf_dir ^/ "wallets" in
         let%map wallets =
           Secrets.Wallets.load ~logger:(Logger.create ())
             ~disk_location:wallets_disk_location
         in
         match wallets |> Secrets.Wallets.pks with
         | [] ->
             printf
               "😢 You have no tracked accounts!\n\
                You can make a new one using `mina accounts create`\n"
         | accounts ->
             List.iteri accounts ~f:(fun i public_key ->
                 printf "Account .%d:\n  Public key: %s\n" (i + 1)
                   (Public_key.Compressed.to_base58_check public_key) )
       in
       match access_method with
       | `GraphQL graphql_endpoint -> (
           match%map do_graphql graphql_endpoint with
           | Ok () ->
               ()
           | Error err ->
               don't_wait_for (Graphql_lib.Client.Connection_error.ok_exn err) )
       | `Conf_dir conf_dir ->
           do_local conf_dir
       | `None -> (
           let default_graphql_endpoint =
             Cli_lib.Flag.(Uri.Client.{ Types.name; value = default })
           in
           match%bind do_graphql default_graphql_endpoint with
           | Ok () ->
               Deferred.unit
           | Error _res ->
               let conf_dir = Mina_lib.Conf_dir.compute_conf_dir None in
               eprintf
                 "%sWarning: Could not connect to a running daemon.\n\
                  Listing from local directory %s%s\n"
                 Bash_colors.orange conf_dir Bash_colors.none ;
               do_local conf_dir ) )

let create_account =
  let open Command.Param in
  Command.async ~summary:"Create new account"
    (Cli_lib.Background_daemon.graphql_init (return ())
       ~f:(fun graphql_endpoint () ->
         let%bind password =
           Secrets.Keypair.Terminal_stdin.prompt_password
             "Password for new account: "
         in
         let%map response =
           Graphql_client.query_exn
             Graphql_queries.Create_account.(
               make @@ makeVariables ~password:(Bytes.to_string password) ())
             graphql_endpoint
         in
         let pk_string =
           Public_key.Compressed.to_base58_check
             response.createAccount.account.public_key
         in
         printf "\n😄 Added new account!\nPublic key: %s\n" pk_string ) )

let create_hd_account =
  Command.async ~summary:Secrets.Hardware_wallets.create_hd_account_summary
    (Cli_lib.Background_daemon.graphql_init Cli_lib.Flag.Signed_command.hd_index
       ~f:(fun graphql_endpoint hd_index ->
         let%map response =
           Graphql_client.(
             query_exn
               Graphql_queries.Create_hd_account.(
                 make @@ makeVariables ~hd_index ()))
             graphql_endpoint
         in
         let pk_string =
           Public_key.Compressed.to_base58_check
             response.createHDAccount.account.public_key
         in
         printf "\n😄 created HD account with HD-index %s!\nPublic key: %s\n"
           (Mina_numbers.Hd_index.to_string hd_index)
           pk_string ) )

let unlock_account =
  let open Command.Param in
  let pk_flag =
    flag "--public-key" ~aliases:[ "public-key" ]
      ~doc:"PUBLICKEY Public key to be unlocked"
      (required Cli_lib.Arg_type.public_key_compressed)
  in
  Command.async ~summary:"Unlock a tracked account"
    (Cli_lib.Background_daemon.graphql_init pk_flag
       ~f:(fun graphql_endpoint pk_str ->
         let password =
           Deferred.map ~f:Or_error.return
             (Secrets.Password.hidden_line_or_env "Password to unlock account: "
                ~env:Secrets.Keypair.env )
         in
         match%bind password with
         | Ok password_bytes ->
             let%map response =
               Graphql_client.query_exn
                 Graphql_queries.Unlock_account.(
                   make
                   @@ makeVariables ~public_key:pk_str
                        ~password:(Bytes.to_string password_bytes)
                        ())
                 graphql_endpoint
             in
             let pk_string =
               Public_key.Compressed.to_base58_check
                 response.unlockAccount.account.public_key
             in
             printf "\n🔓 Unlocked account!\nPublic key: %s\n" pk_string
         | Error e ->
             Deferred.return
               (printf "❌ Error unlocking account: %s\n" (Error.to_string_hum e)) )
    )

let lock_account =
  let open Command.Param in
  let pk_flag =
    flag "--public-key" ~aliases:[ "public-key" ]
      ~doc:"PUBLICKEY Public key of account to be locked"
      (required Cli_lib.Arg_type.public_key_compressed)
  in
  Command.async ~summary:"Lock a tracked account"
    (Cli_lib.Background_daemon.graphql_init pk_flag
       ~f:(fun graphql_endpoint pk ->
         let%map response =
           Graphql_client.query_exn
             Graphql_queries.Lock_account.(
               make @@ makeVariables ~public_key:pk ())
             graphql_endpoint
         in
         let pk_string =
           Public_key.Compressed.to_base58_check response.lockAccount.public_key
         in
         printf "🔒 Locked account!\nPublic key: %s\n" pk_string ) )

let generate_libp2p_keypair_do privkey_path =
  Cli_lib.Exceptions.handle_nicely
  @@ fun () ->
  Deferred.ignore_m
    (let open Deferred.Let_syntax in
    (* FIXME: I'd like to accumulate messages into this logger and only dump them out in failure paths. *)
    let logger = Logger.null () in
    (* Using the helper only for keypair generation requires no state. *)
    File_system.with_temp_dir "mina-generate-libp2p-keypair" ~f:(fun tmpd ->
        match%bind
          Mina_net2.create ~logger ~conf_dir:tmpd ~all_peers_seen_metric:false
            ~pids:(Child_processes.Termination.create_pid_table ())
            ~on_peer_connected:ignore ~on_peer_disconnected:ignore ()
        with
        | Ok net ->
            let%bind me = Mina_net2.generate_random_keypair net in
            let%bind () = Mina_net2.shutdown net in
            let%map () =
              Secrets.Libp2p_keypair.Terminal_stdin.write_exn ~privkey_path me
            in
            printf "libp2p keypair:\n%s\n" (Mina_net2.Keypair.to_string me)
        | Error e ->
            [%log fatal] "failed to generate libp2p keypair: $error"
              ~metadata:[ ("error", Error_json.error_to_yojson e) ] ;
            exit 20 ))

let generate_libp2p_keypair =
  Command.async
    ~summary:"Generate a new libp2p keypair and print out the peer ID"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_write_path in
    generate_libp2p_keypair_do privkey_path)

let trustlist_ip_flag =
  Command.Param.(
    flag "--ip-address" ~aliases:[ "ip-address" ]
      ~doc:"CIDR An IPv4 CIDR mask for the client trustlist (eg, 10.0.0.0/8)"
      (required Cli_lib.Arg_type.cidr_mask))

let trustlist_add =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  Command.async ~summary:"Add an IP to the trustlist"
    (Cli_lib.Background_daemon.rpc_init trustlist_ip_flag
       ~f:(fun port trustlist_ip ->
         let trustlist_ip_string = Unix.Cidr.to_string trustlist_ip in
         match%map Client.dispatch Add_trustlist.rpc trustlist_ip port with
         | Ok (Ok ()) ->
             printf "Added %s to client trustlist" trustlist_ip_string
         | Ok (Error e) ->
             eprintf "Error adding %s to client trustlist: %s"
               trustlist_ip_string (Error.to_string_hum e)
         | Error e ->
             eprintf "Unknown error doing daemon RPC: %s"
               (Error.to_string_hum e) ) )

let trustlist_remove =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  Command.async ~summary:"Remove a CIDR mask from the trustlist"
    (Cli_lib.Background_daemon.rpc_init trustlist_ip_flag
       ~f:(fun port trustlist_ip ->
         let trustlist_ip_string = Unix.Cidr.to_string trustlist_ip in
         match%map Client.dispatch Remove_trustlist.rpc trustlist_ip port with
         | Ok (Ok ()) ->
             printf "Removed %s to client trustlist" trustlist_ip_string
         | Ok (Error e) ->
             eprintf "Error removing %s from client trustlist: %s"
               trustlist_ip_string (Error.to_string_hum e)
         | Error e ->
             eprintf "Unknown error doing daemon RPC: %s"
               (Error.to_string_hum e) ) )

let trustlist_list =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  let open Command.Param in
  Command.async ~summary:"List the CIDR masks in the trustlist"
    (Cli_lib.Background_daemon.rpc_init (return ()) ~f:(fun port () ->
         match%map Client.dispatch Get_trustlist.rpc () port with
         | Ok ips ->
             printf
               "The following IPs are permitted to connect to the daemon \
                control port:\n" ;
             List.iter ips ~f:(fun ip -> printf "%s\n" (Unix.Cidr.to_string ip))
         | Error e ->
             eprintf "Unknown error doing daemon RPC: %s"
               (Error.to_string_hum e) ) )

let get_peers_graphql =
  Command.async ~summary:"List the peers currently connected to the daemon"
    (Cli_lib.Background_daemon.graphql_init
       Command.Param.(return ())
       ~f:(fun graphql_endpoint () ->
         let%map response =
           Graphql_client.query_exn
             Graphql_queries.Get_peers.(make @@ makeVariables ())
             graphql_endpoint
         in
         Array.iter response.getPeers ~f:(fun peer ->
             printf "%s\n"
               (Network_peer.Peer.to_multiaddr_string
                  { host = Unix.Inet_addr.of_string peer.host
                  ; libp2p_port = peer.libp2pPort
                  ; peer_id = peer.peerId
                  } ) ) ) )

let add_peers_graphql =
  let open Command in
  let seed =
    Param.(
      flag "--seed" ~aliases:[ "-seed" ]
        ~doc:
          "true/false Whether to add these peers as 'seed' peers, which may \
           perform peer exchange. Default: true"
        (optional bool))
  in
  let peers =
    Param.(anon Anons.(non_empty_sequence_as_list ("peer" %: string)))
  in
  Command.async
    ~summary:
      "Add peers to the daemon\n\n\
       Addresses take the format /ip4/IPADDR/tcp/PORT/p2p/PEERID"
    (Cli_lib.Background_daemon.graphql_init (Param.both peers seed)
       ~f:(fun graphql_endpoint (input_peers, seed) ->
         let open Deferred.Let_syntax in
         let peers =
           List.map input_peers ~f:(fun peer ->
               match
                 Mina_net2.Multiaddr.of_string peer
                 |> Mina_net2.Multiaddr.to_peer
               with
               | Some peer ->
                   peer
               | None ->
                   eprintf
                     "Could not parse %s as a peer address. It should use the \
                      format /ip4/IPADDR/tcp/PORT/p2p/PEERID"
                     peer ;
                   Core.exit 1 )
         in
         let seed = Option.value ~default:true seed in
         let%map response =
           Graphql_client.query_exn
             Graphql_queries.Add_peers.(make @@ makeVariables ~peers ~seed ())
             graphql_endpoint
         in
         printf "Requested to add peers:\n" ;
         Array.iter response.addPeers ~f:(fun peer ->
             printf "%s\n"
               (Network_peer.Peer.to_multiaddr_string
                  { host = Unix.Inet_addr.of_string peer.host
                  ; libp2p_port = peer.libp2pPort
                  ; peer_id = peer.peerId
                  } ) ) ) )

let compile_time_constants =
  Command.async
    ~summary:"Print a JSON map of the compile-time consensus parameters"
    (Command.Param.return (fun () ->
         let home = Core.Sys.home_directory () in
         let conf_dir = home ^/ Cli_lib.Default.conf_dir_name in
         let genesis_dir =
           let home = Core.Sys.home_directory () in
           home ^/ Cli_lib.Default.conf_dir_name
         in
         let config_file =
           match Sys.getenv "MINA_CONFIG_FILE" with
           | Some config_file ->
               config_file
           | None ->
               conf_dir ^/ "daemon.json"
         in
         let open Async in
         let%map ({ consensus_constants; _ } as precomputed_values), _ =
           config_file |> Genesis_ledger_helper.load_config_json >>| Or_error.ok
           >>| Option.value ~default:(`Assoc [])
           >>| Runtime_config.of_yojson >>| Result.ok
           >>| Option.value ~default:Runtime_config.default
           >>= Genesis_ledger_helper.init_from_config_file ~genesis_dir
                 ~logger:(Logger.null ()) ~proof_level:None
           >>| Or_error.ok_exn
         in
         let all_constants =
           `Assoc
             [ ( "genesis_state_timestamp"
               , `String
                   ( Block_time.to_time_exn
                       consensus_constants.genesis_state_timestamp
                   |> Core.Time.to_string_iso8601_basic ~zone:Core.Time.Zone.utc
                   ) )
             ; ("k", `Int (Unsigned.UInt32.to_int consensus_constants.k))
             ; ( "coinbase"
               , `String
                   (Currency.Amount.to_mina_string
                      precomputed_values.constraint_constants.coinbase_amount )
               )
             ; ( "block_window_duration_ms"
               , `Int
                   precomputed_values.constraint_constants
                     .block_window_duration_ms )
             ; ("delta", `Int (Unsigned.UInt32.to_int consensus_constants.delta))
             ; ( "sub_windows_per_window"
               , `Int
                   (Unsigned.UInt32.to_int
                      consensus_constants.sub_windows_per_window ) )
             ; ( "slots_per_sub_window"
               , `Int
                   (Unsigned.UInt32.to_int
                      consensus_constants.slots_per_sub_window ) )
             ; ( "slots_per_window"
               , `Int
                   (Unsigned.UInt32.to_int consensus_constants.slots_per_window)
               )
             ; ( "slots_per_epoch"
               , `Int
                   (Unsigned.UInt32.to_int consensus_constants.slots_per_epoch)
               )
             ]
         in
         Core_kernel.printf "%s\n%!" (Yojson.Safe.to_string all_constants) ) )

let node_status =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let daemon_peers_flag =
    flag "--daemon-peers" ~aliases:[ "daemon-peers" ] no_arg
      ~doc:"Get node statuses for peers known to the daemon"
  in
  let peers_flag =
    flag "--peers" ~aliases:[ "peers" ]
      (optional (Arg_type.comma_separated string))
      ~doc:"CSV-LIST Peer multiaddrs for obtaining node status"
  in
  let show_errors_flag =
    flag "--show-errors" ~aliases:[ "show-errors" ] no_arg
      ~doc:"Include error responses in output"
  in
  let flags = Args.zip3 daemon_peers_flag peers_flag show_errors_flag in
  Command.async ~summary:"Get node statuses for a set of peers"
    (Cli_lib.Background_daemon.rpc_init flags
       ~f:(fun port (daemon_peers, peers, show_errors) ->
         if
           (Option.is_none peers && not daemon_peers)
           || (Option.is_some peers && daemon_peers)
         then (
           eprintf
             "Must provide exactly one of daemon-peers or peer-ids flags\n%!" ;
           don't_wait_for (exit 33) ) ;
         let peer_ids_opt =
           Option.map peers ~f:(fun peers ->
               List.map peers ~f:Mina_net2.Multiaddr.of_string )
         in
         match%map
           Daemon_rpcs.Client.dispatch Daemon_rpcs.Get_node_status.rpc
             peer_ids_opt port
         with
         | Ok all_status_data ->
             let all_status_data =
               if show_errors then all_status_data
               else
                 List.filter all_status_data ~f:(fun td ->
                     match td with Ok _ -> true | Error _ -> false )
             in
             List.iter all_status_data ~f:(fun peer_status_data ->
                 printf "%s\n%!"
                   ( Yojson.Safe.to_string
                   @@ Mina_networking.Rpcs.Get_node_status.response_to_yojson
                        peer_status_data ) )
         | Error err ->
             printf "Failed to get node status: %s\n%!"
               (Error.to_string_hum err) ) )

let object_lifetime_statistics =
  let open Daemon_rpcs in
  let open Command.Param in
  Command.async ~summary:"Dump internal object lifetime statistics to JSON"
    (Cli_lib.Background_daemon.rpc_init (return ()) ~f:(fun port () ->
         match%map
           Client.dispatch Get_object_lifetime_statistics.rpc () port
         with
         | Ok stats ->
             print_endline stats
         | Error err ->
             printf "Failed to get object lifetime statistics: %s\n%!"
               (Error.to_string_hum err) ) )

let archive_blocks =
  let params =
    let open Command.Let_syntax in
    let%map_open files =
      Command.Param.anon
        Command.Anons.(sequence ("FILES" %: Command.Param.string))
    and success_file =
      Command.Param.flag "--successful-files" ~aliases:[ "successful-files" ]
        ~doc:"PATH Appends the list of files that were processed successfully"
        (Command.Flag.optional Command.Param.string)
    and failure_file =
      Command.Param.flag "--failed-files" ~aliases:[ "failed-files" ]
        ~doc:"PATH Appends the list of files that failed to be processed"
        (Command.Flag.optional Command.Param.string)
    and log_successes =
      Command.Param.flag "--log-successful" ~aliases:[ "log-successful" ]
        ~doc:
          "true/false Whether to log messages for files that were processed \
           successfully"
        (Command.Flag.optional_with_default true Command.Param.bool)
    and archive_process_location = Cli_lib.Flag.Host_and_port.Daemon.archive
    and precomputed_flag =
      Command.Param.flag "--precomputed" ~aliases:[ "precomputed" ] no_arg
        ~doc:"Blocks are in precomputed JSON format"
    and extensional_flag =
      Command.Param.flag "--extensional" ~aliases:[ "extensional" ] no_arg
        ~doc:"Blocks are in extensional JSON format"
    in
    ( files
    , success_file
    , failure_file
    , log_successes
    , archive_process_location
    , precomputed_flag
    , extensional_flag )
  in
  Command.async
    ~summary:
      "Archive a block from a file.\n\n\
       If an archive address is given, this process will communicate with the \
       archive node directly; otherwise it will communicate through the daemon \
       over the rest-server"
    (Cli_lib.Background_daemon.graphql_init params
       ~f:(fun
            graphql_endpoint
            ( files
            , success_file
            , failure_file
            , log_successes
            , archive_process_location
            , precomputed_flag
            , extensional_flag )
          ->
         if Bool.equal precomputed_flag extensional_flag then
           failwith
             "Must provide exactly one of -precomputed and -extensional flags" ;
         let make_send_block ~graphql_make ~archive_dispatch block =
           match archive_process_location with
           | Some archive_process_location ->
               (* Connect directly to the archive node. *)
               archive_dispatch archive_process_location block
           | None ->
               (* Send the requests over GraphQL. *)
               let%map.Deferred.Or_error _res =
                 (* Don't catch this error: [query_exn] already handles
                    printing etc.
                 *)
                 Graphql_client.query (graphql_make block) graphql_endpoint
                 |> Deferred.Result.map_error ~f:(function
                      | `Failed_request e ->
                          Error.create "Unable to connect to Mina daemon" ()
                            (fun () ->
                              Sexp.List
                                [ List
                                    [ Atom "uri"
                                    ; Atom
                                        (Uri.to_string graphql_endpoint.value)
                                    ]
                                ; List
                                    [ Atom "uri_flag"
                                    ; Atom graphql_endpoint.name
                                    ]
                                ; List [ Atom "error_message"; Atom e ]
                                ] )
                      | `Graphql_error e ->
                          Error.createf "GraphQL error: %s" e )
               in
               ()
         in
         let output_file_line path =
           match path with
           | Some path ->
               let file = Out_channel.create ~append:true path in
               fun line -> Out_channel.output_lines file [ line ]
           | None ->
               fun _line -> ()
         in
         let add_to_success_file = output_file_line success_file in
         let add_to_failure_file = output_file_line failure_file in
         let send_precomputed_block =
           make_send_block
             ~graphql_make:(fun block ->
               Graphql_queries.Archive_precomputed_block.(
                 make @@ makeVariables ~block ()) )
             ~archive_dispatch:
               Mina_lib.Archive_client.dispatch_precomputed_block
         in
         let send_extensional_block =
           make_send_block
             ~graphql_make:(fun block ->
               Graphql_queries.Archive_extensional_block.(
                 make @@ makeVariables ~block ()) )
             ~archive_dispatch:
               Mina_lib.Archive_client.dispatch_extensional_block
         in
         Deferred.List.iter files ~f:(fun path ->
             match%map
               let%bind.Deferred.Or_error block_json =
                 Or_error.try_with (fun () ->
                     In_channel.with_file path ~f:(fun in_channel ->
                         Yojson.Safe.from_channel in_channel ) )
                 |> Result.map_error ~f:(fun err ->
                        Error.tag_arg err "Could not parse JSON from file" path
                          String.sexp_of_t )
                 |> Deferred.return
               in
               let open Deferred.Or_error.Let_syntax in
               if precomputed_flag then
                 let%bind precomputed_block =
                   Mina_block.Precomputed.of_yojson block_json
                   |> Result.map_error ~f:(fun err ->
                          Error.tag_arg (Error.of_string err)
                            "Could not parse JSON as a precomputed block from \
                             file"
                            path String.sexp_of_t )
                   |> Deferred.return
                 in
                 send_precomputed_block precomputed_block
               else if extensional_flag then
                 let%bind extensional_block =
                   Archive_lib.Extensional.Block.of_yojson block_json
                   |> Result.map_error ~f:(fun err ->
                          Error.tag_arg (Error.of_string err)
                            "Could not parse JSON as an extensional block from \
                             file"
                            path String.sexp_of_t )
                   |> Deferred.return
                 in
                 send_extensional_block extensional_block
               else
                 (* should be unreachable *)
                 failwith
                   "Expected exactly one of precomputed, extensional flags"
             with
             | Ok () ->
                 if log_successes then
                   Format.printf "Sent block to archive node from %s@." path ;
                 add_to_success_file path
             | Error err ->
                 Format.eprintf
                   "@[<v>Failed to send block to archive node from %s.@,\
                    Error:@,\
                    %s@]@."
                   path (Error.to_string_hum err) ;
                 add_to_failure_file path ) ) )

let receipt_chain_hash =
  let open Command.Let_syntax in
  Command.basic
    ~summary:
      "Compute the next receipt chain hash from the previous hash and \
       transaction ID"
    (let%map_open previous_hash =
       flag "--previous-hash"
         ~doc:"HASH Previous receipt chain hash, Base58Check-encoded"
         (required string)
     and transaction_id =
       flag "--transaction-id"
         ~doc:"TRANSACTION_ID Transaction ID, Base64-encoded" (required string)
     and index =
       flag "--index"
         ~doc:
           "NN For a zkApp, 0 for fee payer or 1-based index of account update"
         (optional string)
     in
     fun () ->
       let previous_hash =
         Receipt.Chain_hash.of_base58_check_exn previous_hash
       in
       let hash =
         match index with
         | None ->
             let signed_cmd =
               Signed_command.of_base64 transaction_id |> Or_error.ok_exn
             in
             Receipt.Chain_hash.cons_signed_command_payload
               (Signed_command_payload signed_cmd.payload) previous_hash
         | Some n ->
             let zkapp_cmd =
               Zkapp_command.of_base64 transaction_id |> Or_error.ok_exn
             in
             let receipt_elt =
               let _txn_commitment, full_txn_commitment =
                 Zkapp_command.get_transaction_commitments zkapp_cmd
               in
               Receipt.Zkapp_command_elt.Zkapp_command_commitment
                 full_txn_commitment
             in
             let account_update_index = Mina_numbers.Index.of_string n in
             Receipt.Chain_hash.cons_zkapp_command_commitment
               account_update_index receipt_elt previous_hash
       in
       printf "%s\n" (Receipt.Chain_hash.to_base58_check hash) )

let chain_id_inputs =
  let open Deferred.Let_syntax in
  Command.async ~summary:"Print the inputs that yield the current chain id"
    (Cli_lib.Background_daemon.rpc_init (Command.Param.all_unit [])
       ~f:(fun port () ->
         let open Daemon_rpcs in
         match%map Client.dispatch Chain_id_inputs.rpc () port with
         | Ok
             ( genesis_state_hash
             , genesis_constants
             , snark_keys
             , protocol_major_version ) ->
             let open Format in
             printf
               "@[<v>Genesis state hash: %s@,\
                @[<v 2>Genesis_constants:@,\
                Protocol:          %a@,\
                Txn pool max size: %d@,\
                Num accounts:      %a@,\
                @]@,\
                @[<v 2>Snark keys:@,\
                %a@]@,\
                Protocol major version: %d@]@."
               (State_hash.to_base58_check genesis_state_hash)
               Yojson.Safe.pp
               (Genesis_constants.Protocol.to_yojson genesis_constants.protocol)
               genesis_constants.txpool_max_size
               (pp_print_option
                  ~none:(fun ppf () -> pp_print_string ppf "None")
                  pp_print_int )
               genesis_constants.num_accounts
               (pp_print_list ~pp_sep:pp_print_cut pp_print_string)
               snark_keys protocol_major_version
         | Error err ->
             Format.eprintf "Could not get chain id inputs: %s@."
               (Error.to_string_hum err) ) )

let hash_transaction =
  let open Command.Let_syntax in
  Command.basic
    ~summary:"Compute the hash of a transaction from its transaction ID"
    (let%map_open transaction_id =
       flag "--transaction-id" ~doc:"ID ID of the transaction to hash"
         (required string)
     in
     fun () ->
       match Transaction_hash.hash_of_transaction_id transaction_id with
       | Ok hash ->
           printf "%s\n" (Transaction_hash.to_base58_check hash)
       | Error err ->
           Format.eprintf "Could not hash transaction: %s@."
             (Error.to_string_hum err) )

let humanize_graphql_error
    ~(graphql_endpoint : Uri.t Cli_lib.Flag.Types.with_name) = function
  | `Failed_request e ->
      Error.create "Unable to connect to Mina daemon" () (fun () ->
          Sexp.List
            [ List [ Atom "uri"; Atom (Uri.to_string graphql_endpoint.value) ]
            ; List [ Atom "uri_flag"; Atom graphql_endpoint.name ]
            ; List [ Atom "error_message"; Atom e ]
            ] )
  | `Graphql_error e ->
      Error.createf "GraphQL error: %s" e

let runtime_config =
  Command.async
    ~summary:"Compute the runtime configuration used by a running daemon"
    (Cli_lib.Background_daemon.graphql_init (Command.Param.return ())
       ~f:(fun graphql_endpoint () ->
         match%bind
           Graphql_client.query
             Graphql_queries.Runtime_config.(make @@ makeVariables ())
             graphql_endpoint
         with
         | Ok runtime_config ->
             Format.printf "%s@."
               (Yojson.Basic.pretty_to_string runtime_config.runtimeConfig) ;
             return ()
         | Error err ->
             Format.eprintf
               "@[<v>Failed to retrieve runtime configuration. Error:@,%s@]@."
               (Error.to_string_hum
                  (humanize_graphql_error ~graphql_endpoint err) ) ;
             exit 1 ) )

let thread_graph =
  Command.async
    ~summary:
      "Return a Graphviz Dot graph representation of the internal thread \
       hierarchy"
    (Cli_lib.Background_daemon.graphql_init (Command.Param.return ())
       ~f:(fun graphql_endpoint () ->
         match%bind
           Graphql_client.query
             Graphql_queries.Thread_graph.(make @@ makeVariables ())
             graphql_endpoint
         with
         | Ok graph ->
             print_endline graph.threadGraph ;
             return ()
         | Error e ->
             Format.eprintf
               "@[<v>Failed to retrieve runtime configuration. Error:@,%s@]@."
               (Error.to_string_hum
                  (humanize_graphql_error ~graphql_endpoint e) ) ;
             exit 1 ) )

let itn_create_accounts =
  Command.async ~summary:"Fund new accounts for incentivized testnet"
    (let open Command.Param in
    let privkey_path = Cli_lib.Flag.privkey_read_path in
    let key_prefix =
      flag "--key-prefix" ~doc:"STRING prefix of keyfiles" (required string)
    in
    let num_accounts =
      flag "--num-accounts" ~doc:"NN Number of new accounts" (required int)
    in
    let fee =
      flag "--fee"
        ~doc:
          (sprintf "NN Fee in nanomina paid to create an account (minimum: %s)"
             Mina_compile_config.minimum_user_command_fee_string )
        (required int)
    in
    let amount =
      flag "--amount"
        ~doc:"NN Amount in nanomina to be divided among new accounts"
        (required int)
    in
    let args = Args.zip5 privkey_path key_prefix num_accounts fee amount in
    Cli_lib.Background_daemon.rpc_init args ~f:Itn.create_accounts)

module Visualization = struct
  let create_command (type rpc_response) ~name ~f
      (rpc : (string, rpc_response) Rpc.Rpc.t) =
    let open Deferred.Let_syntax in
    Command.async
      ~summary:(sprintf !"Produce a visualization of the %s" name)
      (Cli_lib.Background_daemon.rpc_init
         Command.Param.(anon @@ ("output-filepath" %: string))
         ~f:(fun port filename ->
           let%map message =
             match%map Daemon_rpcs.Client.dispatch rpc filename port with
             | Ok response ->
                 f filename response
             | Error e ->
                 sprintf "Could not save file: %s\n" (Error.to_string_hum e)
           in
           print_string message ) )

  module Frontier = struct
    let name = "transition-frontier"

    let command =
      create_command ~name Daemon_rpcs.Visualization.Frontier.rpc
        ~f:(fun filename -> function
        | `Active () ->
            Visualization_message.success name filename
        | `Bootstrapping ->
            Visualization_message.bootstrap name )
  end

  module Registered_masks = struct
    let name = "registered-masks"

    let command =
      create_command ~name Daemon_rpcs.Visualization.Registered_masks.rpc
        ~f:(fun filename () -> Visualization_message.success name filename)
  end

  let command_group =
    Command.group ~summary:"Visualize data structures special to Mina"
      [ (Frontier.name, Frontier.command)
      ; (Registered_masks.name, Registered_masks.command)
      ]
end

let accounts =
  Command.group ~summary:"Client commands concerning account management"
    ~preserve_subcommand_order:()
    [ ("list", list_accounts)
    ; ("create", create_account)
    ; ("import", import_key)
    ; ("export", export_key)
    ; ("unlock", unlock_account)
    ; ("lock", lock_account)
    ]

let client =
  Command.group ~summary:"Lightweight client commands"
    ~preserve_subcommand_order:()
    [ ("get-balance", get_balance_graphql)
    ; ("get-tokens", get_tokens_graphql)
    ; ("send-payment", send_payment_graphql)
    ; ("delegate-stake", delegate_stake_graphql)
    ; ("cancel-transaction", cancel_transaction_graphql)
    ; ("set-snark-worker", set_snark_worker)
    ; ("set-snark-work-fee", set_snark_work_fee)
    ; ("export-logs", Export_logs.export_via_graphql)
    ; ("export-local-logs", Export_logs.export_locally)
    ; ("stop-daemon", stop_daemon)
    ; ("status", status)
    ]

let client_trustlist_group =
  Command.group ~summary:"Client trustlist management"
    ~preserve_subcommand_order:()
    [ ("add", trustlist_add)
    ; ("list", trustlist_list)
    ; ("remove", trustlist_remove)
    ]

let advanced =
  let cmds0 =
    [ ("get-nonce", get_nonce_cmd)
    ; ("client-trustlist", client_trustlist_group)
    ; ("get-trust-status", get_trust_status)
    ; ("get-trust-status-all", get_trust_status_all)
    ; ("get-public-keys", get_public_keys)
    ; ("reset-trust-status", reset_trust_status)
    ; ("batch-send-payments", batch_send_payments)
    ; ("status-clear-hist", status_clear_hist)
    ; ("wrap-key", wrap_key)
    ; ("dump-keypair", dump_keypair)
    ; ("constraint-system-digests", constraint_system_digests)
    ; ("start-tracing", start_tracing)
    ; ("stop-tracing", stop_tracing)
    ; ("start-internal-tracing", start_internal_tracing)
    ; ("stop-internal-tracing", stop_internal_tracing)
    ; ("snark-job-list", snark_job_list)
    ; ("pooled-user-commands", pooled_user_commands)
    ; ("pooled-zkapp-commands", pooled_zkapp_commands)
    ; ("snark-pool-list", snark_pool_list)
    ; ("pending-snark-work", pending_snark_work)
    ; ("compile-time-constants", compile_time_constants)
    ; ("node-status", node_status)
    ; ("visualization", Visualization.command_group)
    ; ("verify-receipt", verify_receipt)
    ; ("generate-keypair", Cli_lib.Commands.generate_keypair)
    ; ("validate-keypair", Cli_lib.Commands.validate_keypair)
    ; ("validate-transaction", Cli_lib.Commands.validate_transaction)
    ; ("send-rosetta-transactions", send_rosetta_transactions_graphql)
    ; ("time-offset", get_time_offset_graphql)
    ; ("get-peers", get_peers_graphql)
    ; ("add-peers", add_peers_graphql)
    ; ("object-lifetime-statistics", object_lifetime_statistics)
    ; ("archive-blocks", archive_blocks)
    ; ("compute-receipt-chain-hash", receipt_chain_hash)
    ; ("hash-transaction", hash_transaction)
    ; ("set-coinbase-receiver", set_coinbase_receiver_graphql)
    ; ("chain-id-inputs", chain_id_inputs)
    ; ("runtime-config", runtime_config)
    ; ("vrf", Cli_lib.Commands.Vrf.command_group)
    ; ("thread-graph", thread_graph)
    ]
  in
  let cmds =
    if Mina_compile_config.itn_features then
      ("itn-create-accounts", itn_create_accounts) :: cmds0
    else cmds0
  in
  Command.group ~summary:"Advanced client commands" cmds

let ledger =
  Command.group ~summary:"Ledger commands"
    [ ("export", export_ledger)
    ; ("hash", hash_ledger)
    ; ("currency", currency_in_ledger)
    ]

let libp2p =
  Command.group ~summary:"Libp2p commands"
    [ ("generate-keypair", generate_libp2p_keypair) ]
