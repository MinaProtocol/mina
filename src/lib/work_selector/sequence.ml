module Make
    (Inputs : Intf.Inputs_intf)
    (Lib : Intf.Lib_intf with module Inputs := Inputs) =
struct
  let work ~snark_pool ~fee ~logger (state : Lib.State.t) =
    Lib.State.remove_old_assignments state ~logger ;
    ()
  (*


    match Lib.State.zkapp_segment_witnesses,Lib.State.pending_proofs with
    [],[] -> (
      let unseen_jobs = Lib.State.all_unseen_works state in
      match Lib.get_expensive_work ~snark_pool ~fee unseen_jobs with
      | [] ->
        None
      | x :: _ ->
        let x' = One_or_two.map x ~f:(fun spec ->
            match (spec : (Inputs.Transaction_witness.t, Inputs.Ledger_proof.t)
                       Snark_work_lib.Work.Single.Spec.t) with
            | Transition (stmt, tw) ->
              (Transition (stmt,Transaction_witness tw) : (Work_lib.spec_inputs, Inputs.Ledger_proof.t)
                   Snark_work_lib.Work.Single.Spec.t
            | Merge _ -> spec))
        in
        Lib.State.set state x' ; Some x')
    | seg1::seg2::segs,_ -> (
        state.zkapp_segment_witnesses <- segs;
        failwith "Not implemented"
      )
    | _,proof1::proof2::proofs -> (
        state.pending_proofs <- proofs
        failwith "Not implemented" *)

  let remove = Lib.State.remove

  let pending_work_statements = Lib.pending_work_statements
end

let%test_module "test" =
  ( module struct
    module Test = Test.Make_test (Make)
  end )
