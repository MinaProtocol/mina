open Mina_base

module Test_input : Transaction_snark_tests.Test_snapp_update.Input_intf =
struct
  let test_description = "permissions"

  let snapp_update =
    { Party.Update.dummy with
      permissions =
        Snapp_basic.Set_or_keep.Set
          { Permissions.user_default with
            set_permissions = Permissions.Auth_required.Proof
          ; set_snapp_uri = Proof
          ; set_token_symbol = Proof
          ; set_voting_for = Proof
          }
    }
end

let%test_module "Update account permissions" =
  ( module struct
    include Transaction_snark_tests.Test_snapp_update.Make (Test_input)
  end )
