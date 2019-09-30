open Core

let json =
  Command.Param.(
    flag "json" no_arg ~doc:"Use json output (default: plaintext)")

let performance =
  Command.Param.(
    flag "performance" no_arg
      ~doc:
        "Include performance histograms in status output (default: don't \
         include)")

let privkey_write_path =
  let open Command.Param in
  flag "privkey-path"
    ~doc:"FILE File to write private key into (public key will be FILE.pub)"
    (required string)

let privkey_read_path =
  let open Command.Param in
  flag "privkey-path" ~doc:"FILE File to read private key from"
    (required string)

let conf_dir =
  let open Command.Param in
  flag "config-directory" ~doc:"DIR Configuration directory" (optional string)

let port =
  Command.Param.flag "daemon-port"
    ~doc:
      (Printf.sprintf "PORT Client to daemon local communication (default: %d)"
         Port.default_client)
    (Command.Param.optional Arg_type.int16)

let rest_port =
  Command.Param.flag "rest-port"
    ~doc:
      (Printf.sprintf "PORT Client to daemon rest server (default: %d)"
         Port.default_rest)
    (Command.Param.optional Arg_type.int16)

type user_command_common =
  { sender: Signature_lib.Public_key.Compressed.t
  ; fee: Currency.Fee.t
  ; nonce: Coda_base.Account.Nonce.t option
  ; memo: string option }

let user_command_common : user_command_common Command.Param.t =
  let open Command.Let_syntax in
  let open Arg_type in
  let%map_open sender =
    flag "sender"
      (required public_key_compressed)
      ~doc:"KEY Public key from which you want to send the transaction"
  and fee =
    flag "fee"
      ~doc:
        (Printf.sprintf
           "FEE Amount you are willing to pay to process the transaction \
            (default: %d)"
           (Currency.Fee.to_int Default.transaction_fee))
      (optional txn_fee)
  and nonce =
    flag "nonce"
      ~doc:
        "NONCE Nonce that you would like to set for your transaction \
         (default: nonce of your account on the best ledger or the successor \
         of highest value nonce of your sent transactions from the \
         transaction pool )"
      (optional txn_nonce)
  and memo =
    flag "memo" ~doc:"STRING Memo accompanying the transaction"
      (optional string)
  in
  {sender; fee= Option.value fee ~default:Default.transaction_fee; nonce; memo}
