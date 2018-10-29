type ('key, 'value) tree_node =
  | Root of {children: 'key list}
  | Child of {parent: 'key; children: 'key list; value: 'value}
[@@deriving sexp]

module Make
    (Transaction : Intf.Transaction)
    (Receipt_chain_hash : Intf.Receipt_chain_hash
                          with type transaction_payload := Transaction.payload)
    (Key_value_db : Key_value_database.S
                    with type key := Receipt_chain_hash.t
                     and type value :=
                                (Receipt_chain_hash.t, Transaction.t) tree_node) :
  Intf.Test.S
  with type receipt_chain_hash := Receipt_chain_hash.t
   and type transaction := Transaction.t
   and type database := Key_value_db.t
