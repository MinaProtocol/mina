open Core
open Async
open Cli_lib
open Signature_lib
open Coda_base

let of_local_port port = Host_and_port.create ~host:"127.0.0.1" ~port

let dispatch rpc query port =
  Tcp.with_connection
    (Tcp.Where_to_connect.of_host_and_port (of_local_port port))
    ~timeout:(Time.Span.of_sec 1.)
    (fun _ r w ->
      let open Deferred.Let_syntax in
      match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
      | Error exn -> return (Or_error.of_exn exn)
      | Ok conn -> Rpc.Rpc.dispatch rpc conn query )

let json_flag =
  Command.Param.(
    flag "json" no_arg ~doc:"Use json output (default: plaintext)")

module Daemon_cli = struct
  module Flag = struct
    open Command.Param

    let port =
      flag "daemon-port"
        ~doc:
          (Printf.sprintf
             "PORT Client to daemon local communication (default: %d)"
             default_client_port)
        (optional int16)
  end

  type state = Start | Run_client | Abort | No_daemon

  let reader = Reader.stdin

  let does_daemon_exist port =
    let open Deferred.Let_syntax in
    let%map result =
      Rpc.Connection.client
        (Tcp.Where_to_connect.of_host_and_port (of_local_port port))
    in
    Result.is_ok result

  let kill p =
    Process.run_exn () ~prog:"kill" ~args:[Pid.to_string @@ Process.pid p]

  let timeout = Time.Span.of_sec 10.0

  let heartbeat = Time.Span.of_sec 0.5

  let invoke_daemon port =
    let rec check_daemon () =
      let%bind result = does_daemon_exist port in
      if result then Deferred.unit
      else
        let%bind () = Async.after heartbeat in
        check_daemon ()
    in
    let our_binary = Sys.executable_name in
    let args = ["daemon"; "-background"; "-client-port"; sprintf "%d" port] in
    let%bind p = Process.create_exn () ~prog:our_binary ~args in
    (* Wait for process to start the client server *)
    match%bind Async.Clock.with_timeout timeout (check_daemon ()) with
    | `Result _ -> Deferred.unit
    | `Timeout ->
        let%bind _ = kill p in
        failwith "Cannot connect to daemon"

  let run ~f port arg =
    let port = Option.value port ~default:default_client_port in
    let rec go = function
      | Start ->
          let%bind has_daemon = does_daemon_exist port in
          if has_daemon then go Run_client else go No_daemon
      | No_daemon ->
          Print.printf !"Error: daemon not running. See `coda daemon`\n" ;
          go Abort
      | Run_client -> f port arg
      | Abort -> Deferred.unit
    in
    go Start

  let init ~f arg_flag =
    let open Command.Param.Applicative_infix in
    Command.Param.return (fun port arg () -> run ~f port arg)
    <*> Flag.port <*> arg_flag
end

