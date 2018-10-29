open Coda_base
open Signature_lib

module type S = sig
  val t : Ledger.t

  val accounts : (Private_key.t option * Account.t) list

  val find_account_record_exn :
    f:(Account.t -> bool) -> Private_key.t option * Account.t

  val find_new_account_record_exn :
    Public_key.t list -> Private_key.t option * Account.t

  val largest_account_exn : unit -> Private_key.t option * Account.t

  val largest_account_keypair_exn : unit -> Keypair.t

  val keypair_of_account_record_exn :
    Private_key.t option * Account.t -> Keypair.t
end
