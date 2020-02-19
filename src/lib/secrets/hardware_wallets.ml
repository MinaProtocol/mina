open Snark_params
open Core
open Signature_lib
open Coda_base
open Async

let hardware_wallet_script = "codaledgercli"

let to_bigint : string -> Bigint.t =
 fun field ->
  Bytes.of_string field
  |> B58.decode Base58_check.coda_alphabet
  |> Bytes.to_list |> List.rev |> Bytes.of_char_list |> Bytes.to_string
  |> String.foldi ~init:Bigint.zero ~f:(fun i acc byte ->
         Bigint.(acc lor (of_int (Char.to_int byte) lsl Int.( * ) 8 i)) )

let decode_field : string -> Snark_params.Tick.Field.t =
 fun field ->
  to_bigint field |> Tick.Bigint.of_bignum_bigint |> Tick.Bigint.to_field

let decode_scalar : string -> Snark_params.Tock.Field.t =
 fun scalar ->
  to_bigint scalar |> Tock.Bigint.of_bignum_bigint |> Tock.Bigint.to_field

type public_key = {status: string; x: string; y: string} [@@deriving yojson]

let decode_status_code ~f = function
  | "Ok" ->
      Ok (f ())
  | "Hardware_wallet_not_found" ->
      Error "Hardware wallet not found."
  | "Computation_aborted" ->
      Error "An internal error happens in hardware wallet."
  | s ->
      Error (sprintf !"Unknown status code returned by hardware wallet: %s" s)

let report_json_error s =
  sprintf !"Failed to parse the json returned by hardware wallet: %s" s

let report_process_error e =
  sprintf
    !"Failed to communicate with hardware wallet program %s: %s"
    hardware_wallet_script (Error.to_string_hum e)

let decode_public_key : string -> (Public_key.t, string) Result.t =
 fun public_key ->
  Yojson.Safe.from_string public_key
  |> public_key_of_yojson
  |> Result.map_error ~f:report_json_error
  |> Result.bind ~f:(fun {status; x; y} ->
         decode_status_code status ~f:(fun () ->
             (decode_field x, decode_field y) ) )

type signature = {status: string; field: string; scalar: string}
[@@deriving yojson]

let decode_signature : string -> (Signature.t, string) Result.t =
 fun signature ->
  Yojson.Safe.from_string signature
  |> signature_of_yojson
  |> Result.map_error ~f:report_json_error
  |> Result.bind ~f:(fun {status; field; scalar} ->
         decode_status_code status ~f:(fun () ->
             (decode_field field, decode_scalar scalar) ) )

let compute_public_key ~hardware_wallet_nonce =
  let prog, args =
    ( "python3"
    , [ "-m" ^ hardware_wallet_script
      ; "--request=publickey"
      ; "--nonce="
        ^ Coda_numbers.Hardware_wallet_nonce.to_string hardware_wallet_nonce ]
    )
  in
  Process.run ~prog ~args ()
  |> Deferred.Result.map_error ~f:report_process_error
  |> Deferred.map ~f:(Result.bind ~f:decode_public_key)

let sign ~hardware_wallet_nonce ~public_key ~user_command_payload =
  let open Deferred.Result.Let_syntax in
  let input =
    Transaction_union_payload.to_input
    @@ Transaction_union_payload.of_user_command_payload user_command_payload
  in
  let fields = Random_oracle.pack_input input in
  let messages =
    Array.map fields ~f:(fun field -> Tick.Field.to_string field)
  in
  if Array.length messages <> 2 then
    Deferred.Result.fail "Malformed user command"
  else
    let prog, args =
      ( "python3"
      , [ "-m" ^ hardware_wallet_script
        ; "--request=sign"
        ; "--msgx=" ^ messages.(0)
        ; "--msgm=" ^ messages.(1)
        ; "--nonce="
          ^ Coda_numbers.Hardware_wallet_nonce.to_string hardware_wallet_nonce
        ] )
    in
    let%bind signature_str =
      Process.run ~prog ~args ()
      |> Deferred.Result.map_error ~f:report_process_error
    in
    let%bind signature = decode_signature signature_str |> Deferred.return in
    if
      Coda_base.Schnorr.verify signature
        (Tick.Inner_curve.of_affine public_key)
        user_command_payload
    then
      return
        Coda_base.User_command.Poly.
          {payload= user_command_payload; sender= public_key; signature}
    else
      let%bind computed_public_key =
        compute_public_key ~hardware_wallet_nonce
      in
      if Public_key.equal computed_public_key public_key then
        Deferred.Result.fail
          "Failed to verify signature returned by hardware wallet."
      else
        Deferred.Result.fail
          "The cached public doesn't match the one that is computed by the \
           hardware wallet. Possible reason could be you are using a \
           different hardware wallet or you reinitialized your hardware \
           wallet using a different seed. If you want to use your new ledger, \
           please first create an account by 'coda account \
           create-hardware-wallet' command"

let write_exn ~hardware_wallet_nonce ~nonce_path : unit Deferred.t =
  let%bind nonce_file = Writer.open_file nonce_path in
  Writer.write_line nonce_file
    (Coda_numbers.Hardware_wallet_nonce.to_string hardware_wallet_nonce) ;
  Writer.close nonce_file
