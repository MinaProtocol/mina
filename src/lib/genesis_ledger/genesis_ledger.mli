open Core_kernel
open Signature_lib
open Mina_base
module Ledger = Mina_ledger.Ledger
module Root_ledger = Mina_ledger.Root
module Intf = Intf

module Utils : sig
  val id_of_account_record : Private_key.t option * Account.t -> Account_id.t
end

module Make (Inputs : Intf.Ledger_input_intf) : Intf.S

module Packed : sig
  type t = (module Intf.S)

  val t : t -> Ledger.t Lazy.t

  val create_root :
       t
    -> config:Root_ledger.Config.t
    -> depth:int
    -> unit
    -> Root_ledger.t Async.Deferred.Or_error.t

  val create_root_with_directory :
    t -> directory:string -> depth:int -> unit -> Root_ledger.t Or_error.t

  val depth : t -> int

  val accounts : t -> (Private_key.t option * Account.t) list Lazy.t

  val find_account_record_exn :
    t -> f:(Account.t -> bool) -> Private_key.t option * Account.t

  val find_new_account_record_exn_ :
    t -> Public_key.Compressed.t list -> Private_key.t option * Account.t

  val find_new_account_record_exn :
    t -> Public_key.t list -> Private_key.t option * Account.t

  val largest_account_exn : t -> Private_key.t option * Account.t

  val largest_account_id_exn : t -> Account_id.t

  val largest_account_pk_exn : t -> Public_key.Compressed.t

  val largest_account_keypair_exn : t -> Keypair.t
end

module Of_ledger (T : sig
  val backing_ledger : Root_ledger.t Lazy.t

  val depth : int
end) : Intf.S

val fetch_ledger : string -> (module Intf.Named_accounts_intf) option

val register_ledger : (module Intf.Named_accounts_intf) -> unit

val fetch_ledger_exn : string -> (module Intf.Named_accounts_intf)

val for_unit_tests : Packed.t
