module type S = Intf.S

module Make
    (Balance : Intf.Balance)
    (Account : Intf.Account with type balance := Balance.t)
    (Hash : Intf.Hash with type account := Account.t)
    (Depth : Intf.Depth)
    (Kvdb : Intf.Key_value_database)
    (Sdb : Intf.Stack_database) :
  S with type account := Account.t and type hash := Hash.t

module Test_database = Test_database
