open Mina_base

module Test_input : Transaction_snark_tests.Test_snapp_update.Input_intf =
struct
  let test_description = "token_symbol"

  let snapp_update =
    { Party.Update.dummy with
      token_symbol = Snapp_basic.Set_or_keep.Set "Zoozoo"
    }
end

let%test_module "Update account token symbol" =
  ( module struct
    include Transaction_snark_tests.Test_snapp_update.Make (Test_input)
  end )
