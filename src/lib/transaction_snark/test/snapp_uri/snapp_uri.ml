open Mina_base

module Test_input : Transaction_snark_tests.Test_snapp_update.Input_intf =
struct
  let test_description = "snapp_uri"

  let snapp_update =
    { Party.Update.dummy with
      snapp_uri = Snapp_basic.Set_or_keep.Set "https://www.minaprotocol.com"
    }
end

let%test_module "Update account snapp URI" =
  ( module struct
    include Transaction_snark_tests.Test_snapp_update.Make (Test_input)
  end )
