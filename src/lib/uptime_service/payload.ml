open Core_kernel
open Mina_base
open Signature_lib

let payload_version = 1

type block_data =
  { block : string
  ; created_at : string
  ; peer_id : string
  ; snark_work : string option [@default None]
  ; graphql_control_port : int option [@default None]
  ; built_with_commit_sha : string option [@default None]
  }
[@@deriving to_yojson]

type request =
  { payload_version : int
  ; data : block_data
  ; signature : Signature.t
  ; submitter : Public_key.t
  }
[@@deriving to_yojson]

let sign_blake2_hash ~private_key s =
  let module Field = Snark_params.Tick.Field in
  let blake2 = Blake2.digest_string s in
  let field_elements = [||] in
  let bitstrings =
    [| Blake2.to_raw_string blake2 |> Blake2.string_to_bits |> Array.to_list |]
  in
  let input : (Field.t, bool) Random_oracle.Legacy.Input.t =
    { field_elements; bitstrings }
  in
  Schnorr.Legacy.sign private_key input

let create_request block_data submitter_keypair =
  let block_data_json = block_data_to_yojson block_data in
  let block_data_string = Yojson.Safe.to_string block_data_json in
  let signature =
    sign_blake2_hash ~private_key:submitter_keypair.Keypair.private_key
      block_data_string
  in
  { payload_version
  ; data = block_data
  ; signature
  ; submitter = submitter_keypair.public_key
  }
