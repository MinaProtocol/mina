open Core
open Async
open Signature_lib
open Coda_base

let dispatch rpc query port =
  Tcp.with_connection
    (Tcp.Where_to_connect.of_host_and_port (Cli_lib.Port.of_local port))
    ~timeout:(Time.Span.of_sec 1.)
    (fun _ r w ->
      let open Deferred.Let_syntax in
      match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
      | Error exn -> return (Or_error.of_exn exn)
      | Ok conn -> Rpc.Rpc.dispatch rpc conn query )

let dispatch_with_message rpc query port ~success ~error =
  match%bind dispatch rpc query port with
  | Ok x ->
      printf "%s\n" (success x) ;
      Deferred.unit
  | Error e ->
      eprintf "%s\n" (error e) ;
      exit 1

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
         | Ok () -> printf "Daemon stopping\n"
         | Error e ->
             printf "Daemon likely stopped: %s\n" (Error.to_string_hum e) ))

let get_balance =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let address_flag =
    flag "address"
      ~doc:
        "PUBLICKEY Public-key address of which you want to check the balance"
      (required Cli_lib.Arg_type.public_key)
  in
  Command.async ~summary:"Get balance associated with an address"
    (Cli_lib.Background_daemon.init address_flag ~f:(fun port address ->
         match%map
           dispatch Daemon_rpcs.Get_balance.rpc
             (Public_key.compress address)
             port
         with
         | Ok (Some b) -> printf "%s\n" (Currency.Balance.to_string b)
         | Ok None ->
             printf "No account found at that public_key (zero balance)\n"
         | Error e ->
             printf "Failed to get balance %s\n" (Error.to_string_hum e) ))

let get_public_keys =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  let open Command.Param in
  let with_balances_flag =
    flag "with-balances" no_arg
      ~doc:"Show corresponding balances to public keys"
  in
  Command.async ~summary:"Get public keys"
    (Cli_lib.Background_daemon.init
       (return (fun a b -> (a, b)) <*> with_balances_flag <*> Cli_lib.Flag.json)
       ~f:(fun port (is_balance_included, json) ->
         if is_balance_included then
           dispatch_pretty_message ~json
             (module Cli_lib.Render.Public_key_with_balances)
             Get_public_keys_with_balances.rpc () port
         else
           dispatch_pretty_message ~json
             (module Cli_lib.Render.String_list_formatter)
             Get_public_keys.rpc () port ))

let prove_payment =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let receipt_hash_flag =
    flag "receipt-chain-hash"
      ~doc:
        "RECEIPTHASH Receipt-chain-hash of the payment that you want to prove"
      (required receipt_chain_hash)
  in
  let address_flag =
    flag "address" ~doc:"PUBLICKEY Public-key address of sender"
      (required public_key_compressed)
  in
  Command.async ~summary:"Generate a proof of a sent payment"
    (Cli_lib.Background_daemon.init (Args.zip2 receipt_hash_flag address_flag)
       ~f:(fun port (receipt_chain_hash, pk) ->
         dispatch_with_message Prove_receipt.rpc (receipt_chain_hash, pk) port
           ~success:(function
             | Ok result -> Cli_lib.Render.Prove_receipt.to_text result
             | Error e -> Error.to_string_hum e)
           ~error:Error.to_string_hum ))

let read_json filepath =
  let%map json_contents = Reader.file_contents filepath in
  Yojson.Safe.from_string json_contents

let verify_payment =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let proof_path_flag =
    flag "proof-path"
      ~doc:"PROOFFILE File to read json version of payment proof"
      (required file)
  in
  let payment_path_flag =
    flag "payment-path"
      ~doc:"PAYMENTPATH File to read json version of verifying payment"
      (required file)
  in
  let address_flag =
    flag "address" ~doc:"PUBLICKEY Public-key address of sender"
      (required public_key_compressed)
  in
  Command.async ~summary:"Verify a proof of a sent payment"
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
         | Ok (Ok ()) -> printf "Payment is valid on the existing blockchain!"
         | Error e | Ok (Error e) -> eprintf "%s" (Error.to_string_hum e) ))

let get_nonce addr port =
  let open Deferred.Let_syntax in
  match%map
    dispatch Daemon_rpcs.Get_nonce.rpc (Public_key.compress addr) port
  with
  | Ok (Some n) -> Ok n
  | Ok None -> Error "No account found at that public_key"
  | Error e -> Error (Error.to_string_hum e)

