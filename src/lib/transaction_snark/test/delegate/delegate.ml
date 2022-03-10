open Mina_base

module Test_input : Transaction_snark_tests.Test_snapp_update.Input_intf =
struct
  let test_description = "delegate"

  let snapp_update =
    let pk =
      Async.Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
    in
    { Party.Update.dummy with delegate = Snapp_basic.Set_or_keep.Set pk }
end

let%test_module "Update account delegate" =
  ( module struct
    include Transaction_snark_tests.Test_snapp_update.Make (Test_input)
  end )
