open Mina_base

type t [@@deriving sexp, to_yojson]

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

val account_ids_accessed :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> t
  -> (Account_id.t * [ `Accessed | `Not_accessed ]) list

val transactions :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> t
  -> Mina_transaction.Transaction.t With_status.t list

val block : t -> Block.t