let get_nonce_cmd =
  let open Command.Param in
  let address_flag =
    flag "address" ~doc:"PUBLICKEY Public-key address you want the nonce for"
      (required Cli_lib.Arg_type.public_key)
  in
  Command.async ~summary:"Get the current nonce for an account"
    (Cli_lib.Background_daemon.init address_flag ~f:(fun port address ->
         match%bind get_nonce address port with
         | Error e ->
             eprintf "Failed to get nonce: %s\n" e ;
             exit 1
         | Ok nonce ->
             printf "%s\n" (Account.Nonce.to_string nonce) ;
             exit 0 ))

let status =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  Command.async ~summary:"Get running daemon status"
    (Cli_lib.Background_daemon.init Cli_lib.Flag.json ~f:(fun port json ->
         dispatch_pretty_message ~json
           (module Daemon_rpcs.Types.Status)
           Get_status.rpc () port ))

let status_clear_hist =
  let open Deferred.Let_syntax in
  let open Daemon_rpcs in
  Command.async ~summary:"Clear histograms reported in status"
    (Cli_lib.Background_daemon.init Cli_lib.Flag.json ~f:(fun port json ->
         dispatch_pretty_message ~json
           (module Daemon_rpcs.Types.Status)
           Clear_hist_status.rpc () port ))

let get_nonce_exn public_key port =
  match%bind get_nonce public_key port with
  | Error e ->
      eprintf "Failed to get nonce %s\n" e ;
      exit 1
  | Ok nonce -> return nonce

let handle_exception_nicely (type a) (f : unit -> a Deferred.t) () :
    a Deferred.t =
  match%bind Deferred.Or_error.try_with ~extract_exn:true f with
  | Ok e -> return e
  | Error e ->
      eprintf "Error: %s" (Error.to_string_hum e) ;
      exit 1

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
    | Ok x -> return x
    | Error e ->
        let sample_info () : Payment_info.t =
          let keypair = Keypair.create () in
          { Payment_info.receiver=
              Public_key.(Compressed.to_base64 (compress keypair.public_key))
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
        exit 1
  in
  let main port (privkey_path, payments_path) =
    let open Deferred.Let_syntax in
    let%bind keypair = Cli_lib.Keypair.Terminal_stdin.read_exn privkey_path
    and infos = get_infos payments_path in
    let%bind nonce0 = get_nonce_exn keypair.public_key port in
    let _, ts =
      List.fold_map ~init:nonce0 infos ~f:(fun nonce {receiver; amount; fee} ->
          ( Account.Nonce.succ nonce
          , User_command.sign keypair
              (User_command_payload.create ~fee ~nonce
                 ~memo:User_command_memo.dummy
                 ~body:
                   (Payment
                      { receiver= Public_key.Compressed.of_base64_exn receiver
                      ; amount })) ) )
    in
    dispatch_with_message Daemon_rpcs.Send_user_commands.rpc
      (ts :> User_command.t list)
      port
      ~success:(fun () -> "Successfully enqueued payments in pool")
      ~error:(fun e ->
        sprintf "Failed to send payments %s" (Error.to_string_hum e) )
  in
  Command.async ~summary:"send multiple payments from a file"
    (Cli_lib.Background_daemon.init
       (Args.zip2 Cli_lib.Flag.privkey_read_path payment_path_flag)
       ~f:main)

let user_command (body_args : User_command_payload.Body.t Command.Param.t)
    ~label ~summary ~error =
  let open Command.Param in
  let open Cli_lib.Arg_type in
  let amount_flag =
    flag "fee" ~doc:"VALUE  fee you're willing to pay (default: 1)"
      (optional txn_fee)
  in
  let flag =
    let open Command.Param in
    return (fun a b c -> (a, b, c))
    <*> body_args <*> Cli_lib.Flag.privkey_read_path <*> amount_flag
  in
  Command.async ~summary
    (Cli_lib.Background_daemon.init flag
       ~f:(fun port (body, from_account, fee) ->
         let open Deferred.Let_syntax in
         let%bind sender_kp =
           Cli_lib.Keypair.Terminal_stdin.read_exn from_account
         in
         let%bind nonce = get_nonce_exn sender_kp.public_key port in
         let fee = Option.value ~default:(Currency.Fee.of_int 1) fee in
         let payload : User_command.Payload.t =
           User_command.Payload.create ~fee ~nonce
             ~memo:User_command_memo.dummy ~body
         in
         let payment = User_command.sign sender_kp payload in
         dispatch_with_message Daemon_rpcs.Send_user_command.rpc
           (payment :> User_command.t)
           port
           ~success:(fun receipt_chain_hash ->
             sprintf "Successfully enqueued %s in pool\nReceipt_chain_hash: %s"
               label
               (Receipt.Chain_hash.to_string receipt_chain_hash) )
           ~error:(fun e -> sprintf "%s: %s" error (Error.to_string_hum e)) ))

let send_payment =
  let body =
    let open Command.Let_syntax in
    let open Cli_lib.Arg_type in
    let%map_open receiver =
      flag "receiver"
        ~doc:"PUBLICKEY Public-key address to which you want to send money"
        (required public_key_compressed)
    and amount =
      flag "amount" ~doc:"VALUE Payment amount you want to send"
        (required txn_amount)
    in
    User_command_payload.Body.Payment {receiver; amount}
  in
  user_command body ~label:"payment" ~summary:"Send payment to an address"
    ~error:"Failed to send payment"

let delegate_stake =
  let body =
    let open Command.Let_syntax in
    let open Cli_lib.Arg_type in
    let%map_open new_delegate =
      flag "delegate"
        ~doc:"PUBLICKEY Public-key address you want to set as your delegate"
        (required public_key_compressed)
    in
    User_command_payload.Body.Stake_delegation (Set_delegate {new_delegate})
  in
  user_command body ~label:"stake delegation"
    ~summary:"Set your proof-of-stake delegate" ~error:"Failed to set delegate"

let wrap_key =
  Command.async ~summary:"Wrap a private key into a private key file"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_write_path in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let%bind privkey =
      Cli_lib.Password.hidden_line_or_env "Private key: " ~env:"CODA_PRIVKEY"
    in
    let pk =
      Private_key.of_base64_exn (privkey |> Or_error.ok_exn |> Bytes.to_string)
    in
    let kp = Keypair.of_private_key_exn pk in
    Cli_lib.Keypair.Terminal_stdin.write_exn kp ~privkey_path)

