open Core_kernel
open Mina_base

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "voting_for"

  let failure_expected =
    ( Mina_base.Transaction_status.Failure.Update_not_permitted_voting_for
    , Transaction_snark_tests.Util.Pass_2 )

  let snapp_update : Account_update.Update.t =
    { Account_update.Update.dummy with
      voting_for =
        Zkapp_basic.Set_or_keep.Set
          (Async.Quickcheck.random_value State_hash.gen)
    }

  let is_non_zkapp_update = true
end

let suite () =
  Transaction_snark_test_suite.make ~name:"voting_for"
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