let get_balance =
  let open Command.Param in
  let open Deferred.Let_syntax in
  let address_flag =
    flag "address"
      ~doc:
        "PUBLICKEY Public-key address of which you want to check the balance"
      (required public_key)
  in
  Command.async ~summary:"Get balance associated with an address"
    (Daemon_cli.init address_flag ~f:(fun port address ->
         match%map
           dispatch Client_lib.Get_balance.rpc
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
  let open Client_lib in
  let open Command.Param in
  let with_balances_flag =
    flag "with-balances" no_arg
      ~doc:"Show corresponding balances to public keys"
  in
  Command.async ~summary:"Get public keys"
    (Daemon_cli.init
       (return (fun a b -> (a, b)) <*> with_balances_flag <*> json_flag)
       ~f:(fun port (is_balance_included, json) ->
         if is_balance_included then
           dispatch Get_public_keys_with_balances.rpc () port
           >>| print (module Public_key_with_balances) json
         else
           dispatch Get_public_keys.rpc () port
           >>| print (module String_list_formatter) json ))

let get_nonce addr port =
  let open Deferred.Let_syntax in
  match%map
    dispatch Client_lib.Get_nonce.rpc (Public_key.compress addr) port
  with
  | Ok (Some n) -> Ok n
  | Ok None -> Error "No account found at that public_key"
  | Error e -> Error (Error.to_string_hum e)

let get_nonce_cmd =
  let open Command.Param in
  let address_flag =
    flag "address" ~doc:"PUBLICKEY Public-key address you want the nonce for"
      (required public_key)
  in
  Command.async ~summary:"Get the current nonce for an account"
    (Daemon_cli.init address_flag ~f:(fun port address ->
         match%bind get_nonce address port with
         | Error e ->
             eprintf "Failed to get nonce: %s\n" e ;
             exit 1
         | Ok nonce ->
             printf "%s\n" (Account.Nonce.to_string nonce) ;
             exit 0 ))

let status =
  let open Deferred.Let_syntax in
  let open Client_lib in
  Command.async ~summary:"Get running daemon status"
    (Daemon_cli.init json_flag ~f:(fun port json ->
         dispatch Get_status.rpc () port >>| print (module Status) json ))

let status_clear_hist =
  let open Deferred.Let_syntax in
  let open Client_lib in
  Command.async ~summary:"Clear histograms reported in status"
    (Daemon_cli.init json_flag ~f:(fun port json ->
         dispatch Clear_hist_status.rpc () port >>| print (module Status) json
     ))

let rec prompt_password prompt =
  let open Deferred.Or_error.Let_syntax in
  let%bind pw1 = read_password_exn prompt in
  let%bind pw2 = read_password_exn "Again to confirm: " in
  if not (Bytes.equal pw1 pw2) then (
    eprintf "Error: passwords don't match, try again\n" ;
    prompt_password prompt )
  else return pw2

let privkey_path_flag =
  let open Command.Param in
  flag "privkey-path"
    ~doc:"FILE File to write private key into (public key will be FILE.pub)"
    (required file)

let privkey_read_path_flag =
  let open Command.Param in
  flag "privkey-path" ~doc:"FILE File to read private key from" (required file)

let get_nonce_exn public_key port =
  match%bind get_nonce public_key port with
  | Error e ->
      eprintf "Failed to get nonce %s\n" e ;
      exit 1
  | Ok nonce -> return nonce

let dispatch_with_message rpc arg port ~success ~error =
  match%bind dispatch rpc arg port with
  | Ok x ->
      printf "%s\n" (success x) ;
      Deferred.unit
  | Error e ->
      eprintf "%s\n" (error e) ;
      exit 1

let handle_exception_nicely (type a) (f : unit -> a Deferred.t) () :
    a Deferred.t =
  match%bind Deferred.Or_error.try_with ~extract_exn:true f with
  | Ok e -> return e
  | Error e ->
      eprintf "Error: %s" (Error.to_string_hum e) ;
      exit 1

let read_keypair path =
  handle_exception_nicely
    (fun () ->
      read_keypair_exn ~privkey_path:path
        ~password:(lazy (read_password_exn "Secret key password: ")) )
    ()

let batch_send_payments =
  let module Payment_info = struct
    type t = {receiver: string; amount: Currency.Amount.t; fee: Currency.Fee.t}
    [@@deriving sexp]
  end in
  let arg =
    let open Command.Let_syntax in
    let%map_open privkey_path = privkey_read_path_flag
    and payments_path = anon ("payments-file" %: string) in
    (privkey_path, payments_path)
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
    let%bind keypair = read_keypair_exn' privkey_path
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
    dispatch_with_message Client_lib.Send_user_commands.rpc
      (ts :> User_command.t list)
      port
      ~success:(fun () -> "Successfully enqueued payments in pool")
      ~error:(fun e ->
        sprintf "Failed to send payments %s" (Error.to_string_hum e) )
  in
  Command.async ~summary:"send multiple payments from a file"
    (Daemon_cli.init arg ~f:main)

let send_payment =
  let open Command.Param in
  let address_flag =
    flag "receiver"
      ~doc:"PUBLICKEY Public-key address to which you want to send money"
      (required public_key)
  in
  let fee_flag =
    flag "fee" ~doc:"VALUE  Payment fee you're willing to pay (default: 1)"
      (optional txn_fee)
  in
  let amount_flag =
    flag "amount" ~doc:"VALUE Payment amount you want to send"
      (required txn_amount)
  in
  let flag =
    let open Command.Param in
    return (fun a b c d -> (a, b, c, d))
    <*> address_flag <*> privkey_read_path_flag <*> fee_flag <*> amount_flag
  in
  Command.async ~summary:"Send payment to an address"
    (Daemon_cli.init flag ~f:(fun port (address, from_account, fee, amount) ->
         let open Deferred.Let_syntax in
         let%bind sender_kp = read_keypair_exn' from_account in
         let%bind nonce = get_nonce_exn sender_kp.public_key port in
         let receiver_compressed = Public_key.compress address in
         let fee = Option.value ~default:(Currency.Fee.of_int 1) fee in
         let payload : User_command.Payload.t =
           User_command.Payload.create ~fee ~nonce
             ~memo:User_command_memo.dummy
             ~body:(Payment {receiver= receiver_compressed; amount})
         in
         let txn = User_command.sign sender_kp payload in
         dispatch_with_message Client_lib.Send_user_commands.rpc
           [(txn :> User_command.t)]
           port
           ~success:(fun () -> "Successfully enqueued payment in pool")
           ~error:(fun e ->
             sprintf "Failed to send payment %s" (Error.to_string_hum e) ) ))

let wrap_key =
  Command.async ~summary:"Wrap a private key into a private key file"
    (let open Command.Let_syntax in
    let%map_open privkey_path = privkey_path_flag in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let%bind privkey =
      hidden_line_or_env "Private key: " ~env:"CODA_PRIVKEY"
    in
    let pk =
      Private_key.of_base64_exn (privkey |> Or_error.ok_exn |> Bytes.to_string)
    in
    let kp = Keypair.of_private_key_exn pk in
    write_keypair_exn kp ~privkey_path
      ~password:(lazy (prompt_password "Password for new private key file: ")))

let dump_keypair =
  Command.async ~summary:"Print out a keypair from a private key file"
    (let open Command.Let_syntax in
    let%map_open privkey_path = privkey_read_path_flag in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let%map kp =
      read_keypair_exn ~privkey_path
        ~password:(lazy (read_password_exn "Password for private key file: "))
    in
    printf "Public key: %s\nPrivate key: %s\n"
      (kp.public_key |> Public_key.compress |> Public_key.Compressed.to_base64)
      (kp.private_key |> Private_key.to_base64))

let generate_keypair =
  Command.async ~summary:"Generate a new public-key/private-key pair"
    (let open Command.Let_syntax in
    let%map_open privkey_path = privkey_path_flag in
    handle_exception_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let kp = Keypair.create () in
    let%bind () =
      write_keypair_exn kp ~privkey_path
        ~password:(lazy (prompt_password "Password for new private key file: "))
    in
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
    (Daemon_cli.init lb_hash ~f:(fun port lb_hash ->
         dispatch Client_lib.Get_ledger.rpc lb_hash port
         >>| function
         | Error e -> eprintf !"Error: %{sexp:Error.t}\n" e
         | Ok (Error e) -> printf !"Ledger not found: %{sexp:Error.t}\n" e
         | Ok (Ok ledger) -> printf !"%{sexp:Ledger.t}\n" ledger ))

let command =
  Command.group ~summary:"Lightweight client process"
    [ ("get-balance", get_balance)
    ; ("get-public-keys", get_public_keys)
    ; ("get-nonce", get_nonce_cmd)
    ; ("send-payment", send_payment)
    ; ("batch-send-payments", batch_send_payments)
    ; ("status", status)
    ; ("status-clear-hist", status_clear_hist)
    ; ("wrap-key", wrap_key)
    ; ("dump-keypair", dump_keypair)
    ; ("dump-ledger", dump_ledger)
    ; ("generate-keypair", generate_keypair) ]
