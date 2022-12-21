open Mina_base
open Pickles

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "verification_key"

  let failure_expected =
    Mina_base.Transaction_status.Failure.Update_not_permitted_verification_key

  let snapp_update : Account_update.Update.t =
    let new_verification_key :
        (Side_loaded.Verification_key.t, Zkapp_basic.F.t) With_hash.t =
      let data = Pickles.Side_loaded.Verification_key.dummy in
      let hash = Zkapp_account.dummy_vk_hash () in
      ({ data; hash } : _ With_hash.t)
    in
    { Account_update.Update.dummy with
      verification_key = Zkapp_basic.Set_or_keep.Set new_verification_key
    }
end

let%test_module "Update account verification key" =
  ( module struct
    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input)
  end )
