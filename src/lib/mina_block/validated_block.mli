open Mina_base

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V2 : sig
    type t [@@deriving equal]

    val hashes : t -> State_hash.State_hashes.t
  end
end]

module Serializable_type : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t

      val hashes : t -> State_hash.State_hashes.t
    end
  end]
end

type t [@@deriving to_yojson]

val lift : Validation.fully_valid_with_block -> t

val forget : t -> Block.with_hash

val remember : t -> Validation.fully_valid_with_block

val delta_block_chain_proof : t -> State_hash.t Mina_stdlib.Nonempty_list.t

val valid_commands : t -> User_command.Valid.t With_status.t list

val unsafe_of_trusted_block :
     delta_block_chain_proof:State_hash.t Mina_stdlib.Nonempty_list.t
  -> [ `This_block_is_trusted_to_be_safe of Block.with_hash ]
  -> t

val state_hash : t -> State_hash.t

val state_body_hash : t -> State_body_hash.t

val header : t -> Header.t

val body : t -> Staged_ledger_diff.Body.t

val is_genesis : t -> bool

val read_all_proofs_from_disk : t -> Stable.Latest.t

val to_serializable_type : t -> Serializable_type.t
