open Mina_base

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "delegate"

  let failure_expected =
    Mina_base.Transaction_status.Failure.Update_not_permitted Delegate

  let snapp_update =
    let pk =
      Async.Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
    in
    { Party.Update.dummy with delegate = Zkapp_basic.Set_or_keep.Set pk }
end

let%test_module "Update account delegate" =
  ( module struct
    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input)
  end )
