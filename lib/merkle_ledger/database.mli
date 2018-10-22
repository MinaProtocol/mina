open Core_kernel
open Coda_spec

module type Key_value_database_intf = sig
  type t

  val copy : t -> t

  val create : directory:string -> t

  val destroy : t -> unit

  val get : t -> key:Bigstring.t -> Bigstring.t option

  val set : t -> key:Bigstring.t -> data:Bigstring.t -> unit

  val delete : t -> key:Bigstring.t -> unit
end

module type Stack_database_intf = sig
  type t

  val copy : t -> t

  val create : filename:string -> t

  val destroy : t -> unit

  val push : t -> Bigstring.t -> unit

  val pop : t -> Bigstring.t option

  val length : t -> int
end

module type Storage_locations_intf = sig
  val key_value_db_dir : string

  val stack_db_file : string
end

module type Inputs_intf = sig
  module Depth : Ledger_intf.Depth.S
  module Account : Account_intf.S
  module Root_hash : Ledger_intf.Root_hash.S
  module Hash : Ledger_intf.Hash.S
  module Kvdb : Key_value_database_intf
  module Sdb : Stack_database_intf
  module Storage_locations : Storage_locations_intf
end

module Make (Inputs : Inputs_intf) :
  Ledger_intf.Base.S
    with module Account = Inputs.Account
     and module Root_hash = Inputs.Root_hash
     and module Hash = Inputs.Hash
     and module Addr = Merkle_address
     and module Path = Merkle_path
