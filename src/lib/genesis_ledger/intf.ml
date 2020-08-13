open Coda_base
open Signature_lib
open Core_kernel

module Timing = struct
  type t =
    { initial_minimum_balance: int
    ; cliff_time: int (*slot number*)
    ; vesting_period: int (*in slots*)
    ; vesting_increment: int }

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind initial_minimum_balance =
      Quickcheck.Generator.small_non_negative_int
    in
    let%bind cliff_time = Quickcheck.Generator.small_non_negative_int in
    let%bind vesting_increment = Quickcheck.Generator.small_non_negative_int in
    let%map vesting_period = Quickcheck.Generator.small_positive_int in
    {initial_minimum_balance; cliff_time; vesting_increment; vesting_period}
end

module Public_accounts = struct
  type account_data =
    { pk: Public_key.Compressed.t
    ; balance: int
    ; delegate: Public_key.Compressed.t option
    ; timing: Timing.t option }

  module type S = sig
    val name : string

    val accounts : account_data list Lazy.t
  end
end

module Private_accounts = struct
  type account_data =
    { pk: Public_key.Compressed.t
    ; sk: Private_key.t
    ; balance: int
    ; timing: Timing.t option }

  module type S = sig
    val name : string

    val accounts : account_data list Lazy.t
  end
end

module type Named_balances_intf = sig
  val name : string

  val balances : int list Lazy.t
end

module type Accounts_intf = sig
  val accounts : (Private_key.t option * Account.t) list Lazy.t
end

module type Named_accounts_intf = sig
  val name : string

  include Accounts_intf
end

module type Ledger_input_intf = sig
  include Accounts_intf

  val directory : [`Ephemeral | `New | `Path of string]

  val depth : int
end

module type S = sig
  val t : Ledger.t Lazy.t

  val depth : int

  val accounts : (Private_key.t option * Account.t) list Lazy.t

  val find_account_record_exn :
    f:(Account.t -> bool) -> Private_key.t option * Account.t

  val find_new_account_record_exn :
    Public_key.t list -> Private_key.t option * Account.t

  val find_new_account_record_exn_ :
    Public_key.Compressed.t list -> Private_key.t option * Account.t

  val largest_account_exn : unit -> Private_key.t option * Account.t

  val largest_account_id_exn : unit -> Account_id.t

  val largest_account_pk_exn : unit -> Public_key.Compressed.t

  val largest_account_keypair_exn : unit -> Keypair.t

  val keypair_of_account_record_exn :
    Private_key.t option * Account.t -> Keypair.t

  val id_of_account_record : Private_key.t option * Account.t -> Account_id.t

  val pk_of_account_record :
    Private_key.t option * Account.t -> Public_key.Compressed.t
end
