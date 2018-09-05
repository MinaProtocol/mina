open Core

module type S = sig
  type account

  type hash

  type key

  type t

  type error = Account_key_not_found | Out_of_leaves | Malformed_database
  [@@deriving sexp]

  module Addr : Merkle_address.S

  module Path : Merkle_path.S with type hash := hash

  type path = Path.t

  val copy : t -> t

  val create : key_value_db_dir:string -> stack_db_file:string -> t

  val destroy : t -> unit

  val get_key_of_account : t -> account -> (key, error) Result.t

  val get : t -> key -> account option

  val set : t -> account -> (unit, error) Result.t

  val merkle_path : t -> key -> path

  include Merkle_tree_intf.S
          with type root_hash := hash
           and type hash := hash
           and type account := account
           and type addr := Addr.t
           and type t := t
           and type path := Path.t
end
