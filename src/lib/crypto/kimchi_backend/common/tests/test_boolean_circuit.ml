let test_prove_verify () =
  let size = 1 lsl 15 in
  let srs = Kimchi_bindings.Protocol.SRS.Fp.create size in
  let data =
    let v = Kimchi_bindings.FieldVectors.Fp.create () in
    for _ = 1 to size do
      let b = Random.int 2 |> Pasta_bindings.Fp.of_int in
      Kimchi_bindings.FieldVectors.Fp.emplace_back v b
    done ;
    Kimchi_bindings.Protocol.Boolean_circuit.create_witness srs v
  in
  let proof = Kimchi_bindings.Protocol.Boolean_circuit.boolean_prove srs data in
  let verifies =
    Kimchi_bindings.Protocol.Boolean_circuit.boolean_verify srs proof
  in
  assert verifies

let tests =
  let open Alcotest in
  [ ( "boolean circuit tests"
    , [ test_case "prove_verify" `Quick test_prove_verify ] )
  ]
