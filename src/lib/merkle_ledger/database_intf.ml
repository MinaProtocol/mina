module type S = sig
  include Base_ledger_intf.S

  val create : ?directory_name:string -> unit -> t

  val with_ledger : f:(t -> 'a) -> 'a

  module For_tests : sig
    val gen_account_location : Location.t Core.Quickcheck.Generator.t
  end
end
