open Signature_lib

let signature_kind = Mina_signature_kind.Testnet

let privkey =
  Private_key.of_base58_check_exn
    "EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N"

let secondPrivkey =
  Private_key.of_base58_check_exn
    "EKFXH5yESt7nsD1TJy5WNb4agVczkvzPRVexKQ8qYdNqauQRA8Ef"

let signature_expected =
  ( Snark_params.Tick.Field.of_string
      "22392589120931543014785073787084416773963960016576902579504636013984435243005"
  , Snark_params.Tock.Field.of_string
      "21219227048859428590456415944357352158328885122224477074004768710152393114331"
  )

let test_signature_of_empty_random_oracle_input_matches () =
  let signature_got =
    Schnorr.Legacy.sign ~signature_kind privkey
      (Random_oracle_input.Legacy.field_elements [||])
  in
  Alcotest.(check bool)
    "signature of empty random oracle input matches" true
    ( Snark_params.Tick.Field.equal (fst signature_expected) (fst signature_got)
    && Snark_params.Tock.Field.equal (snd signature_expected)
         (snd signature_got) )

let test_signature_of_signature_matches () =
  let signature_got =
    Schnorr.Legacy.sign ~signature_kind privkey
      (Random_oracle_input.Legacy.field_elements [| fst signature_expected |])
  in
  let signature_expected =
    ( Snark_params.Tick.Field.of_string
        "7379148532947400206038414977119655575287747480082205647969258483647762101030"
    , Snark_params.Tock.Field.of_string
        "26901815964642131149392134713980873704065643302140817442239336405283236628658"
    )
  in
  Alcotest.(check bool)
    "signature of signature matches" true
    ( Snark_params.Tick.Field.equal (fst signature_expected) (fst signature_got)
    && Snark_params.Tock.Field.equal (snd signature_expected)
         (snd signature_got) )

let test_signature_of_fields_123_matches () =
  let signature_got =
    Schnorr.Chunked.sign ~signature_kind secondPrivkey
      (Random_oracle_input.Chunked.field_elements
         [| Snark_params.Tick.Field.of_int 1
          ; Snark_params.Tick.Field.of_int 2
          ; Snark_params.Tick.Field.of_int 3
         |] )
  in
  (* The expected value has been generated using the commit [19872b9] of [MinaProtocol/mina] *)
  let signature_expected =
    ( Snark_params.Tick.Field.of_string
        "20765817320000234273433345899587917625188885976914380365037035465312392849949"
    , Snark_params.Tock.Field.of_string
        "1002418623751815063744079415040141105602079382674393704838141255389705661040"
    )
  in
  Alcotest.(check bool)
    "signature of fields 1,2,3 matches" true
    ( Snark_params.Tick.Field.equal (fst signature_expected) (fst signature_got)
    && Snark_params.Tock.Field.equal (snd signature_expected)
         (snd signature_got) )

let () =
  let open Alcotest in
  run "Signature_lib"
    [ ( "Signatures are unchanged test"
      , [ test_case "signature of empty random oracle input matches" `Quick
            test_signature_of_empty_random_oracle_input_matches
        ; test_case "signature of signature matches" `Quick
            test_signature_of_signature_matches
        ; test_case "signature of fields 1,2,3 matches" `Quick
            test_signature_of_fields_123_matches
        ] )
    ]
