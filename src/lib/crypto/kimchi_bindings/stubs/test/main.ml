let () =
  let tests =
    Test_impls.tests
  in
  Alcotest.run "KimchiBindings" tests