let dump_keypair =
  Command.async ~summary:"Print out a keypair from a private key file"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_read_path in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let%map kp =
      Cli_lib.Keypair.read_exn ~privkey_path
        ~password:
          (lazy (Cli_lib.Password.read "Password for private key file: "))
    in
    printf "Public key: %s\nPrivate key: %s\n"
      (kp.public_key |> Public_key.compress |> Public_key.Compressed.to_base64)
      (kp.private_key |> Private_key.to_base64))

let generate_keypair =
  Command.async ~summary:"Generate a new public-key/private-key pair"
    (let open Command.Let_syntax in
    let%map_open privkey_path = Cli_lib.Flag.privkey_write_path in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let kp = Keypair.create () in
    let%bind () = Cli_lib.Keypair.Terminal_stdin.write_exn kp ~privkey_path in
    printf "Public key: %s\n"
      (kp.public_key |> Public_key.compress |> Public_key.Compressed.to_base64) ;
    exit 0)

let dump_ledger =
  let lb_hash =
    let open Command.Param in
    let h =
      Arg_type.create (fun s ->
          Sexp.of_string_conv_exn s Ledger_builder_hash.Stable.V1.t_of_sexp )
    in
    anon ("ledger-builder-hash" %: h)
  in
  Command.async ~summary:"Print the ledger with given merkle root as a sexp"
    (Cli_lib.Background_daemon.init lb_hash ~f:(fun port lb_hash ->
         dispatch Daemon_rpcs.Get_ledger.rpc lb_hash port
         >>| function
         | Error e -> eprintf !"Error: %{sexp:Error.t}\n" e
         | Ok (Error e) -> printf !"Ledger not found: %{sexp:Error.t}\n" e
         | Ok (Ok accounts) -> printf !"%{sexp:Account.t list}\n" accounts ))

let constraint_system_digests =
  Command.async ~summary:"Print the md5 digest of each SNARK constraint system"
    (Command.Param.return (fun () ->
         let all =
           Transaction_snark.constraint_system_digests ()
           @ Blockchain_snark.Blockchain_transition.constraint_system_digests
               ()
         in
         let all =
           List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) all
         in
         List.iter all ~f:(fun (k, v) -> printf "%s\t%s\n" k (Md5.to_hex v)) ;
         Deferred.unit ))

let command =
  Command.group ~summary:"Lightweight client process"
    [ ("get-balance", get_balance)
    ; ("get-public-keys", get_public_keys)
    ; ("prove-payment", prove_payment)
    ; ("get-nonce", get_nonce_cmd)
    ; ("send-payment", send_payment)
    ; ("stop-daemon", stop_daemon)
    ; ("batch-send-payments", batch_send_payments)
    ; ("status", status)
    ; ("status-clear-hist", status_clear_hist)
    ; ("wrap-key", wrap_key)
    ; ("dump-keypair", dump_keypair)
    ; ("dump-ledger", dump_ledger)
    ; ("constraint-system-digests", constraint_system_digests)
    ; ("generate-keypair", generate_keypair) ]
