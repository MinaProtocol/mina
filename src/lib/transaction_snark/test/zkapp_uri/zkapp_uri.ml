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

let suite () =
  Transaction_snark_test_suite.make ~name:"zkapp_uri"
    ~proof_cache_json:Proof_cache_json.contents
  @@ fun ~test ->
  let module _ = struct
    include
      Transaction_snark_tests.Test_zkapp_update.Make
        (Test_input)
        (struct
          let test = test
        end)
  end in
  ()
