type t [@@deriving equal]

val to_string : t -> string

val make :
     signature_kind:Mina_signature_kind.t
  -> genesis_constants:Genesis_constants.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> genesis_ledger:Consensus.Genesis_data.Hashed.t
  -> genesis_epoch_data:
       Consensus.Genesis_data.Hashed.t Consensus.Genesis_data.Epoch.t
  -> t Lazy.t
