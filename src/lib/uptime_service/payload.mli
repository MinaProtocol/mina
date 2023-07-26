type 'a request =
  { version : int
  ; data : 'a
  ; signature : Mina_base.Signature.t
  ; submitter : Signature_lib.Public_key.t
  }
[@@deriving to_yojson]

type block_data_common =
  { block : string
  ; created_at : string
  ; peer_id : string
  ; snark_work : string option
  ; graphql_control_port : int option
  ; built_with_commit_sha : string
  }

module type S = sig
  val version : int

  type block_data [@@deriving to_yojson]

  val create_request :
    block_data_common -> Signature_lib.Keypair.t -> block_data request
end

module V0 : sig
  module T : sig
    type block_data =
      { block : string
      ; created_at : string
      ; peer_id : string
      ; snark_work : string option
      ; graphql_control_port : int option
      }
  end

  include S with type block_data := T.block_data
end

module V1 : sig
  module T : sig
    type block_data =
      { block : string
      ; created_at : string
      ; peer_id : string
      ; snark_work : string option
      ; graphql_control_port : int option
      ; built_with_commit_sha : string
      }
  end

  include S with type block_data := T.block_data
end
