type block_data =
  { block : string
  ; created_at : string
  ; peer_id : string
  ; snark_work : string option
  ; graphql_control_port : int option
  ; built_with_commit_sha : string option
  }
[@@deriving to_yojson]

type request [@@deriving to_yojson]

val create_request : block_data -> Signature_lib.Keypair.t -> request
