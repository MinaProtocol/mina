open Core
open Async
open Cli_common

let get_balance =
  Command.async ~summary:"Get balance associated with an address" begin
    let open Command.Let_syntax in
    let%map_open address =
      flag "address" ~doc:"Public-key address" (required public_key)
    in
    fun () -> Deferred.return ()
  end

let send_txn =
  Command.async ~summary:"Send transaction to an address" begin
    let open Command.Let_syntax in
    let%map_open address =
      flag "address" ~doc:"Public-key address" (required public_key)
    (* TODO: Include self-keypair and other transaction things *)
    in
    fun () -> Deferred.return ()
  end

let command =
  Command.group ~summary:"Lightweight client process"
    [ "get-balance", get_balance
    ; "send-txn", send_txn
    ]
