module Make
    (Account : Intf.Account with type key := String.t)
    (Hash : Intf.Hash with type account := Account.t)
    (Depth : Intf.Depth)
    (Kvdb : Intf.Key_value_database)
    (Sdb : Intf.Stack_database) : sig
  
  
  module Key : sig
    type t
    
    val of_index: int -> t

    val to_index: t -> int
  end

  include Database_intf.S
          with type account := Account.t
           and type hash := Hash.t
           and type key := Key.t
  
  

  val update_account: t -> Key.t -> Account.t -> unit

  module For_tests : sig
    val gen_account_key : Key.t Core.Quickcheck.Generator.t
  end
end
