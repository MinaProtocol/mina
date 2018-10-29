open Core_kernel
open Async

module Make (Inputs : Inputs.Inputs_intf) :
  Protocols.Coda_pow.Work_selector_intf
  with type ledger_builder := Inputs.Ledger_builder.t
   and type work :=
              ( Inputs.Ledger_proof_statement.t
              , Inputs.Super_transaction.t
              , Inputs.Sparse_ledger.t
              , Inputs.Ledger_proof.t )
              Snark_work_lib.Work.Single.Spec.t = struct
  module Helper = Work_lib.Make (Inputs)
  module State = Helper.State

  let work (ledger_builder : Inputs.Ledger_builder.t) (state : State.t) =
    let unseen_jobs = Helper.all_works ledger_builder state in
    match unseen_jobs with
    | [] -> ([], state)
    | _ ->
        let i = Random.int (List.length unseen_jobs) in
        let x = List.nth_exn unseen_jobs i in
        (Helper.pair_to_list x, State.set state x)
end

let%test_module "test" =
  ( module struct
    module T = Inputs.Test_input
    module Selector = Make (T)

    let%test_unit "Random workspec chunk doesn't send same things again" =
      Backtrace.elide := false ;
      let p = 50 in
      let g = Int.gen_incl 1 p in
      Quickcheck.test g ~trials:100 ~f:(fun i ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let open Deferred.Let_syntax in
              let lb : T.Ledger_builder.t = List.init i ~f:Fn.id in
              (* A bit of a roundabout way to check, but essentially, if it
               * does not give repeats then our loop will not iterate more than
               * list-length times.*)
              let rec go i seen =
                [%test_result: Bool.t]
                  ~message:"Exceeded time expected to exhaust random work"
                  ~expect:true (i <= p) ;
                let stuff, seen = Selector.work lb seen in
                match stuff with [] -> return () | _ -> go (i + 1) seen
              in
              go 0 Selector.State.init ) )
  end )
