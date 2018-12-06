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
          failwithf
            "Couldn't read %s (Invalid key format) %s -- here's a sample one: \
             %s"
            Key.name
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
  Command.Arg_type.map public_key_compressed ~f:(fun pk ->
      match Public_key.decompress pk with
      | None -> failwith "Invalid key"
      | Some pk' -> pk' )

let receipt_chain_hash =
  Command.Arg_type.map Command.Param.string
    ~f:Coda_base.Receipt.Chain_hash.of_string

let peer : Host_and_port.t Command.Arg_type.t =
  Command.Arg_type.create (fun s -> Host_and_port.of_string s)

let txn_fee =
  Command.Arg_type.map Command.Param.string ~f:Currency.Fee.of_string

let txn_amount =
  Command.Arg_type.map Command.Param.string ~f:Currency.Amount.of_string

let txn_nonce =
  let open Coda_base in
  Command.Arg_type.map Command.Param.string ~f:Account.Nonce.of_string

let work_selection_val =
  let open Protocols in
  function
  | "seq" -> Coda_pow.Work_selection.Seq
  | "rand" -> Coda_pow.Work_selection.Random
  | _ -> failwith "Invalid work selection"

let work_selection =
  Command.Arg_type.map Command.Param.string ~f:work_selection_val
