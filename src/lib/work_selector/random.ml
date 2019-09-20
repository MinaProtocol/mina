open Core_kernel

module Make
    (Inputs : Intf.Inputs_intf)
    (Lib : Intf.Lib_intf with module Inputs := Inputs) =
struct
  let work ~snark_pool ~fee ~logger (staged_ledger : Inputs.Staged_ledger.t)
      (state : Lib.State.t) =
    let state = Lib.State.remove_old_assignments state ~logger in
    let unseen_jobs = Lib.all_works staged_ledger state in
    match Lib.get_expensive_work ~snark_pool ~fee unseen_jobs with
    | [] ->
        (None, state)
    | expensive_work ->
        let i = Random.int (List.length expensive_work) in
        let x = List.nth_exn expensive_work i in
        (Some x, Lib.State.set state x)

  let remove = Lib.State.remove
end

let%test_module "test" =
  ( module struct
    module Test = Test.Make_test (Make)
  end )
