module Make
    (Public_key : sig
      type t
      val to_string : t -> string
    end)
    (Account : Intf.Account with type key := Public_key.t)
    (Hash : Intf.Hash with type account := Account.t)
    (Depth : Intf.Depth)
    (Kvdb : Intf.Key_value_database)
    (Sdb : Intf.Stack_database) : sig
  include Database_intf.S
          with type account := Account.t
           and type hash := Hash.t
           and type key := Public_key.t

  module Key : sig
    type t
  end

  val of_index: int -> Key.t

  val to_index: Key.t -> int

  val get_account_from_key : t -> Key.t -> Account.t option

  val get_key_of_account : t -> Account.t -> (Key.t, error) Core.Result.t

  val update_account: t -> Key.t -> Account.t -> unit

  val public_key_to_index : t -> Public_key.t -> Key.t option

  module For_tests : sig
    val gen_account_key : Key.t Core.Quickcheck.Generator.t
  end
end
