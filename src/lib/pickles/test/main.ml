let () =
  let test =
    Test_impls.tests @ Test_sponge.tests @ Test_scalar_challenge.tests
    @ Test_side_loaded_verification_key.tests
  in
  Alcotest.run "Pickles" test
