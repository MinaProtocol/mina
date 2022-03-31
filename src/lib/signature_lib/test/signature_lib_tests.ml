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
        Schnorr.Legacy.sign privkey
          (Random_oracle_input.Legacy.field_elements [||])
      in
      Snark_params.Tick.Field.equal (fst signature_expected) (fst signature_got)
      && Snark_params.Tock.Field.equal (snd signature_expected)
           (snd signature_got)

    let%test "signature of signature matches" =
      let signature_got =
        Schnorr.Legacy.sign privkey
          (Random_oracle_input.Legacy.field_elements
             [| fst signature_expected |])
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
  end )
