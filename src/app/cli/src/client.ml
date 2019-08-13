open Core
open Async
open Signature_lib
open Coda_base

let print_rpc_error error =
  eprintf "RPC connection error: %s\n" (Error.to_string_hum error)

let dispatch rpc query port =
  Tcp.with_connection
    (Tcp.Where_to_connect.of_host_and_port (Cli_lib.Port.of_local port))
    ~timeout:(Time.Span.of_sec 1.)
    (fun _ r w ->
      let open Deferred.Let_syntax in
      match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
      | Error exn ->
          return (Or_error.of_exn exn)
      | Ok conn ->
          Rpc.Rpc.dispatch rpc conn query )

(** Call an RPC, passing handlers for a successful call and a failing one. Note
    that a successful *call* may have failed on the server side and returned a
    failing result. To deal with that, the success handler returns an
    Or_error. *)
let dispatch_with_message rpc query port ~success ~error =
  let fail err = eprintf "%s\n%!" err ; exit 14 in
  match%bind dispatch rpc query port with
  | Ok x -> (
    match success x with
    | Ok res ->
        printf "%s\n" res ; Deferred.unit
    | Error e ->
        fail (Error.to_string_hum e) )
  | Error e ->
      fail (error e)

let dispatch_pretty_message (type t)
    (module Print : Cli_lib.Render.Printable_intf with type t = t)
    ?(json = true) rpc query port =
  dispatch rpc query port >>| Cli_lib.Render.print (module Print) json

module Args = struct
  open Command.Param

  let zip2 = map2 ~f:(fun arg1 arg2 -> (arg1, arg2))

  let zip3 = map3 ~f:(fun arg1 arg2 arg3 -> (arg1, arg2, arg3))

  let zip4 arg1 arg2 arg3 arg4 =
    return (fun a b c d -> (a, b, c, d)) <*> arg1 <*> arg2 <*> arg3 <*> arg4
end

let stop_daemon =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  let open Command.Param in
  Command.async ~summary:"Stop the daemon"
    (Cli_lib.Background_daemon.init (return ()) ~f:(fun port () ->
         match%map dispatch Stop_daemon.rpc () port with
         | Ok () ->
             printf "Daemon stopping\n"
         | Error e ->
             printf "Daemon likely stopped: %s\n" (Error.to_string_hum e) ))

let get_balance =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let address_flag =
    flag "address"
      ~doc:"PUBLICKEY Public-key for which you want to check the balance"
      (required Cli_lib.Arg_type.public_key)
  in
  Command.async ~summary:"Get balance associated with a public key"
    (Cli_lib.Background_daemon.init address_flag ~f:(fun port address ->
         match%map
           dispatch Daemon_rpcs.Get_balance.rpc
             (Public_key.compress address)
             port
         with
         | Ok (Some b) ->
             printf "Balance: %s coda\n" (Currency.Balance.to_string b)
         | Ok None ->
             printf "There are no funds in this account\n"
         | Error e ->
             printf "Failed to get balance\n%s\n" (Error.to_string_hum e) ))

let print_trust_status status json =
  if json then
    printf "%s\n"
      (Yojson.Safe.to_string (Trust_system.Peer_status.to_yojson status))
  else
    let ban_status =
      match status.banned with
      | Unbanned ->
          "Unbanned"
      | Banned_until tm ->
          sprintf "Banned_until %s" (Time.to_string_abs tm ~zone:Time.Zone.utc)
    in
    printf "%0.04f, %s\n" status.trust ban_status

let round_trust_score trust_status =
  let open Trust_system.Peer_status in
  let trust = Float.round_decimal trust_status.trust ~decimal_digits:4 in
  {trust_status with trust}

let get_trust_status =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let address_flag =
    flag "ip-address"
      ~doc:
        "IP An IPv4 or IPv6 address for which you want to query the trust \
         status"
      (required Cli_lib.Arg_type.ip_address)
  in
  let json_flag = Cli_lib.Flag.json in
  let flags = Args.zip2 address_flag json_flag in
  Command.async ~summary:"Get the trust status associated with an IP address"
    (Cli_lib.Background_daemon.init flags ~f:(fun port (ip_address, json) ->
         match%map
           dispatch Daemon_rpcs.Get_trust_status.rpc ip_address port
         with
         | Ok status ->
             print_trust_status (round_trust_score status) json
         | Error e ->
             printf "Failed to get trust status %s\n" (Error.to_string_hum e)
     ))

