let () =
  Alcotest.run "Pickles"
    ( Test_wrap_hack.tests @ Test_opt_sponge.tests @ Test_scalar_challenge.tests
    @ Test_side_loaded_verification_key.tests )
