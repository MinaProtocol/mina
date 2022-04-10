module Intf = Intf

val account_with_timing :
     Mina_base.Account_id.t
  -> 'a
  -> Intf.Timing.t
  -> ( Mina_base.Import.Public_key.Compressed.t
     , Mina_base.Token_id.t
     , Mina_base.Token_permissions.t
     , 'a
     , Mina_numbers.Account_nonce.t
     , Mina_base.Receipt.Chain_hash.t
     , Mina_base.Import.Public_key.Compressed.t option
     , Mina_base.State_hash.t
     , ( Mina_numbers.Global_slot.t
       , Currency.Balance.Stable.Latest.t
       , Currency.Amount.Stable.Latest.t )
       Mina_base.Account_timing.tt
     , Mina_base.Permissions.t
     , 'b option )
     Mina_base.Account.Poly.t

module Private_accounts : functor (Accounts : Intf.Private_accounts.S) -> sig
  val name : string

  val accounts :
    ( Signature_lib.Private_key.t option
    * ( Mina_base.Import.Public_key.Compressed.t
      , Mina_base.Token_id.t
      , Mina_base.Token_permissions.t
      , Currency.Balance.Stable.Latest.t
      , Mina_numbers.Account_nonce.t
      , Mina_base.Receipt.Chain_hash.t
      , Mina_base.Import.Public_key.Compressed.t option
      , Mina_base.State_hash.t
      , ( Mina_numbers.Global_slot.t
        , Currency.Balance.Stable.Latest.t
        , Currency.Amount.Stable.Latest.t )
        Mina_base.Account_timing.tt
      , Mina_base.Permissions.t
      , 'a option )
      Mina_base.Account.Poly.t )
    list
    Core_kernel__Lazy.t
end

module Public_accounts : functor (Accounts : Intf.Public_accounts.S) -> sig
  val name : string

  val accounts :
    ( 'a option
    * ( Mina_base.Import.Public_key.Compressed.t
      , Mina_base.Token_id.t
      , Mina_base.Token_permissions.t
      , Currency.Balance.Stable.Latest.t
      , Mina_numbers.Account_nonce.t
      , Mina_base.Receipt.Chain_hash.t
      , Signature_lib.Public_key.Compressed.t
      , Mina_base.State_hash.t
      , ( Mina_numbers.Global_slot.t
        , Currency.Balance.Stable.Latest.t
        , Currency.Amount.Stable.Latest.t )
        Mina_base.Account_timing.tt
      , Mina_base.Permissions.t
      , 'b option )
      Mina_base.Account.Poly.t )
    list
    Core_kernel__Lazy.t
end

module Balances : functor (Balances : Intf.Named_balances_intf) -> sig
  val name : string

  val accounts :
    ( Signature_lib.Private_key.t option
    * ( Mina_base.Import.Public_key.Compressed.t
      , Mina_base.Token_id.t
      , Mina_base.Token_permissions.t
      , Currency.Balance.Stable.Latest.t
      , Mina_numbers.Account_nonce.t
      , Mina_base.Receipt.Chain_hash.t
      , Mina_base.Import.Public_key.Compressed.t option
      , Mina_base.State_hash.t
      , ( Mina_numbers.Global_slot.t
        , Currency.Balance.Stable.Latest.t
        , Currency.Amount.Stable.Latest.t )
        Mina_base.Account_timing.tt
      , Mina_base.Permissions.t
      , 'a option )
      Mina_base.Account.Poly.t )
    list
    Core_kernel__Lazy.t
end

module Utils : sig
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

  val find_new_account_record_exn_ :
       ('a * Mina_base.Account.t) list
    -> Mina_base.Account.key list
    -> 'a * Mina_base.Account.t

  val find_new_account_record_exn :
       ('a * Mina_base.Account.t) list
    -> Signature_lib.Public_key.t list
    -> 'a * Mina_base.Account.t
end

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

val find_new_account_record_exn_ :
     ('a * Mina_base.Account.t) list
  -> Mina_base.Account.key list
  -> 'a * Mina_base.Account.t

val find_new_account_record_exn :
     ('a * Mina_base.Account.t) list
  -> Signature_lib.Public_key.t list
  -> 'a * Mina_base.Account.t

module Make : functor (Inputs : Intf.Ledger_input_intf) -> Intf.S

module Packed : sig
  type t = (module Intf.S)

  val t : t -> Mina_base.Ledger.t Core_kernel.Lazy.t

  val depth : t -> int

  val accounts :
       t
    -> (Signature_lib.Private_key.t option * Mina_base.Account.t) list
       Core_kernel.Lazy.t

  val find_account_record_exn :
       t
    -> f:(Mina_base.Account.t -> bool)
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val find_new_account_record_exn_ :
       t
    -> Signature_lib.Public_key.Compressed.t list
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val find_new_account_record_exn :
       t
    -> Signature_lib.Public_key.t list
    -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val largest_account_exn :
    t -> Signature_lib.Private_key.t option * Mina_base.Account.t

  val largest_account_id_exn : t -> Mina_base.Account_id.t

  val largest_account_pk_exn : t -> Signature_lib.Public_key.Compressed.t

  val largest_account_keypair_exn : t -> Signature_lib.Keypair.t
end

module Of_ledger : functor
  (T : sig
     val t : Mina_base.Ledger.t Core_kernel.Lazy.t

     val depth : int
   end)
  -> Intf.S

val fetch_ledger :
     Core_kernel.String.Map.Key.t
  -> (module Intf.Named_accounts_intf) Core_kernel__.Import.option

val register_ledger : (module Intf.Named_accounts_intf) -> unit

val fetch_ledger_exn :
  Core_kernel.String.Map.Key.t -> (module Intf.Named_accounts_intf)

module Register : functor (Accounts : Intf.Named_accounts_intf) ->
  Intf.Named_accounts_intf

module Testnet_postake : sig
  val name : string

  val accounts :
    (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    Core_kernel.Lazy.t
end

module Testnet_postake_many_producers : Intf.Named_accounts_intf

module Test : sig
  val name : string

  val accounts :
    (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    Core_kernel.Lazy.t
end

module Fuzz : sig
  val name : string

  val accounts :
    (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    Core_kernel.Lazy.t
end

module Release : sig
  val name : string

  val accounts :
    (Signature_lib.Private_key.t option * Mina_base.Account.t) list
    Core_kernel.Lazy.t
end

module Unit_test_ledger : Intf.S

val for_unit_tests : Packed.t

module Integration_tests : sig
  module Delegation : Intf.Named_accounts_intf

  module Five_even_stakes : Intf.Named_accounts_intf

  module Split_two_stakes : Intf.Named_accounts_intf

  module Three_even_stakes : Intf.Named_accounts_intf
end
