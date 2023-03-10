let () =
  Alcotest.run "Pickles"
    (Test_wrap_hack.tests @ Test_opt_sponge.tests @ Test_scalar_challenge.tests)
