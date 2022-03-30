open Core_kernel
open Signature_lib

let%test_module "Signatures are unchanged test" =
  ( module struct
    let privkey =
      Private_key.of_base58_check_exn
        "EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N"

    let signature_expected =
      ( Snark_params.Tick.Field.of_string
          "22392589120931543014785073787084416773963960016576902579504636013984435243005"
      , Snark_params.Tock.Field.of_string
          "21219227048859428590456415944357352158328885122224477074004768710152393114331"
      )

    let%test "signature of empty random oracle input matches" =
      let signature_got =
        Schnorr.sign privkey (Random_oracle_input.field_elements [||])
      in
      Snark_params.Tick.Field.equal (fst signature_expected) (fst signature_got)
      && Snark_params.Tock.Field.equal (snd signature_expected)
           (snd signature_got)

    let%test "signature of signature matches" =
      let signature_got =
        Schnorr.sign privkey
          (Random_oracle_input.field_elements [| fst signature_expected |])
      in
      let signature_expected =
        ( Snark_params.Tick.Field.of_string
            "7379148532947400206038414977119655575287747480082205647969258483647762101030"
        , Snark_params.Tock.Field.of_string
            "26901815964642131149392134713980873704065643302140817442239336405283236628658"
        )
      in
      Snark_params.Tick.Field.equal (fst signature_expected) (fst signature_got)
      && Snark_params.Tock.Field.equal (snd signature_expected)
           (snd signature_got)

    (* Testsuite from
       https://github.com/o1-labs/proof-systems/blob/bbc4c77382507c3a0c66f9fda1a7499a5d547b7a/signer/tests/signer.rs#L125
    *)

    type test_schema =
      { txn_type : [ `Payment | `Delegation ]
      ; sender_sk : string (*Private_key.t*)
      ; source : string (*Public_key.Compressed.t*)
      ; receiver : string
      ; amount : int64
      ; fee : int64
      ; nonce : int32
      ; valid_until : int32
      ; memo : string
      ; testnet_signature : string
      ; mainnet_signature : string
      }

    (* Use non-standard printing that the rust tests are written using. *)
    let hex_print_signature (rx, s) =
      let rx_bytes =
        Zexe_backend.Pasta.Vesta_based_plonk.(
          Bigint.R.to_hex_string (Field.to_bigint rx))
      in
      let s_bytes =
        Zexe_backend.Pasta.Pallas_based_plonk.(
          Bigint.R.to_hex_string (Field.to_bigint s))
      in
      sprintf "%s%s" rx_bytes s_bytes

    let run_test (schema : test_schema) =
      let sender_sk =
        Zexe_backend.Pasta.Pallas_based_plonk.Bigint.R.of_hex_string
          schema.sender_sk
        |> Zexe_backend.Pasta.Pallas_based_plonk.Field.of_bigint
      in
      let source = Public_key.Compressed.of_base58_check_exn schema.source in
      let receiver =
        Public_key.Compressed.of_base58_check_exn schema.receiver
      in
      let amount =
        Currency.Amount.of_uint64 (Unsigned.UInt64.of_int64 schema.amount)
      in
      let fee = Currency.Fee.of_uint64 (Unsigned.UInt64.of_int64 schema.fee) in
      let nonce : Mina_numbers.Account_nonce.t =
        Unsigned.UInt32.of_int32 schema.nonce
      in
      let valid_until : Mina_numbers.Global_slot.t =
        Unsigned.UInt32.of_int32 schema.valid_until
      in
      let memo =
        Mina_base.Signed_command_memo.create_from_string schema.memo
        |> Or_error.ok_exn
      in
      let open Mina_base in
      let body =
        match schema.txn_type with
        | `Payment ->
            Signed_command_payload.Body.Payment
              { source_pk = source
              ; receiver_pk = receiver
              ; token_id = Token_id.default
              ; amount
              }
        | `Delegation ->
            Signed_command_payload.Body.Stake_delegation
              (Set_delegate { delegator = source; new_delegate = receiver })
      in
      let payload =
        { Signed_command_payload.Poly.body
        ; common =
            { Signed_command_payload.Common.Poly.fee
            ; fee_token = Token_id.default
            ; fee_payer_pk = source
            ; nonce
            ; valid_until
            ; memo
            }
        }
      in
      let got_testnet_signature =
        Signed_command.sign_payload ~signature_kind:Testnet sender_sk payload
        |> hex_print_signature
      in
      let got_mainnet_signature =
        Signed_command.sign_payload ~signature_kind:Mainnet sender_sk payload
        |> hex_print_signature
      in
      [%test_eq: string] got_testnet_signature schema.testnet_signature ;
      [%test_eq: string] got_mainnet_signature schema.mainnet_signature

    let%test_unit "sign_payment_test_1" =
      run_test
        { txn_type = `Payment
        ; sender_sk =
            "0x164244176fddb5d769b7de2027469d027ad428fadcc0c02396e6280142efb718"
        ; source = "B62qnzbXmRNo9q32n4SNu2mpB8e7FYYLH8NmaX6oFCBYjjQ8SbD7uzV"
        ; receiver = "B62qicipYxyEHu7QjUqS7QvBipTs5CzgkYZZZkPoKVYBu6tnDUcE9Zt"
        ; amount = 1729000000000L
        ; fee = 2000000000L
        ; nonce = 16l
        ; valid_until = 271828l
        ; memo = "Hello Mina!"
        ; testnet_signature =
            "11a36a8dfe5b857b95a2a7b7b17c62c3ea33411ae6f4eb3a907064aecae353c60794f1d0288322fe3f8bb69d6fabd4fd7c15f8d09f8783b2f087a80407e299af"
        ; mainnet_signature =
            "124c592178ed380cdffb11a9f8e1521bf940e39c13f37ba4c55bb4454ea69fba3c3595a55b06dac86261bb8ab97126bf3f7fff70270300cb97ff41401a5ef789"
        }
  end )
