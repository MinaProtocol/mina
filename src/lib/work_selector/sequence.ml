module Make (Inputs : Inputs.Inputs_intf) :
  Test.Work_selector_with_tests_intf
  with type staged_ledger := Inputs.Staged_ledger.t
   and type work :=
              ( Inputs.Ledger_proof_statement.t
              , Inputs.Transaction.t
              , Inputs.Transaction_witness.t
              , Inputs.Ledger_proof.t )
              Snark_work_lib.Work.Single.Spec.t
   and type snark_pool := Inputs.Snark_pool.t
   and type fee := Inputs.Fee.t = struct
  module Helper = Work_lib.Make (Inputs)
  module State = Helper.State

  module For_tests = struct
    let does_not_have_better_fee = Helper.For_tests.does_not_have_better_fee
  end

  let work ~snark_pool ~fee (staged_ledger : Inputs.Staged_ledger.t)
      (state : State.t) =
    let unseen_jobs = Helper.all_works staged_ledger state in
    match Helper.get_expensive_work ~snark_pool ~fee unseen_jobs with
    | [] -> ([], state)
    | x :: _ -> (Helper.pair_to_list x, State.set state x)
end

let%test_module "test" =
  ( module struct
    module Test = Test.Make_test (Make)
  end )
