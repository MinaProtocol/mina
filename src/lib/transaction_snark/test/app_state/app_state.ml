open Core_kernel
open Mina_base
open Pickles_types

module Test_input : Transaction_snark_tests.Test_zkapp_update.Input_intf =
struct
  let test_description = "app_state"

  let failure_expected =
    ( Mina_base.Transaction_status.Failure.Update_not_permitted_app_state
    , Transaction_snark_tests.Util.Pass_2 )

  let snapp_update =
    { Account_update.Update.dummy with
      app_state =
        Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
            Zkapp_basic.Set_or_keep.Set (Snark_params.Tick.Field.of_int i) )
    }

  let is_non_zkapp_update = false
end

let suite () =
  Transaction_snark_test_suite.make ~name:"app_state"
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
