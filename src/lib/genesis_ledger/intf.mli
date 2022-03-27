module Timing : sig
  type t = (int, int, int) Mina_base.Account_timing.Poly.t

  val gen :
    ( Core_kernel__.Import.int
    , Core_kernel__.Import.int
    , Core_kernel__.Import.int )
    Mina_base.Account_timing.Poly.t
    Core_kernel__Quickcheck.Generator.t
end

module Public_accounts : sig
  type account_data =
    { pk : Signature_lib.Public_key.Compressed.t
    ; balance : int
    ; delegate : Signature_lib.Public_key.Compressed.t option
    ; timing : Timing.t
    }

  module type S = sig
    val name : string

    val accounts : account_data list Core_kernel.Lazy.t
  end
end

module Private_accounts : sig
  type account_data =
    { pk : Signature_lib.Public_key.Compressed.t
    ; sk : Signature_lib.Private_key.t
    ; balance : int
    ; timing : Timing.t
    }

  module type S = sig
    val name : string

    val accounts : account_data list Core_kernel.Lazy.t
  end
end

module type Named_balances_intf = sig
  val name : string

  val balances : int list Core_kernel.Lazy.t
end

module type Accounts_intf = sig
  val accounts :
    (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    Core_kernel.Lazy.t
end

module type Named_accounts_intf = sig
  val name : string

  val accounts :
    (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    Core_kernel.Lazy.t
end

module type Ledger_input_intf = sig
  val accounts :
    (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    Core_kernel.Lazy.t

  val directory : [ `Ephemeral | `New | `Path of string ]

  val depth : int
end

module type S = sig
  val t : Mina_base.Ledger.t Core_kernel.Lazy.t

  val depth : int

  val accounts :
    (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    Core_kernel.Lazy.t

  val find_account_record_exn :
       f:(Mina_base.Account.t -> bool)
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val find_new_account_record_exn :
       Signature_lib.Public_key.t list
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val find_new_account_record_exn_ :
       Signature_lib.Public_key.Compressed.t list
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val largest_account_exn :
    unit -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val largest_account_id_exn : unit -> Mina_base.Account_id.t

  val largest_account_pk_exn : unit -> Signature_lib.Public_key.Compressed.t

  val largest_account_keypair_exn : unit -> Signature_lib.Keypair.t

  val keypair_of_account_record_exn :
       Signature_lib.Private_key.t option * Mina_base.Account.t
    -> Signature_lib.Keypair.t

  val id_of_account_record :
       Signature_lib.Private_key.t option * Mina_base.Account.t
    -> Mina_base.Account_id.t

  val pk_of_account_record :
       Signature_lib.Private_key.t option * Mina_base.Account.t
    -> Signature_lib.Public_key.Compressed.t
end
