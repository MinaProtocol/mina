open Mina_base

module Test_input : Transaction_snark_tests.Test_snapp_update.Input_intf =
struct
  let test_description = "voting_for"

  let snapp_update : Party.Update.t =
    { Party.Update.dummy with
      voting_for =
        Snapp_basic.Set_or_keep.Set
          (Async.Quickcheck.random_value State_hash.gen)
    }
end

let%test_module "Update account voting-for" =
  ( module struct
    include Transaction_snark_tests.Test_snapp_update.Make (Test_input)
  end )
