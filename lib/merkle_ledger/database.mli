module Make
    (Account : Intf.Account)
    (Hash : Intf.Hash with type account := Account.t)
    (Depth : Intf.Depth)
    (Kvdb : Intf.Key_value_database)
    (Sdb : Intf.Stack_database) : sig
  include Database_intf.S
          with type account := Account.t
           and type hash := Hash.t

  module For_tests : sig
    val gen_account_key : key Core.Quickcheck.Generator.t
  end
end
