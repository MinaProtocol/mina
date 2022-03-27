module Inputs : sig
  type t =
    { runtime_config : Runtime_config.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; genesis_constants : Genesis_constants.t
    ; genesis_ledger : Genesis_ledger.Packed.t
    ; genesis_epoch_data : Consensus.Genesis_epoch_data.t
    ; consensus_constants : Consensus.Constants.t
    ; protocol_state_with_hashes :
        Mina_state.Protocol_state.value Mina_base.State_hash.With_state_hashes.t
    ; constraint_system_digests : (string * Md5_lib.t) list option
    ; blockchain_proof_system_id : Pickles.Verification_key.Id.t option
    }

  val runtime_config : t -> Runtime_config.t

  val constraint_constants : t -> Genesis_constants.Constraint_constants.t

  val genesis_constants : t -> Genesis_constants.t

  val proof_level : t -> Genesis_constants.Proof_level.t

  val protocol_constants : t -> Genesis_constants.Protocol.Stable.Latest.t

  val ledger_depth : t -> int

  val keypair_of_account_record_exn :
       Signature_lib.Private_key.t option
       * ( Signature_lib.Public_key.Compressed.t
         , 'a
         , 'b
         , 'c
         , 'd
         , 'e
         , 'f
         , 'g
         , 'h
         , 'i
         , 'j )
         Mina_base.Account.Poly.Stable.Latest.t
    -> Signature_lib.Keypair.t

  val id_of_account_record : 'a * Mina_base.Account.t -> Mina_base.Account_id.t

  val pk_of_account_record : 'a * Mina_base.Account.t -> Mina_base.Account.key

  val find_account_record_exn : f:('a -> bool) -> ('b * 'a) list -> 'b * 'a

  val genesis_ledger : t -> Mina_base.Ledger.t Core_kernel.Lazy.t

  val genesis_epoch_data : t -> Consensus.Genesis_epoch_data.t

  val accounts :
       t
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list
       Core_kernel.Lazy.t

  val find_new_account_record_exn :
       t
    -> Signature_lib.Public_key.t list
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val find_new_account_record_exn_ :
       t
    -> Signature_lib.Public_key.Compressed.t list
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val largest_account_exn :
    t -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val largest_account_keypair_exn : t -> Signature_lib.Keypair.t

  val largest_account_pk_exn : t -> Signature_lib.Public_key.Compressed.t

  val consensus_constants : t -> Consensus.Constants.t

  val genesis_state_with_hashes :
       t
    -> Mina_state.Protocol_state.value Mina_base.State_hash.With_state_hashes.t

  val genesis_state : t -> Mina_state.Protocol_state.value

  val genesis_state_hashes : t -> Mina_base__State_hash.State_hashes.t
end

module Proof_data : sig
  type t =
    { blockchain_proof_system_id : Pickles.Verification_key.Id.t
    ; genesis_proof : Mina_base.Proof.t
    }
end

module T : sig
  type t =
    { runtime_config : Runtime_config.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; genesis_constants : Genesis_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; genesis_ledger : Genesis_ledger.Packed.t
    ; genesis_epoch_data : Consensus.Genesis_epoch_data.t
    ; consensus_constants : Consensus.Constants.t
    ; protocol_state_with_hashes :
        Mina_state.Protocol_state.value Mina_base.State_hash.With_state_hashes.t
    ; constraint_system_digests : (string * Md5_lib.t) list Core_kernel.Lazy.t
    ; proof_data : Proof_data.t option
    }

  val runtime_config : t -> Runtime_config.t

  val constraint_constants : t -> Genesis_constants.Constraint_constants.t

  val genesis_constants : t -> Genesis_constants.t

  val proof_level : t -> Genesis_constants.Proof_level.t

  val protocol_constants : t -> Genesis_constants.Protocol.Stable.Latest.t

  val ledger_depth : t -> int

  val keypair_of_account_record_exn :
       Signature_lib.Private_key.t option
       * ( Signature_lib.Public_key.Compressed.t
         , 'a
         , 'b
         , 'c
         , 'd
         , 'e
         , 'f
         , 'g
         , 'h
         , 'i
         , 'j )
         Mina_base.Account.Poly.Stable.Latest.t
    -> Signature_lib.Keypair.t

  val id_of_account_record : 'a * Mina_base.Account.t -> Mina_base.Account_id.t

  val pk_of_account_record : 'a * Mina_base.Account.t -> Mina_base.Account.key

  val find_account_record_exn : f:('a -> bool) -> ('b * 'a) list -> 'b * 'a

  val genesis_ledger : t -> Mina_base.Ledger.t Core_kernel.Lazy.t

  val genesis_epoch_data : t -> Consensus.Genesis_epoch_data.t

  val accounts :
       t
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list
       Core_kernel.Lazy.t

  val find_new_account_record_exn :
       t
    -> Signature_lib.Public_key.t list
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val find_new_account_record_exn_ :
       t
    -> Signature_lib.Public_key.Compressed.t list
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val largest_account_exn :
    t -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val largest_account_keypair_exn : t -> Signature_lib.Keypair.t

  val largest_account_pk_exn : t -> Signature_lib.Public_key.Compressed.t

  val consensus_constants : t -> Consensus.Constants.t

  val genesis_state_with_hashes :
       t
    -> Mina_state.Protocol_state.value Mina_base.State_hash.With_state_hashes.t

  val genesis_state : t -> Mina_state.Protocol_state.value

  val genesis_state_hashes : t -> Mina_base__State_hash.State_hashes.t

  val genesis_proof : t -> Mina_base.Proof.t option
end

type t = T.t =
  { runtime_config : Runtime_config.t
  ; constraint_constants : Genesis_constants.Constraint_constants.t
  ; genesis_constants : Genesis_constants.t
  ; proof_level : Genesis_constants.Proof_level.t
  ; genesis_ledger : Genesis_ledger.Packed.t
  ; genesis_epoch_data : Consensus.Genesis_epoch_data.t
  ; consensus_constants : Consensus.Constants.t
  ; protocol_state_with_hashes :
      Mina_state.Protocol_state.value Mina_base.State_hash.With_state_hashes.t
  ; constraint_system_digests : (string * Md5_lib.t) list Core_kernel.Lazy.t
  ; proof_data : Proof_data.t option
  }

val runtime_config : t -> Runtime_config.t

val constraint_constants : t -> Genesis_constants.Constraint_constants.t

val genesis_constants : t -> Genesis_constants.t

val proof_level : t -> Genesis_constants.Proof_level.t

val protocol_constants : t -> Genesis_constants.Protocol.Stable.Latest.t

val ledger_depth : t -> int

val keypair_of_account_record_exn :
     Signature_lib.Private_key.t option
     * ( Signature_lib.Public_key.Compressed.t
       , 'a
       , 'b
       , 'c
       , 'd
       , 'e
       , 'f
       , 'g
       , 'h
       , 'i
       , 'j )
       Mina_base.Account.Poly.Stable.Latest.t
  -> Signature_lib.Keypair.t

val id_of_account_record : 'a * Mina_base.Account.t -> Mina_base.Account_id.t

val pk_of_account_record : 'a * Mina_base.Account.t -> Mina_base.Account.key

val find_account_record_exn : f:('a -> bool) -> ('b * 'a) list -> 'b * 'a

val genesis_ledger : t -> Mina_base.Ledger.t Core_kernel.Lazy.t

val genesis_epoch_data : t -> Consensus.Genesis_epoch_data.t

val accounts :
     t
  -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list
     Core_kernel.Lazy.t

val find_new_account_record_exn :
     t
  -> Signature_lib.Public_key.t list
  -> Signature_lib.Private_key.t option * Mina_base.Account.t

val find_new_account_record_exn_ :
     t
  -> Signature_lib.Public_key.Compressed.t list
  -> Signature_lib.Private_key.t option * Mina_base.Account.t

val largest_account_exn :
  t -> Signature_lib.Private_key.t option * Mina_base.Account.t

val largest_account_keypair_exn : t -> Signature_lib.Keypair.t

val largest_account_pk_exn : t -> Signature_lib.Public_key.Compressed.t

val consensus_constants : t -> Consensus.Constants.t

val genesis_state_with_hashes :
  t -> Mina_state.Protocol_state.value Mina_base.State_hash.With_state_hashes.t

val genesis_state : t -> Mina_state.Protocol_state.value

val genesis_state_hashes : t -> Mina_base__State_hash.State_hashes.t

val genesis_proof : t -> Mina_base.Proof.t option

val base_proof :
     (module Blockchain_snark.Blockchain_snark_state.S)
  -> Inputs.t
  -> (Pickles_types.Nat.N2.n, Pickles_types.Nat.N2.n) Pickles.Proof.t
     Async.Deferred.t

val digests :
     (module Transaction_snark.S)
  -> (module Blockchain_snark.Blockchain_snark_state.S)
  -> (string * Md5_lib.t) Base__List.t Core_kernel__Lazy.t

val blockchain_snark_state :
     Inputs.t
  -> (module Transaction_snark.S)
     * (module Blockchain_snark.Blockchain_snark_state.S)

val create_values :
     (module Transaction_snark.S)
  -> (module Blockchain_snark.Blockchain_snark_state.S)
  -> Inputs.t
  -> t Async.Deferred.t

val create_values_no_proof : Inputs.t -> t

val to_inputs : t -> Inputs.t
