open Core_kernel
open Mina_base
open Signature_lib

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

type 'a request =
  { version : int
  ; data : 'a
  ; signature : Signature.t
  ; submitter : Public_key.t
  }
[@@deriving to_yojson]

(* Should be the superset of all the fields required by all payload versions *)
type block_data_common =
  { block : string
  ; created_at : string
  ; peer_id : string
  ; snark_work : string option
  ; graphql_control_port : int option
  ; built_with_commit_sha : string
  }

let create_request version block_data_common_to_v block_data_to_yojson
    block_data_common submitter_keypair =
  let block_data = block_data_common_to_v block_data_common in
  let block_data_json = block_data_to_yojson block_data in
  let block_data_string = Yojson.Safe.to_string block_data_json in
  let signature =
    sign_blake2_hash ~private_key:submitter_keypair.Keypair.private_key
      block_data_string
  in
  { version
  ; data = block_data
  ; signature
  ; submitter = submitter_keypair.public_key
  }

module type S = sig
  val version : int

  type block_data [@@deriving to_yojson]

  val create_request : block_data_common -> Keypair.t -> block_data request
end

module Make_V (M : sig
  val version : int

  type block_data [@@deriving to_yojson]

  val block_data_common_to_v : block_data_common -> block_data
end) =
struct
  let version = M.version

  type block_data = M.block_data [@@deriving to_yojson]

  let create_request =
    create_request version M.block_data_common_to_v block_data_to_yojson
end

module V0 = struct
  module T = struct
    let version = 0

    type block_data =
      { block : string
      ; created_at : string
      ; peer_id : string
      ; snark_work : string option [@default None]
      ; graphql_control_port : int option [@default None]
      }
    [@@deriving to_yojson]

    let block_data_common_to_v (b : block_data_common) =
      { block = b.block
      ; created_at = b.created_at
      ; peer_id = b.peer_id
      ; snark_work = b.snark_work
      ; graphql_control_port = b.graphql_control_port
      }
  end

  include Make_V (T)
end

module V1 = struct
  module T = struct
    let version = 1

    type block_data =
      { block : string
      ; created_at : string
      ; peer_id : string
      ; snark_work : string option [@default None]
      ; graphql_control_port : int option [@default None]
      ; built_with_commit_sha : string
      }
    [@@deriving to_yojson]

    let block_data_common_to_v (b : block_data_common) =
      { block = b.block
      ; created_at = b.created_at
      ; peer_id = b.peer_id
      ; snark_work = b.snark_work
      ; graphql_control_port = b.graphql_control_port
      ; built_with_commit_sha = b.built_with_commit_sha
      }
  end

  include Make_V (T)
end
