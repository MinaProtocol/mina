open Core
open Command.Param
open Command.Arg_type
open Coda_base
open Signature_lib
module Consensus_time = Consensus.Data.Consensus_time

let unwrap_cli_error cli_arg res =
  match res with
  | Ok x ->
      x
  | Error err ->
      failwithf "CLI PARSING ERROR: failed to parse %s -- %s" cli_arg
        (Error.to_string_hum err) ()

let validate_int16 x =
  let max_port = 1 lsl 16 in
  if 0 <= x && x < max_port then Ok x
  else Or_error.errorf !"Port not between 0 and %d" max_port

let int16 = map int ~f:(Fn.compose Or_error.ok_exn validate_int16)

module Key_arg_type (Key : sig
  type t

  val of_base58_check_exn : string -> t

  val to_base58_check : t -> string

  val name : string

  val random : unit -> t
end) =
struct
  let arg_type =
    create (fun s ->
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
  map public_key_compressed ~f:(fun pk ->
      match Public_key.decompress pk with
      | None ->
          failwith "Invalid key"
      | Some pk' ->
          pk' )

let receipt_chain_hash = map string ~f:Coda_base.Receipt.Chain_hash.of_string

let peer : Host_and_port.t t = create (fun s -> Host_and_port.of_string s)

let consensus_time_raw = map int ~f:Consensus_time.of_int

let consensus_time_unix cli_arg =
  (* this implementation of [slot_of_unix_time] is good until 12/20/2286 *)
  let slot_of_unix_time time_input =
    (* it's suprising that core doesn't have this function already *)
    let rec num_digits ?(digits = 0) n =
      if n / 10 = 0 then if n = 0 then digits else digits + 1
      else num_digits ~digits:(digits + 1) (n / 10)
    in
    let ms_since_epoch =
      match num_digits time_input with
      | 10 ->
          1000 * time_input
      | 13 ->
          time_input
      | _ ->
          failwith "invalid unix timestamp"
    in
    Consensus_time.of_time
      Block_time.(
        Int64.of_int ms_since_epoch
        |> Span.of_ms |> of_span_since_epoch
        |> normalize (Controller.basic ~logger:(Logger.null ())))
    |> unwrap_cli_error cli_arg
  in
  map int ~f:slot_of_unix_time

let consensus_time_date_time cli_arg =
  let slot_of_date_time str =
    Consensus_time.of_time
      (Block_time.of_time (Time.of_string_gen ~if_no_timezone:`Local str))
    |> unwrap_cli_error cli_arg
  in
  map string ~f:slot_of_date_time

let txn_fee = map string ~f:Currency.Fee.of_string

let txn_amount = map string ~f:Currency.Amount.of_string

let txn_nonce =
  let open Coda_base in
  map string ~f:Account.Nonce.of_string

let hd_index = map string ~f:Coda_numbers.Hd_index.of_string

let ip_address = map string ~f:Unix.Inet_addr.of_string

let log_level =
  map string ~f:(fun log_level_str_with_case ->
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
  create (fun s ->
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

let work_selection_method = map string ~f:work_selection_method_val

let work_selection_method_to_module :
    Work_selection_method.t -> (module Work_selector.Selection_method_intf) =
  function
  | Sequence ->
      (module Work_selector.Selection_methods.Sequence)
  | Random ->
      (module Work_selector.Selection_methods.Random)
