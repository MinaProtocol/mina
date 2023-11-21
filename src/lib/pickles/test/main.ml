let () =
  let test = Test_impls.tests @ Test_scalar_challenge.tests in
  Alcotest.run "Pickles" test
