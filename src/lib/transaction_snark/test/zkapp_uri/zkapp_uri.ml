open Core_kernel
open Mina_base

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "zkapp_uri"

  let failure_expected =
    ( Mina_base.Transaction_status.Failure.Update_not_permitted_zkapp_uri
    , Transaction_snark_tests.Util.Pass_2 )

  let snapp_update =
    { Account_update.Update.dummy with
      zkapp_uri = Zkapp_basic.Set_or_keep.Set "https://www.minaprotocol.com"
    }

  let is_non_zkapp_update = false
end

let%test_module "Update account snapp URI" =
  ( module struct
    let proof_cache =
      Result.ok_or_failwith @@ Pickles.Proof_cache.of_yojson
      @@ Yojson.Safe.from_file "proof_cache.json"

    let () = Transaction_snark.For_tests.set_proof_cache proof_cache

    include Transaction_snark_tests.Test_zkapp_update.Make (Test_input)

    (*let () =
      Yojson.Safe.to_file "proof_cache.json.out"
      @@ Pickles.Proof_cache.to_yojson proof_cache*)
  end )
