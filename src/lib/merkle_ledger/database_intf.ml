module type S = sig
  include Base_ledger_intf.S

  val create : ?directory_name:string -> depth:int -> unit -> t

  val with_ledger : depth:int -> f:(t -> 'a) -> 'a

  module For_tests : sig
    val gen_account_location :
      ledger_depth:int -> Location.t Core.Quickcheck.Generator.t
  end
end
