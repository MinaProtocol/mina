open Mina_base

module Test_input1 : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "vk-permission-proof"

  let failure_expected =
    ( Mina_base.Transaction_status.Failure.Update_not_permitted_permissions
    , Transaction_snark_tests.Util.Pass_2 )

  let snapp_update =
    { Account_update.Update.dummy with
      permissions =
        Zkapp_basic.Set_or_keep.Set
          { Permissions.user_default with
            set_verification_key = (Proof, Mina_numbers.Txn_version.current)
          }
    }

  let is_non_zkapp_update = true
end

let%test_module "Set verification key permission to Proof" =
  ( module struct
    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input1)
  end )

module Test_input2 : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "vk-permission-impossible"

  let failure_expected =
    ( Mina_base.Transaction_status.Failure.Update_not_permitted_permissions
    , Transaction_snark_tests.Util.Pass_2 )

  let snapp_update =
    { Account_update.Update.dummy with
      permissions =
        Zkapp_basic.Set_or_keep.Set
          { Permissions.user_default with
            set_verification_key = (Impossible, Mina_numbers.Txn_version.current)
          }
    }

  let is_non_zkapp_update = true
end

let%test_module "Set verification key permission to Impossible" =
  ( module struct
    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input2)
  end )