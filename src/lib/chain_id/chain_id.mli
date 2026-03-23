type t [@@deriving equal]

val to_string : t -> string

val make :
     genesis_constants:Genesis_constants.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> genesis_ledger:Consensus.Genesis_data.Hashed.t
  -> genesis_epoch_data:
       Consensus.Genesis_data.Hashed.t Consensus.Genesis_data.Epoch.t
  -> constraint_system_digests:(string * Md5_lib.t) list Lazy.t
  -> t Lazy.t

val of_precomputed_values : Precomputed_values.t -> t Lazy.t
