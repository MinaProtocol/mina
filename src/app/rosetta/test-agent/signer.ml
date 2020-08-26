(* A to-spec signer library that uses internal coda libs *)

open Core_kernel
open Signature_lib
open Lib
module Signature = Coda_base.Signature
module User_command = Coda_base.User_command

module Keys = struct
  type t = {keypair: Keypair.t; public_key_hex_bytes: string}

  let of_keypair keypair =
    {keypair; public_key_hex_bytes= Public_key.Hex.encode keypair.public_key}

  let of_private_key_box secret_box_string =
    let json = Yojson.Safe.from_string secret_box_string in
    let which = Secrets.Keypair.T.which in
    let sb : Secrets.Secret_box.t =
      Secrets.Secret_box.of_yojson json |> Result.ok |> Option.value_exn
    in
    let output : Bytes.t =
      Secrets.Secret_box.decrypt ~password:(Bytes.of_string "") ~which sb
      |> Result.ok |> Option.value_exn
    in
    let sk = output |> Bigstring.of_bytes |> Private_key.of_bigstring_exn in
    of_keypair (Keypair.of_private_key_exn sk)
end

(* Returns signed_transaction_string *)
let sign ~(keys : Keys.t) ~unsigned_transaction_string =
  let open Result.Let_syntax in
  let%bind json =
    try return (Yojson.Safe.from_string unsigned_transaction_string)
    with _ -> Result.fail (Errors.create (`Json_parse None))
  in
  let%map unsigned_transaction =
    Transaction.Unsigned.Rendered.of_yojson json
    |> Result.map_error ~f:(fun e -> Errors.create (`Json_parse (Some e)))
    |> Result.bind ~f:Transaction.Unsigned.of_rendered
  in
  let user_command_payload =
    User_command_info.Partial.to_user_command_payload
      ~nonce:unsigned_transaction.nonce
      unsigned_transaction.Transaction.Unsigned.command
    |> Result.ok |> Option.value_exn
  in
  let signature =
    Schnorr.sign keys.keypair.private_key
      unsigned_transaction.random_oracle_input
    |> Signature.Raw.encode
  in
  let signature' =
    User_command.sign_payload keys.keypair.private_key user_command_payload
    |> Signature.Raw.encode
  in
  [%test_eq: string] signature signature' ;
  signature
