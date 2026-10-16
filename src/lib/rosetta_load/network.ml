(* The networks the load tool can talk to; the name goes into every request's
   network_identifier. *)

open Core_kernel

type t = Devnet | Mainnet

let of_string = function
  | "devnet" ->
      Devnet
  | "mainnet" ->
      Mainnet
  | s ->
      failwithf "unknown network %s (expected devnet or mainnet)" s ()

let to_string = function Devnet -> "devnet" | Mainnet -> "mainnet"

let arg_type = Command.Arg_type.create of_string
