open Core
open Signature_lib

let validate_int16 x =
  let max_port = 1 lsl 16 in
  if 0 <= x && x < max_port then Ok x
  else Or_error.errorf !"Port not between 0 and %d" max_port

let int16 =
  Command.Arg_type.map Command.Param.int
    ~f:(Fn.compose Or_error.ok_exn validate_int16)

module Key_arg_type (Key : sig
  type t

  val of_base58_check_exn : string -> t

  val to_base58_check : t -> string

  val name : string

  val random : unit -> t
end) =
struct
  let arg_type =
    Command.Arg_type.create (fun s ->
        try Key.of_base58_check_exn s
        with e ->
          failwithf
            "Couldn't read %s (Invalid key format) %s -- here's a sample one: \
             %s"
            Key.name
            (Error.to_string_hum (Error.of_exn e))
            (Key.to_base58_check (Key.random ()))
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
      | None ->
          failwith "Invalid key"
      | Some pk' ->
          pk' )

let receipt_chain_hash =
  Command.Arg_type.map Command.Param.string
    ~f:Coda_base.Receipt.Chain_hash.of_string

let peer : Host_and_port.t Command.Arg_type.t =
  Command.Arg_type.create (fun s -> Host_and_port.of_string s)

let global_slot =
  Command.Arg_type.map Command.Param.int ~f:Coda_numbers.Global_slot.of_int

let txn_fee =
  Command.Arg_type.map Command.Param.string ~f:Currency.Fee.of_formatted_string

let txn_amount =
  Command.Arg_type.map Command.Param.string
    ~f:Currency.Amount.of_formatted_string

let txn_nonce =
  let open Coda_base in
  Command.Arg_type.map Command.Param.string ~f:Account.Nonce.of_string

let ip_address =
  Command.Arg_type.map Command.Param.string ~f:Unix.Inet_addr.of_string

let log_level =
  Command.Arg_type.map Command.Param.string ~f:(fun log_level_str_with_case ->
      let open Logger in
      let log_level_str = String.lowercase log_level_str_with_case in
      match Level.of_string log_level_str with
      | Error _ ->
          eprintf "Received unknown log-level %s. Expected one of: %s\n"
            log_level_str
            ( Level.all |> List.map ~f:Level.show
            |> List.map ~f:String.lowercase
            |> String.concat ~sep:", " ) ;
          exit 14
      | Ok ll ->
          ll )

let user_command =
  Command.Arg_type.create (fun s ->
      try Coda_base.User_command.of_base58_check_exn s
      with e ->
        failwithf "Couldn't decode transaction id: %s\n"
          (Error.to_string_hum (Error.of_exn e))
          () )

module Work_selection_method = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Sequence | Random

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = Sequence | Random
end

let work_selection_method_val = function
  | "seq" ->
      Work_selection_method.Sequence
  | "rand" ->
      Random
  | _ ->
      failwith "Invalid work selection"

let work_selection_method =
  Command.Arg_type.map Command.Param.string ~f:work_selection_method_val

let work_selection_method_to_module :
    Work_selection_method.t -> (module Work_selector.Selection_method_intf) =
  function
  | Sequence ->
      (module Work_selector.Selection_methods.Sequence)
  | Random ->
      (module Work_selector.Selection_methods.Random)
