open Core

module type S = sig
  type account

  type hash

  type location

  type key

  type t

  module Db_error : sig
    type t = Account_location_not_found | Out_of_leaves | Malformed_database
  end

  module Addr : Merkle_address.S

  module Path : Merkle_path.S with type hash := hash

  val create : unit -> t

  val location_of_key : t -> key -> location option

  val destroy : t -> unit

  val to_list : t -> account list

  val get : t -> location -> account option

  val set : t -> location -> account -> unit

  val set_batch : t -> (location * account) list -> unit

  val get_at_index_exn : t -> int -> account

  val set_at_index_exn : t -> int -> account -> unit

  val index_of_key_exn : t -> key -> int

  val get_or_create_account :
    t -> key -> account -> ([`Added | `Existed] * location, Db_error.t) result

  val get_or_create_account_exn :
    t -> key -> account -> [`Added | `Existed] * location

  val merkle_path : t -> location -> Path.t

  val merkle_path_at_index_exn : t -> int -> Path.t

  val remove_accounts_exn : t -> key list -> unit

  val copy : t -> t

  include
    Syncable_intf.S
    with type root_hash := hash
     and type hash := hash
     and type account := account
     and type addr := Addr.t
     and type t := t
     and type path := Path.t

  module For_tests : sig
    val gen_account_location : location Core.Quickcheck.Generator.t
  end
end
