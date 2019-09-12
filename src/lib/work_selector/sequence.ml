module Make
    (Inputs : Intf.Inputs_intf)
    (Lib : Intf.Lib_intf with module Inputs := Inputs) =
struct
  let work ~snark_pool ~fee ~logger (staged_ledger : Inputs.Staged_ledger.t)
      (state : Lib.State.t) =
    let unseen_jobs = Lib.all_works staged_ledger state ~logger in
    match Lib.get_expensive_work ~snark_pool ~fee unseen_jobs with
    | [] ->
        (None, state)
    | x :: _ ->
        (Some x, Lib.State.set state x)
end

let%test_module "test" =
  ( module struct
    module Test = Test.Make_test (Make)
  end )