let ip_trust_statuses_to_yojson ip_trust_statuses =
  let items =
    List.map ip_trust_statuses ~f:(fun (ip_addr, status) ->
        `Assoc
          [ ("ip", `String (Unix.Inet_addr.to_string ip_addr))
          ; ("status", Trust_system.Peer_status.to_yojson status) ] )
  in
  `List items

let print_ip_trust_statuses ip_statuses json =
  if json then
    printf "%s\n"
      (Yojson.Safe.to_string @@ ip_trust_statuses_to_yojson ip_statuses)
  else
    List.iter ip_statuses ~f:(fun (ip_addr, status) ->
        printf "%s : " (Unix.Inet_addr.to_string ip_addr) ;
        print_trust_status status false )

let get_trust_status_all =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let nonzero_flag =
    flag "nonzero-only" no_arg
      ~doc:"Only show trust statuses whose trust score is nonzero"
  in
  let json_flag = Cli_lib.Flag.json in
  let flags = Args.zip2 nonzero_flag json_flag in
  Command.async
    ~summary:"Get trust statuses for all peers known to the trust system"
    (Cli_lib.Background_daemon.init flags ~f:(fun port (nonzero, json) ->
         match%map dispatch Daemon_rpcs.Get_trust_status_all.rpc () port with
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
             print_ip_trust_statuses filtered_ip_trust_statuses json
         | Error e ->
             printf "Failed to get trust statuses %s\n" (Error.to_string_hum e)
     ))

let reset_trust_status =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let address_flag =
    flag "ip-address"
      ~doc:
        "IP An IPv4 or IPv6 address for which you want to reset the trust \
         status"
      (required Cli_lib.Arg_type.ip_address)
  in
  let json_flag = Cli_lib.Flag.json in
  let flags = Args.zip2 address_flag json_flag in
  Command.async ~summary:"Reset the trust status associated with an IP address"
    (Cli_lib.Background_daemon.init flags ~f:(fun port (ip_address, json) ->
         match%map
           dispatch Daemon_rpcs.Reset_trust_status.rpc ip_address port
         with
         | Ok status ->
             print_trust_status status json
         | Error e ->
             printf "Failed to reset trust status %s\n" (Error.to_string_hum e)
     ))

let get_public_keys =
  let open Daemon_rpcs in
  let open Command.Param in
  let with_balances_flag =
    flag "with-balances" no_arg
      ~doc:"Show corresponding balances to public keys"
  in
  Command.async ~summary:"Get public keys"
    (Cli_lib.Background_daemon.init
       (Args.zip2 with_balances_flag Cli_lib.Flag.json)
       ~f:(fun port (is_balance_included, json) ->
         if is_balance_included then
           dispatch_pretty_message ~json
             (module Cli_lib.Render.Public_key_with_balances)
             Get_public_keys_with_balances.rpc () port
         else
           dispatch_pretty_message ~json
             (module Cli_lib.Render.String_list_formatter)
             Get_public_keys.rpc () port ))

let generate_receipt =
  let open Daemon_rpcs in
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let receipt_hash_flag =
    flag "receipt-chain-hash"
      ~doc:
        "RECEIPTHASH Receipt-chain-hash of the payment that you want to\n\
        \        generate a receipt for"
      (required receipt_chain_hash)
  in
  let address_flag =
    flag "address" ~doc:"PUBLICKEY Public-key address of sender"
      (required public_key_compressed)
  in
  Command.async ~summary:"Generate a receipt for a sent payment"
    (Cli_lib.Background_daemon.init (Args.zip2 receipt_hash_flag address_flag)
       ~f:(fun port (receipt_chain_hash, pk) ->
         dispatch_with_message Prove_receipt.rpc (receipt_chain_hash, pk) port
           ~success:(Or_error.map ~f:Cli_lib.Render.Prove_receipt.to_text)
           ~error:Error.to_string_hum ))

let read_json filepath =
  let%map json_contents = Reader.file_contents filepath in
  Yojson.Safe.from_string json_contents

let verify_receipt =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let proof_path_flag =
    flag "proof-path"
      ~doc:"PROOFFILE File to read json version of payment receipt"
      (required string)
  in
  let payment_path_flag =
    flag "payment-path"
      ~doc:"PAYMENTPATH File to read json version of verifying payment"
      (required string)
  in
  let address_flag =
    flag "address" ~doc:"PUBLICKEY Public-key address of sender"
      (required public_key_compressed)
  in
  Command.async ~summary:"Verify a receipt of a sent payment"
    (Cli_lib.Background_daemon.init
       (Args.zip3 payment_path_flag proof_path_flag address_flag)
       ~f:(fun port (payment_path, proof_path, pk) ->
         let%bind payment_json = read_json payment_path
         and proof_json = read_json proof_path in
         let dispatch_result =
           let open Deferred.Or_error.Let_syntax in
           let to_deferred_or_error result =
             Result.map_error result ~f:Error.of_string |> Deferred.return
           in
           let%bind payment =
             User_command.of_yojson payment_json |> to_deferred_or_error
           and proof =
             Payment_proof.of_yojson proof_json |> to_deferred_or_error
           in
           dispatch Verify_proof.rpc (pk, payment, proof) port
         in
         match%map dispatch_result with
         | Ok (Ok ()) ->
             printf "Payment is valid on the existing blockchain!\n"
         | Error e | Ok (Error e) ->
             eprintf "%s" (Error.to_string_hum e) ))

let get_nonce :
       rpc:(Public_key.Compressed.t, Account.Nonce.t option) Rpc.Rpc.t
    -> Public_key.t
    -> int
    -> (Account.Nonce.t, string) Deferred.Result.t =
 fun ~rpc addr port ->
  let open Deferred.Let_syntax in
  match%map dispatch rpc (Public_key.compress addr) port with
  | Ok (Some n) ->
      Ok n
  | Ok None ->
      Error "No account found at that public_key"
  | Error e ->
      Error (Error.to_string_hum e)

let get_nonce_cmd =
  let open Command.Param in
  let address_flag =
    flag "address" ~doc:"PUBLICKEY Public-key address you want the nonce for"
      (required Cli_lib.Arg_type.public_key)
  in
  Command.async ~summary:"Get the current nonce for an account"
    (Cli_lib.Background_daemon.init address_flag ~f:(fun port address ->
         match%bind get_nonce ~rpc:Daemon_rpcs.Get_nonce.rpc address port with
         | Error e ->
             eprintf "Failed to get nonce: %s\n" e ;
             exit 2
         | Ok nonce ->
             printf "%s\n" (Account.Nonce.to_string nonce) ;
             exit 0 ))

let status =
  let open Daemon_rpcs in
  let flag = Args.zip2 Cli_lib.Flag.json Cli_lib.Flag.performance in
  Command.async ~summary:"Get running daemon status"
    (Cli_lib.Background_daemon.init flag ~f:(fun port (json, performance) ->
         dispatch_pretty_message ~json
           (module Daemon_rpcs.Types.Status)
           Get_status.rpc
           (if performance then `Performance else `None)
           port ))

let status_clear_hist =
  let open Daemon_rpcs in
  let flag = Args.zip2 Cli_lib.Flag.json Cli_lib.Flag.performance in
  Command.async ~summary:"Clear histograms reported in status"
    (Cli_lib.Background_daemon.init flag ~f:(fun port (json, performance) ->
         dispatch_pretty_message ~json
           (module Daemon_rpcs.Types.Status)
           Clear_hist_status.rpc
           (if performance then `Performance else `None)
           port ))

let get_nonce_exn ~rpc public_key port =
  match%bind get_nonce ~rpc public_key port with
  | Error e ->
      eprintf "Failed to get nonce %s\n" e ;
      exit 3
  | Ok nonce ->
      return nonce

let handle_exception_nicely (type a) (f : unit -> a Deferred.t) () :
    a Deferred.t =
  match%bind Deferred.Or_error.try_with ~extract_exn:true f with
  | Ok e ->
      return e
  | Error e ->
      eprintf "Error: %s" (Error.to_string_hum e) ;
      exit 4

let batch_send_payments =
  let module Payment_info = struct
    type t = {receiver: string; amount: Currency.Amount.t; fee: Currency.Fee.t}
    [@@deriving sexp]
  end in
  let payment_path_flag =
    Command.Param.(anon @@ ("payments-file" %: string))
  in
  let get_infos payments_path =
    match%bind
      Reader.load_sexp payments_path [%of_sexp: Payment_info.t list]
    with
    | Ok x ->
        return x
    | Error _ ->
        let sample_info () : Payment_info.t =
          let keypair = Keypair.create () in
          { Payment_info.receiver=
              Public_key.(
                Compressed.to_base58_check (compress keypair.public_key))
          ; amount= Currency.Amount.of_int (Random.int 100)
          ; fee= Currency.Fee.of_int (Random.int 100) }
        in
        eprintf "Could not read payments from %s.\n" payments_path ;
        eprintf
          "The file should be a sexp list of payments. Here is an example file:\n\
           %s\n"
          (Sexp.to_string_hum
             ([%sexp_of: Payment_info.t list]
                (List.init 3 ~f:(fun _ -> sample_info ())))) ;
        exit 5
  in
  let main port (privkey_path, payments_path) =
    let open Deferred.Let_syntax in
    let%bind keypair = Secrets.Keypair.Terminal_stdin.read_exn privkey_path
    and infos = get_infos payments_path in
    let%bind nonce0 =
      get_nonce_exn ~rpc:Daemon_rpcs.Get_nonce.rpc keypair.public_key port
    in
    let _, ts =
      List.fold_map ~init:nonce0 infos ~f:(fun nonce {receiver; amount; fee} ->
          ( Account.Nonce.succ nonce
          , User_command.sign keypair
              (User_command_payload.create ~fee ~nonce
                 ~memo:User_command_memo.dummy
                 ~body:
                   (Payment
                      { receiver=
                          Public_key.Compressed.of_base58_check_exn receiver
                      ; amount })) ) )
    in
    dispatch_with_message Daemon_rpcs.Send_user_commands.rpc
      (ts :> User_command.t list)
      port
      ~success:(fun () ->
        Or_error.return "Successfully enqueued payments in pool" )
      ~error:(fun e ->
        sprintf "Failed to send payments %s" (Error.to_string_hum e) )
  in
  Command.async ~summary:"Send multiple payments from a file"
    (Cli_lib.Background_daemon.init
       (Args.zip2 Cli_lib.Flag.privkey_read_path payment_path_flag)
       ~f:main)

let user_command (body_args : User_command_payload.Body.t Command.Param.t)
    ~label ~summary ~error =
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let amount_flag =
    flag "fee"
      ~doc:
        (Printf.sprintf
           "FEE Amount you are willing to pay to process the transaction \
            (default: %d)"
           (Currency.Fee.to_int Cli_lib.Fee.default_transaction))
      (optional txn_fee)
  in
  let nonce_flag =
    flag "nonce"
      ~doc:
        "NONCE Nonce that you would like to set for your transaction \
         (default: nonce of your account on the best ledger or the successor \
         of highest value nonce of your sent transactions from the \
         transaction pool )"
      (optional txn_nonce)
  in
  let flag =
    Args.zip4 body_args Cli_lib.Flag.privkey_read_path amount_flag nonce_flag
  in
  Command.async ~summary
    (Cli_lib.Background_daemon.init flag
       ~f:(fun port (body, from_account, fee_opt, nonce_opt) ->
         let open Deferred.Let_syntax in
         let%bind sender_kp =
           Secrets.Keypair.Terminal_stdin.read_exn from_account
         in
         let%bind nonce =
           match nonce_opt with
           | Some nonce ->
               return nonce
           | None ->
               get_nonce_exn ~rpc:Daemon_rpcs.Get_inferred_nonce.rpc
                 sender_kp.public_key port
         in
         let fee =
           Option.value ~default:Cli_lib.Fee.default_transaction fee_opt
         in
         let command =
           Coda_commands.setup_user_command ~fee ~nonce
             ~memo:User_command_memo.dummy ~sender_kp body
         in
         dispatch_with_message Daemon_rpcs.Send_user_command.rpc command port
           ~success:
             (Or_error.map ~f:(fun receipt_chain_hash ->
                  sprintf
                    "Dispatched %s with ID %s\nReceipt chain hash is now %s\n"
                    label
                    (User_command.to_base58_check command)
                    (Receipt.Chain_hash.to_string receipt_chain_hash) ))
           ~error:(fun e -> sprintf "%s: %s" error (Error.to_string_hum e)) ))

let send_payment =
  let body =
    let open Command.Let_syntax in
    let open Cli_lib.Arg_type in
    let%map_open receiver =
      flag "receiver"
        ~doc:"PUBLICKEY Public key address to which you want to send money"
        (required public_key_compressed)
    and amount =
      flag "amount" ~doc:"VALUE Payment amount you want to send"
        (required txn_amount)
    in
    User_command_payload.Body.Payment {receiver; amount}
  in
  user_command body ~label:"payment" ~summary:"Send payment to an address"
    ~error:"Failed to send payment"

let get_transaction_status =
  Command.async ~summary:"Get the status of a transaction"
    (Cli_lib.Background_daemon.init
       Command.Param.(anon @@ ("txn" %: string))
       ~f:(fun port serialized_transaction ->
         match User_command.of_base58_check serialized_transaction with
         | Ok user_command ->
             dispatch_with_message Daemon_rpcs.Get_transaction_status.rpc
               user_command port
               ~success:
                 (Or_error.map ~f:(fun status ->
                      sprintf !"Transaction status : %s\n"
                      @@ Transaction_status.State.to_string status ))
               ~error:(fun e ->
                 sprintf "Failed to get transaction status : %s"
                   (Error.to_string_hum e) )
         | Error _e ->
             eprintf "Could not deserialize user command" ;
             exit 16 ))

let delegate_stake =
  let body =
    let open Command.Let_syntax in
    let open Cli_lib.Arg_type in
    let%map_open new_delegate =
      flag "delegate"
        ~doc:
          "PUBLICKEY Public key address to which you want to which you want \
           to delegate your stake"
        (required public_key_compressed)
    in
    User_command_payload.Body.Stake_delegation (Set_delegate {new_delegate})
  in
  user_command body ~label:"delegate"
    ~summary:"Change the address to which you're delegating your coda"
    ~error:"Failed to change delegate"

let wrap_key =
  Command.async ~summary:"Wrap a private key into a private key file"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_write_path in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let%bind privkey =
      Secrets.Password.hidden_line_or_env "Private key: " ~env:"CODA_PRIVKEY"
    in
    let pk =
      Private_key.of_base58_check_exn
        (privkey |> Or_error.ok_exn |> Bytes.to_string)
    in
    let kp = Keypair.of_private_key_exn pk in
    Secrets.Keypair.Terminal_stdin.write_exn kp ~privkey_path)

let dump_keypair =
  Command.async ~summary:"Print out a keypair from a private key file"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_read_path in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let%map kp =
      Secrets.Keypair.read_exn ~privkey_path
        ~password:
          (lazy (Secrets.Password.read "Password for private key file: "))
    in
    printf "Public key: %s\nPrivate key: %s\n"
      ( kp.public_key |> Public_key.compress
      |> Public_key.Compressed.to_base58_check )
      (kp.private_key |> Private_key.to_base58_check))

let generate_keypair =
  Command.async ~summary:"Generate a new public-key/private-key pair"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_write_path in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let kp = Keypair.create () in
    let%bind () = Secrets.Keypair.Terminal_stdin.write_exn kp ~privkey_path in
    printf "Keypair generated\nPublic key: %s\n"
      ( kp.public_key |> Public_key.compress
      |> Public_key.Compressed.to_base58_check ) ;
    exit 0)

let dump_ledger =
  let sl_hash =
    let open Command.Param in
    let h =
      Arg_type.create (fun s ->
          Sexp.of_string_conv_exn s Staged_ledger_hash.Stable.V1.t_of_sexp )
    in
    anon ("staged-ledger-hash" %: h)
  in
  Command.async ~summary:"Print the ledger with given merkle root as a sexp"
    (Cli_lib.Background_daemon.init sl_hash ~f:(fun port sl_hash ->
         dispatch Daemon_rpcs.Get_ledger.rpc sl_hash port
         >>| function
         | Error e ->
             print_rpc_error e
         | Ok (Error e) ->
             printf !"Ledger not found: %s\n" (Error.to_string_hum e)
         | Ok (Ok accounts) ->
             printf !"%{sexp:Account.t list}\n" accounts ))

let constraint_system_digests =
  Command.async ~summary:"Print MD5 digest of each SNARK constraint"
    (Command.Param.return (fun () ->
         let all =
           Transaction_snark.constraint_system_digests ()
           @ Blockchain_snark.Blockchain_transition.constraint_system_digests
               ()
         in
         let all =
           List.sort ~compare:(fun (k1, _) (k2, _) -> String.compare k1 k2) all
         in
         List.iter all ~f:(fun (k, v) -> printf "%s\t%s\n" k (Md5.to_hex v)) ;
         Deferred.unit ))

let snark_job_list =
  let open Deferred.Let_syntax in
  let open Command.Param in
  Command.async ~summary:"List of snark jobs in JSON format"
    (Cli_lib.Background_daemon.init (return ()) ~f:(fun port () ->
         match%map dispatch Daemon_rpcs.Snark_job_list.rpc () port with
         | Ok str ->
             printf "%s" str
         | Error e ->
             print_rpc_error e ))

let start_tracing =
  let open Deferred.Let_syntax in
  let open Command.Param in
  Command.async ~summary:"Start async tracing to $config-directory/$pid.trace"
    (Cli_lib.Background_daemon.init (return ()) ~f:(fun port () ->
         match%map dispatch Daemon_rpcs.Start_tracing.rpc () port with
         | Ok () ->
             printf "Daemon started tracing!"
         | Error e ->
             print_rpc_error e ))

let stop_tracing =
  let open Deferred.Let_syntax in
  let open Command.Param in
  Command.async ~summary:"Stop async tracing"
    (Cli_lib.Background_daemon.init (return ()) ~f:(fun port () ->
         match%map dispatch Daemon_rpcs.Stop_tracing.rpc () port with
         | Ok () ->
             printf "Daemon stopped printing!"
         | Error e ->
             print_rpc_error e ))

let set_staking =
  let privkey_path = Cli_lib.Flag.privkey_write_path in
  Command.async ~summary:"Set new block proposer keys"
    (Cli_lib.Background_daemon.init privkey_path ~f:(fun port privkey_path ->
         let%bind ({Keypair.public_key; _} as keypair) =
           Secrets.Keypair.Terminal_stdin.read_exn privkey_path
         in
         match%map dispatch Daemon_rpcs.Set_staking.rpc [keypair] port with
         | Error e ->
             print_rpc_error e
         | Ok () ->
             printf
               !"New block proposer public key : %s\n"
               (Public_key.Compressed.to_base58_check
                  (Public_key.compress public_key)) ))

module Visualization = struct
  let create_command (type rpc_response) ~name ~f
      (rpc : (string, rpc_response) Rpc.Rpc.t) =
    let open Deferred.Let_syntax in
    Command.async
      ~summary:(sprintf !"Produce a visualization of the %s" name)
      (Cli_lib.Background_daemon.init
         Command.Param.(anon @@ ("output-filepath" %: string))
         ~f:(fun port filename ->
           let%map message =
             match%map dispatch rpc filename port with
             | Ok response ->
                 f filename response
             | Error e ->
                 sprintf "Could not save file: %s\n" (Error.to_string_hum e)
           in
           print_string message ))

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
    Command.group ~summary:"Visualize data structures special to Coda"
      [ (Frontier.name, Frontier.command)
      ; (Registered_masks.name, Registered_masks.command) ]
end

let command =
  Command.group ~summary:"Lightweight client commands"
    ~preserve_subcommand_order:()
    [ ("get-balance", get_balance)
    ; ("send-payment", send_payment)
    ; ("generate-keypair", generate_keypair)
    ; ("delegate-stake", delegate_stake)
    ; ("set-staking", set_staking)
    ; ("generate-receipt", generate_receipt)
    ; ("verify-receipt", verify_receipt)
    ; ("stop-daemon", stop_daemon)
    ; ("status", status) ]

let advanced =
  Command.group ~summary:"Advanced client commands"
    [ ("get-nonce", get_nonce_cmd)
    ; ("get-trust-status", get_trust_status)
    ; ("get-trust-status-all", get_trust_status_all)
    ; ("get-public-keys", get_public_keys)
    ; ("reset-trust-status", reset_trust_status)
    ; ("batch-send-payments", batch_send_payments)
    ; ("status-clear-hist", status_clear_hist)
    ; ("wrap-key", wrap_key)
    ; ("dump-keypair", dump_keypair)
    ; ("dump-ledger", dump_ledger)
    ; ("constraint-system-digests", constraint_system_digests)
    ; ("start-tracing", start_tracing)
    ; ("stop-tracing", stop_tracing)
    ; ("snark-job-list", snark_job_list)
    ; ("visualization", Visualization.command_group) ]
