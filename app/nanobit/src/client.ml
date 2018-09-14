open Core
open Async
open Cli_lib
open Signature_lib
open Nanobit_base

let dispatch rpc query port =
  Tcp.with_connection
    (Tcp.Where_to_connect.of_host_and_port
       (Host_and_port.create ~host:"127.0.0.1" ~port))
    ~timeout:(Time.Span.of_sec 1.)
    (fun _ r w ->
      let open Deferred.Let_syntax in
      match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
      | Error exn -> return (Or_error.of_exn exn)
      | Ok conn -> Rpc.Rpc.dispatch rpc conn query )

let daemon_port_flag =
  Command.Param.flag "daemon-port"
    ~doc:
      (Printf.sprintf "PORT Client to daemon local communication (default: %d)"
         default_client_port)
    (Command.Param.optional int16)

let json_flag =
  Command.Param.(flag "json" no_arg ~doc:"Use json output (default: plaintext)")

let get_balance =
  Command.async ~summary:"Get balance associated with an address"
    (let open Command.Let_syntax in
    let%map_open address =
      flag "address"
        ~doc:
          "PUBLICKEY Public-key address of which you want to check the balance"
        (required public_key)
    and port = daemon_port_flag in
    fun () ->
      let open Deferred.Let_syntax in
      let port = Option.value ~default:default_client_port port in
      match%map
        dispatch Client_lib.Get_balance.rpc (Public_key.compress address) port
      with
      | Ok (Some b) -> printf "%s\n" (Currency.Balance.to_string b)
      | Ok None ->
          printf "No account found at that public_key (zero balance)\n"
      | Error e -> printf "Failed to send txn %s\n" (Error.to_string_hum e))

let get_public_keys =
  Command.async ~summary:"Get public keys"
    (let open Command.Let_syntax in
    let%map_open json = json_flag and port = daemon_port_flag in
    fun () ->
      let open Deferred.Let_syntax in
      let port = Option.value ~default:default_client_port port in
      let open Client_lib in
      dispatch Get_public_keys.rpc () port >>| print (module Public_key) json)

let get_nonce addr port =
  let open Deferred.Let_syntax in
  match%map
    dispatch Client_lib.Get_nonce.rpc (Public_key.compress addr) port
  with
  | Ok (Some n) -> Ok n
  | Ok None -> Error "No account found at that public_key"
  | Error e -> Error (Error.to_string_hum e)

let status =
  Command.async ~summary:"Get running daemon status"
    (let open Command.Let_syntax in
    let%map_open json = json_flag and port = daemon_port_flag in
    fun () ->
      let open Deferred.Let_syntax in
      let port = Option.value ~default:default_client_port port in
      let open Client_lib in
      dispatch Get_status.rpc () port >>| print (module Status) json)

let send_txn =
  Command.async ~summary:"Send transaction to an address"
    (let open Command.Let_syntax in
    let%map_open address =
      flag "receiver"
        ~doc:"PUBLICKEY Public-key address to which you want to send money"
        (required public_key)
    and from_account =
      flag "from"
        ~doc:
          "PRIVATEKEY Private-key address from which you would like to send \
           money"
        (required private_key)
    and fee =
      flag "fee"
        ~doc:"VALUE  Transaction fee you're willing to pay (default: 1)"
        (optional txn_fee)
    and amount =
      flag "amount" ~doc:"VALUE Transaction amount you want to send"
        (required txn_amount)
    and port = daemon_port_flag in
    fun () ->
      let open Deferred.Let_syntax in
      let receiver_compressed = Public_key.compress address in
      let sender_kp = Keypair.of_private_key_exn from_account in
      let port = Option.value ~default:default_client_port port in
      match%bind get_nonce sender_kp.public_key port with
      | Error e ->
          printf "Failed to get nonce %s\n" e ;
          return ()
      | Ok nonce ->
          let fee = Option.value ~default:(Currency.Fee.of_int 1) fee in
          let payload : Transaction.Payload.t =
            {receiver= receiver_compressed; amount; fee; nonce}
          in
          let txn = Transaction.sign sender_kp payload in
          match%map
            dispatch Client_lib.Send_transaction.rpc
              (txn :> Transaction.t)
              port
          with
          | Ok () -> printf "Successfully enqueued transaction in pool\n"
          | Error e ->
              printf "Failed to send transaction %s\n" (Error.to_string_hum e))

let generate_keypair =
  Command.async ~summary:"Generate a new public-key/private-key pair"
    (Command.Param.return (fun () ->
         let keypair = Keypair.create () in
         printf "public-key: %s\nprivate-key: %s\n"
           (Public_key.Compressed.to_base64
              (Public_key.compress keypair.public_key))
           (Private_key.to_base64 keypair.private_key) ;
         exit 0 ))

let command =
  Command.group ~summary:"Lightweight client process"
    [ ("get-balance", get_balance)
    ; ("get-public-keys", get_public_keys)
    ; ("send-txn", send_txn)
    ; ("status", status)
    ; ("generate-keypair", generate_keypair) ]
