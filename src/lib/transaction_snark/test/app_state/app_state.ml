open Mina_base
open Pickles_types

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "app_state"

  let failure_expected =
    Mina_base.Transaction_status.Failure.Update_not_permitted_app_state

  let snapp_update =
    { Account_update.Update.dummy with
      app_state =
        Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
            Zkapp_basic.Set_or_keep.Set (Snark_params.Step.Field.of_int i) )
    }
end

let%test_module "Update account app_state" =
  ( module struct
    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input)
  end )
