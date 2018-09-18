open Core
open Signature_lib

let int16 =
  let max_port = 1 lsl 16 in
  Command.Arg_type.map Command.Param.int ~f:(fun x ->
      if 0 <= x && x < max_port then x
      else failwithf "Port not between 0 and %d" max_port () )

module Key_arg_type (Key : sig
  type t

  val of_base64_exn : string -> t

  val to_base64 : t -> string

  val name : string

  val random : unit -> t
end) =
struct
  let arg_type =
    Command.Arg_type.create (fun s ->
        try Key.of_base64_exn s with e ->
          failwithf "Couldn't read %s %s -- here's a sample one: %s" Key.name
            (Error.to_string_hum (Error.of_exn e))
            (Key.to_base64 (Key.random ()))
            () )
end

let public_key_compressed =
  let module Pk = Key_arg_type (struct
    include Public_key.Compressed

    let name = "public key"

    let random () = Public_key.compress (Keypair.create ()).public_key
  end) in
  Pk.arg_type

let public_key =
  Command.Arg_type.map public_key_compressed ~f:Public_key.decompress_exn

let peer : Host_and_port.t Command.Arg_type.t =
  Command.Arg_type.create (fun s -> Host_and_port.of_string s)

let private_key =
  let module Sk = Key_arg_type (struct
    include Private_key

    let name = "private key"

    let random () = Private_key.create ()
  end) in
  Sk.arg_type

let txn_fee =
  Command.Arg_type.map Command.Param.string ~f:Currency.Fee.of_string

let txn_amount =
  Command.Arg_type.map Command.Param.string ~f:Currency.Amount.of_string

let txn_nonce =
  let open Coda_base in
  Command.Arg_type.map Command.Param.string ~f:Account.Nonce.of_string

let default_client_port = 8301
