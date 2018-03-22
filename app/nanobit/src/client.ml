open Core
open Async
open Cli_common
open Nanobit_base

(* TODO: Fill out this implementations properly *)
let send_txn_impl _ payload =
  printf "Starting keypair create\n";
  let kp = Transaction.Signature.Keypair.create () in
  printf "Ending keypair create\n";
  let _txn : Transaction.t = Transaction.sign kp payload in
  printf "Created a real transaction!\n";
  return ()

let get_balance_impl _ addr =
  return (Balance.Amount.of_unsigned_string "1000")

let init_server ~parent_log ~port =
  let log = Logger.child parent_log "client" in
  let _ =
    Tcp.Server.create
        ~on_handler_error:(`Call (fun net exn -> Logger.error log "%s" (Exn.to_string_mach exn)))
        (Tcp.Where_to_listen.of_port port)
        (fun address reader writer -> 
           Rpc.Connection.server_with_close 
             reader writer
             ~implementations:(Rpc.Implementations.create_exn 
               ~implementations:
                 [ Rpc.Rpc.implement Client_lib.Send_transaction.rpc send_txn_impl
                 ; Rpc.Rpc.implement Client_lib.Get_balance.rpc get_balance_impl
                 ]
               ~on_unknown_rpc:`Raise
             )
             ~connection_state:(fun _ -> ())
             ~on_handshake_error:
               (`Call (fun exn -> 
                  Logger.error log "%s" (Exn.to_string_mach exn);
                Deferred.unit)))
  in ()

let dispatch rpc query port =
  Tcp.with_connection
    (Tcp.Where_to_connect.of_host_and_port (Host_and_port.create ~host:"127.0.0.1" ~port))
    ~timeout:(Time.Span.of_sec 1.)
    (fun _ r w ->
       let open Deferred.Let_syntax in
       match%bind Rpc.Connection.create r w ~connection_state:(fun _ -> ()) with
       | Error exn -> return (Or_error.of_exn exn)
       | Ok conn -> Rpc.Rpc.dispatch rpc conn query)


let get_balance =
  Command.async ~summary:"Get balance associated with an address" begin
    let open Command.Let_syntax in
    let%map_open address =
      flag "address" ~doc:"Public-key address of which you want to see the balance" (required public_key)
    and port =
      flag "daemon-port" ~doc:"Port of the deamon's client-rpc handlers" (required int16)
    in
    fun () ->
      let open Deferred.Let_syntax in
      match%map (dispatch Client_lib.Get_balance.rpc address port) with
      | Ok b -> printf "%s\n" (Balance.Amount.to_string b)
      | Error e -> printf "Failed to send txn %s\n" (Error.to_string_hum e)
  end

let send_txn =
  Command.async ~summary:"Send transaction to an address" begin
    let open Command.Let_syntax in
    begin
    [%map_open
      let address =
        flag "receiver" ~doc:"Public-key address to which you want to send money" (required public_key)
      and fee =
        flag "fee" ~doc:"Transaction fee you're willing to pay" (required txn_fee)
      and amount =
        flag "amount" ~doc:"Transaction amount you want to send" (required txn_amount)
      and port =
        flag "daemon-port" ~doc:"Port of the deamon's client-rpc handlers" (required int16)
      in
      fun () -> 
        let open Deferred.Let_syntax in
        let receiver_compressed = Public_key.compress address in
        let payload : Transaction.Payload.t =
          { receiver = receiver_compressed
          ; amount
          ; fee
          }
        in
        match%map (dispatch Client_lib.Send_transaction.rpc payload port) with
        | Ok () -> printf "Successfully sent txn\n"
        | Error e -> printf "Failed to send txn %s\n" (Error.to_string_hum e)
    ]
    end
  end

let command =
  Command.group ~summary:"Lightweight client process"
    [ "get-balance", get_balance
    ; "send-txn", send_txn
    ]
