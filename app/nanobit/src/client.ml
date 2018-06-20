open Core
open Async
open Cli_common
open Nanobit_base

module Rpc_server (Main : sig
  type t

  val get_balance :
       t
    -> Public_key.Compressed.Stable.V1.t
    -> Currency.Balance.Stable.V1.t option Deferred.t

  val send_txn : t -> Transaction.Stable.V1.t -> unit option Deferred.t

  val get_nonce :
       t
    -> Public_key.Compressed.Stable.V1.t
    -> Account.Nonce.Stable.V1.t option Deferred.t
end) =
struct
  let init_server ~parent_log ~minibit ~port =
    let log = Logger.child parent_log "client" in
    ignore
      (Tcp.Server.create
         ~on_handler_error:
           (`Call
             (fun net exn -> Logger.error log "%s" (Exn.to_string_mach exn)))
         (Tcp.Where_to_listen.of_port port)
         (fun address reader writer ->
           Rpc.Connection.server_with_close reader writer
             ~implementations:
               (Rpc.Implementations.create_exn
                  ~implementations:
                    [ Rpc.Rpc.implement Client_lib.Send_transaction.rpc
                        (fun _ -> Main.send_txn minibit )
                    ; Rpc.Rpc.implement Client_lib.Get_balance.rpc (fun _ ->
                          Main.get_balance minibit )
                    ; Rpc.Rpc.implement Client_lib.Get_nonce.rpc (fun _ ->
                          Main.get_nonce minibit ) ]
                  ~on_unknown_rpc:`Raise)
             ~connection_state:(fun _ -> ())
             ~on_handshake_error:
               (`Call
                 (fun exn ->
                   Logger.error log "%s" (Exn.to_string_mach exn) ;
                   Deferred.unit )) ))
end

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

let get_balance =
  Command.async ~summary:"Get balance associated with an address"
    (let open Command.Let_syntax in
    let%map_open address =
      flag "address"
        ~doc:"Public-key address of which you want to see the balance"
        (required public_key)
    and port =
      flag "daemon-port" ~doc:"Port of the deamon's client-rpc handlers"
        (required int16)
    in
    fun () ->
      let open Deferred.Let_syntax in
      match%map
        dispatch Client_lib.Get_balance.rpc (Public_key.compress address) port
      with
      | Ok (Some b) -> printf "%s\n" (Currency.Balance.to_string b)
      | Ok None -> printf "No account found at that public_key (zero balance)"
      | Error e -> printf "Failed to send txn %s\n" (Error.to_string_hum e))

let get_nonce addr port =
  let open Deferred.Let_syntax in
  match%map
    dispatch Client_lib.Get_nonce.rpc (Public_key.compress addr) port
  with
  | Ok (Some n) -> Ok n
  | Ok None -> Error "No account found at that public_key"
  | Error e -> Error (Error.to_string_hum e)

let send_txn =
  Command.async ~summary:"Send transaction to an address"
    (let open Command.Let_syntax in
    let%map_open address =
      flag "receiver" ~doc:"Public-key address to which you want to send money"
        (required public_key)
    and from_account =
      flag "from"
        ~doc:"Private-key address from which you would like to send money"
        (required private_key)
    and fee =
      flag "fee" ~doc:"Transaction fee you're willing to pay (default: 1)"
        (optional txn_fee)
    and amount =
      flag "amount" ~doc:"Transaction amount you want to send"
        (required txn_amount)
    and port =
      flag "daemon-port"
        ~doc:
          (Printf.sprintf
             "Port of the deamon's client-rpc handlers (default: %d)"
             default_daemon_port)
        (optional int16)
    in
    fun () ->
      let open Deferred.Let_syntax in
      let receiver_compressed = Public_key.compress address in
      let sender_kp = Signature_keypair.of_private_key from_account in
      let port = Option.value ~default:default_daemon_port port in
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
          | Ok (Some ()) -> printf "Successfully enqueued txn in pool\n"
          | Ok None -> printf "Txn can't be signed properly\n"
          | Error e -> printf "Failed to send txn %s\n" (Error.to_string_hum e))

let command =
  Command.group ~summary:"Lightweight client process"
    [("get-balance", get_balance); ("send-txn", send_txn)]
