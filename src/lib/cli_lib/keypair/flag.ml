(* flag.ml -- the command-line flags the keypair commands need

   Kept here rather than in Cli_lib.Flag so that the keypair executables do
   not link the daemon's flag surface. Cli_lib.Flag re-exports these. *)

open Core
open Async

let privkey_write_path =
  let open Command.Param in
  flag "--privkey-path" ~aliases:[ "privkey-path" ]
    ~doc:"FILE File to write private key into (public key will be FILE.pub)"
    (required string)

let signature_kind =
  let open Command.Param in
  let arg_type =
    Command.Arg_type.create (fun s ->
        match String.lowercase s with
        | "mainnet" ->
            Mina_signature_kind.Mainnet
        | "testnet" ->
            Mina_signature_kind.Testnet
        | other ->
            Mina_signature_kind.Other_network other )
  in
  flag "--signature-kind"
    ~doc:
      "mainnet|testnet|<other> Signature kind to use (default: value compiled \
       into this binary)"
    (optional_with_default Mina_signature_kind.t_DEPRECATED arg_type)
