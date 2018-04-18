open Core

let int16 =
  let max_port = 1 lsl 16 in
  Command.Arg_type.map Command.Param.int ~f:(fun x ->
    if 0 <= x && x < max_port
    then x
    else failwithf "Port not between 0 and %d" max_port ())

module Key_command (Key : sig
  type t
  val name : string
  val of_bigstring : Bigstring.t -> t Or_error.t
  val to_bigstring : t -> Bigstring.t
  val project : Nanobit_base.Signature_keypair.t -> t
end) =
  struct
    let key =
      let open Nanobit_base in
      Command.Arg_type.map Command.Param.string ~f:(fun s ->
        let key_maybe =
          s |> B64.decode
            |> Bigstring.of_string
            |> Key.of_bigstring
        in
        match key_maybe with
        | Ok key -> key
        | Error e ->
            failwithf "Couldn't read %s %s -- here's a sample one: %s"
              Key.name
              (Error.to_string_hum e)
              (
                let kp = Signature_keypair.create () in
                (Key.project kp) |> Key.to_bigstring |> Bigstring.to_string |> B64.encode
              )
              ()
      )
  end

let public_key =
  let module Pk = Key_command(struct
    include Nanobit_base.Public_key
    let name = "public key"
    let project (kp : Nanobit_base.Signature_keypair.t) = kp.public_key
  end) in
  Pk.key

let private_key =
  let module Sk = Key_command(struct
    include Nanobit_base.Private_key
    let name = "private key"
    let project (kp : Nanobit_base.Signature_keypair.t) = kp.private_key
  end) in
  Sk.key

let txn_fee =
  let open Nanobit_base in
  Command.Arg_type.map Command.Param.string ~f:Currency.Fee.of_string

let txn_amount =
  let open Nanobit_base in
  Command.Arg_type.map Command.Param.string ~f:Currency.Amount.of_string

