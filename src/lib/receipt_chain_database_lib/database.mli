module Make
    (Payment : Intf.Payment)
    (Receipt_chain_hash : Intf.Receipt_chain_hash
                          with type payment_payload := Payment.Payload.t)
    (Key_value_db : Key_value_database.S
                    with type key := Receipt_chain_hash.t
                     and type value :=
                                (Receipt_chain_hash.t, Payment.t) Tree_node.t) :
  Intf.Test.S
  with type receipt_chain_hash := Receipt_chain_hash.t
   and type payment := Payment.t
   and type database := Key_value_db.t
