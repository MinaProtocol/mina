   
    type tx = {
        sender_pub_key: Signature_lib.Public_key.t
        ; receiver_pub_key: Signature_lib.Public_key.t
        ; amount: Currency.Amount.t
        ; memo: string
        ; valid_until: Mina_numbers.Global_slot_since_genesis.t
        ; nonce: Unsigned.uint32 option
        ; fee: Currency.Fee.t
    }

    type signed_tx = {
        tx: tx;
        sender_priv_key: Signature_lib.Private_key.t
    }

    val to_raw_signature: signed_tx -> string

    type delegation = {
        sender_pub_key: Signature_lib.Public_key.t
        ; receiver_pub_key: Signature_lib.Public_key.t
        ; fee: Currency.Fee.t
    }

    val default_tx: sender_pub_key:Signature_lib.Public_key.t -> receiver_pub_key:Signature_lib.Public_key.t -> tx

    val simple_tx: sender_pub_key:Signature_lib.Public_key.t -> receiver_pub_key:Signature_lib.Public_key.t -> amount:Currency.Amount.t -> fee:Currency.Fee.t -> tx

    val simple_tx_compressed: sender_pub_key:Signature_lib.Public_key.Compressed.t -> receiver_pub_key:Signature_lib.Public_key.Compressed.t -> amount:Currency.Amount.t -> fee:Currency.Fee.t -> tx

    val delegation_compressed: sender_pub_key:Signature_lib.Public_key.Compressed.t -> receiver_pub_key:Signature_lib.Public_key.Compressed.t -> fee:Currency.Fee.t -> delegation