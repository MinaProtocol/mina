module type S = sig
  include Base_ledger_intf.S

  val create : ?directory_name:string -> depth:int -> unit -> t

  (** create_checkpoint would create the checkpoint and open a db connection to that checkpoint *)
  val create_checkpoint : t -> directory_name:string -> unit -> t

  (** make_checkpoint would only create the checkpoint *)
  val make_checkpoint : t -> directory_name:string -> unit

  val with_ledger : depth:int -> f:(t -> 'a) -> 'a

  module For_tests : sig
    val gen_account_location :
      ledger_depth:int -> Location.t Core.Quickcheck.Generator.t
  end
end

module type Inputs_intf = sig
  include Base_inputs_intf.S

  module Location : Location_intf.S

  module Location_binable :
    Core_kernel.Hashable.S_binable with type t := Location.t

  module Kvdb : Intf.Key_value_database with type config := string

  module Storage_locations : Intf.Storage_locations
end
