module Accounts : sig
  module Single : sig
    val to_account_with_pk :
      Runtime_config.Accounts.Single.t -> Mina_base.Account.t Core.Or_error.t

    val of_account :
         Mina_base.Account.t
      -> Signature_lib.Private_key.t option
      -> Runtime_config.Accounts.Single.t
  end

  val to_full :
       Runtime_config.Accounts.t
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list

  val gen_with_balance :
       Currency.Balance.Stable.V1.t
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t)
       Core.Quickcheck.Generator.t

  val gen :
    (Signature_lib.Private_key.t option * Mina_base.Account.t)
    Core.Quickcheck.Generator.t

  val generate :
       Core_kernel__.Import.int
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list

  val gen_balances_rev :
       (Core_kernel__Int.t * Currency.Balance.Stable.V1.t) list
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list
       Core.Quickcheck.Generator.t

  val pad_with_rev_balances :
       (Core_kernel__Int.t * Currency.Balance.Stable.V1.t) list
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list

  val pad_to :
       Core_kernel__Int.t
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list
end

val make_constraint_constants :
     default:Genesis_constants.Constraint_constants.t
  -> Runtime_config.Proof_keys.t
  -> Genesis_constants.Constraint_constants.t

val runtime_config_of_constraint_constants :
     proof_level:Genesis_constants.Proof_level.t
  -> Genesis_constants.Constraint_constants.t
  -> Runtime_config.Proof_keys.t

val make_genesis_constants :
     logger:Logger.t
  -> default:Genesis_constants.t
  -> Runtime_config.t
  -> Genesis_constants.t Base__Or_error.t

val runtime_config_of_genesis_constants :
  Genesis_constants.t -> Runtime_config.Genesis.t

val runtime_config_of_precomputed_values : Genesis_proof.t -> Runtime_config.t
