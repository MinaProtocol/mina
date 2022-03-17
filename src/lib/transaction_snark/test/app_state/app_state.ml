open Mina_base
open Pickles_types

module Test_input : Transaction_snark_tests.Test_snapp_update.Input_intf =
struct
  let test_description = "app_state"

  let snapp_update =
    { Party.Update.dummy with
      app_state =
        Vector.init Snapp_state.Max_state_size.n ~f:(fun i ->
            Snapp_basic.Set_or_keep.Set (Snark_params.Tick.Field.of_int i))
    }
end

let%test_module "Update account app_state" =
  ( module struct
    include Transaction_snark_tests.Test_snapp_update.Make (Test_input)
  end )
