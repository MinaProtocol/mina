open Mina_base

type delegation = {
  sender_pub_key: Signature_lib.Public_key.t
  ; receiver_pub_key: Signature_lib.Public_key.t
  ; fee: Currency.Fee.t
}

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

  let default_tx ~sender_pub_key ~receiver_pub_key = 
    {
    sender_pub_key
    ; receiver_pub_key
    ; amount = Currency.Amount.of_mina_int_exn 1
    ; memo = ""
    ; valid_until = Mina_numbers.Global_slot_since_genesis.max_value
    ; fee = Currency.Fee.of_mina_int_exn 1
    ; nonce = None
  }

  let simple_tx ~sender_pub_key ~receiver_pub_key ~amount ~fee = 
    { (default_tx ~sender_pub_key ~receiver_pub_key) with 
      amount;
      fee
    }

  let simple_tx_compressed ~sender_pub_key ~receiver_pub_key ~amount ~fee =
    let sender_pub_key = Signature_lib.Public_key.decompress_exn sender_pub_key in
    let receiver_pub_key = Signature_lib.Public_key.decompress_exn receiver_pub_key in
    simple_tx ~sender_pub_key ~receiver_pub_key ~amount ~fee

  let delegation_compressed ~sender_pub_key ~receiver_pub_key ~fee =
    let sender_pub_key = Signature_lib.Public_key.decompress_exn sender_pub_key in
    let receiver_pub_key = Signature_lib.Public_key.decompress_exn receiver_pub_key in
    {
      sender_pub_key
      ;receiver_pub_key
      ;fee
    } 
  

  let to_raw_signature signed_tx = 
    let sender_pk = Signature_lib.Public_key.compress signed_tx.tx.sender_pub_key in
    let receiver_pk = Signature_lib.Public_key.compress signed_tx.tx.receiver_pub_key in
    let amount = signed_tx.tx.amount in
    let valid_until = Mina_numbers.Global_slot_since_genesis.max_value in
    let fee = signed_tx.tx.fee in
    let common =
        { Signed_command_payload.Common.Poly.fee
        ; fee_payer_pk = sender_pk
        ; nonce = (match signed_tx.tx.nonce with
          | Some nonce -> Account.Nonce.of_uint32 nonce
          | None -> Account.Nonce.of_int 0)
        ; valid_until
        ; memo =  Signed_command_memo.create_from_string_exn signed_tx.tx.memo
        }
    in
    let payment_payload = { Payment_payload.Poly.receiver_pk; amount } in
    let body = Signed_command_payload.Body.Payment payment_payload in
    let payload = { Signed_command_payload.Poly.common; body } in
    let raw_signature = Signed_command.sign_payload signed_tx.sender_priv_key payload
      |> Signature.Raw.encode in
    raw_signature