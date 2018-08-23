module Make
    (Balance : Intf.Balance)
    (Account : Intf.Account with type balance := Balance.t)
    (Hash : Intf.Hash with type account := Account.t)
    (Depth : Intf.Depth)
    (Kvdb : Intf.Key_value_database)
    (Sdb : Intf.Stack_database) : sig
  include Intf.Database_S
          with type account := Account.t
           and type hash := Hash.t

  val gen_account_key : key Core.Quickcheck.Generator.t
end
