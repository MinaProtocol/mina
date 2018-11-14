open Core_kernel

module Make (Inputs : Inputs.Inputs_intf) :
  Test.Work_selector_with_tests_intf
  with type ledger_builder := Inputs.Ledger_builder.t
   and type work :=
              ( Inputs.Ledger_proof_statement.t
              , Inputs.Transaction.t
              , Inputs.Sparse_ledger.t
              , Inputs.Ledger_proof.t )
              Snark_work_lib.Work.Single.Spec.t
   and type snark_pool := Inputs.Snark_pool.t
   and type fee := Inputs.Fee.t = struct
  module Helper = Work_lib.Make (Inputs)
  module State = Helper.State

  module For_tests = struct
    let does_not_have_better_fee = Helper.For_tests.does_not_have_better_fee
  end

  let work ~snark_pool ~fee (ledger_builder : Inputs.Ledger_builder.t)
      (state : State.t) =
    let unseen_jobs = Helper.all_works ledger_builder state in
    match Helper.get_expensive_work ~snark_pool ~fee unseen_jobs with
    | [] -> ([], state)
    | _ ->
        let i = Random.int (List.length unseen_jobs) in
        let x = List.nth_exn unseen_jobs i in
        (Helper.pair_to_list x, State.set state x)
end

let%test_module "test" =
  ( module struct
    module Test = Test.Make_test (Make)
  end )
