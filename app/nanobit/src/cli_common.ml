open Core

let int16 =
  let max_port = 1 lsl 16 in
  Command.Arg_type.map Command.Param.int ~f:(fun x ->
    if 0 <= x && x < max_port
    then x
    else failwithf "Port not between 0 and %d" max_port ())

let public_key =
  let open Nanobit_base in
  Command.Arg_type.map Command.Param.string ~f:(fun s ->
    let public_key_maybe =
      s |> B64.decode
        |> Bigstring.of_string
        |> Public_key.of_bigstring
    in
    match public_key_maybe with
    | Ok key -> key
    | Error e ->
        failwithf "Couldn't read public key %s -- here's a sample one: %s"
          (Error.to_string_hum e)
          (
            let kp = Signature_keypair.create () in
            kp.public_key |> Public_key.to_bigstring |> Bigstring.to_string |> B64.encode
          )
          ()
  )

let txn_fee =
  let open Nanobit_base in
  Command.Arg_type.map Command.Param.string ~f:Currency.Fee.of_string

let txn_amount =
  let open Nanobit_base in
  Command.Arg_type.map Command.Param.string ~f:Currency.Amount.of_string

