open Core_kernel
open Async

module type For_tests_intf = sig
  type work

  type snark_pool

  type fee

  module For_tests : sig
    val does_not_have_better_fee :
      snark_pool:snark_pool -> fee:fee -> work list -> bool
  end
end

module type Work_selector_with_tests_intf = sig
  include Protocols.Coda_pow.Work_selector_intf

  include
    For_tests_intf
    with type work := work
     and type snark_pool := snark_pool
     and type fee := fee
end

module type Work_selector_F = functor (Inputs : Inputs.Inputs_intf) -> Work_selector_with_tests_intf
                                                                       with type 
                                                                       staged_ledger :=
                                                                         Inputs
                                                                         .Staged_ledger
                                                                         .t
                                                                        and type 
                                                                       work :=
                                                                         ( Inputs
                                                                           .Ledger_proof_statement
                                                                           .t
                                                                         , Inputs
                                                                           .Transaction
                                                                           .t
                                                                         , Inputs
                                                                           .Transaction_witness
                                                                           .t
                                                                         , Inputs
                                                                           .Ledger_proof
                                                                           .t
                                                                         )
                                                                         Snark_work_lib
                                                                         .Work
                                                                         .Single
                                                                         .Spec
                                                                         .t
                                                                        and type 
                                                                       snark_pool :=
                                                                         Inputs
                                                                         .Snark_pool
                                                                         .t
                                                                        and type 
                                                                       fee :=
                                                                         Inputs
                                                                         .Fee
                                                                         .t

module Make_test (Make_selector : Work_selector_F) = struct
  module T = Inputs.Test_input
  module Selector = Make_selector (T)

  let%test_unit "Workspec chunk doesn't send same things again" =
    Backtrace.elide := false ;
    let p = 50 in
    let g = Int.gen_incl 1 p in
    let snark_pool = T.Snark_pool.create () in
    let fee = 0 in
    Quickcheck.test g ~trials:100 ~f:(fun i ->
        Async.Thread_safe.block_on_async_exn (fun () ->
            let open Deferred.Let_syntax in
            let sl : T.Staged_ledger.t = List.init i ~f:Fn.id in
            let rec go i seen =
              [%test_result: Bool.t]
                ~message:"Exceeded time expected to exhaust work" ~expect:true
                (i <= p) ;
              let stuff, seen = Selector.work ~snark_pool ~fee sl seen in
              match stuff with [] -> return () | _ -> go (i + 1) seen
            in
            go 0 Selector.State.init ) )

  let gen_snark_pool works fee =
    let cheap_work_fee = fee - 1 in
    let expensive_work_fee = fee + 1 in
    let snark_pool = T.Snark_pool.create () in
    let gen_add_work work =
      let open Quickcheck.Generator.Let_syntax in
      let%bind should_add_work = Bool.gen in
      if should_add_work then
        let%map fee =
          Quickcheck.Generator.of_list [cheap_work_fee; expensive_work_fee]
        in
        T.Snark_pool.add_snark snark_pool ~work ~fee
      else return ()
    in
    List.iter works ~f:(fun work ->
        gen_add_work work |> Quickcheck.random_value ) ;
    snark_pool

  let%test_unit "selector shouldn't get work that it cannot outbid" =
    Backtrace.elide := false ;
    let p = 50 in
    let g = Int.gen_incl 1 p in
    Quickcheck.test g ~trials:100 ~f:(fun i ->
        Async.Thread_safe.block_on_async_exn (fun () ->
            let open Deferred.Let_syntax in
            let sl : T.Staged_ledger.t = List.init i ~f:Fn.id in
            let works = T.Staged_ledger.chunks_of sl ~n:2 in
            let my_fee = 2 in
            let snark_pool = gen_snark_pool works my_fee in
            let rec go i seen =
              [%test_result: Bool.t]
                ~message:"Exceeded time expected to exhaust work" ~expect:true
                (i <= p) ;
              let work, seen = Selector.work ~snark_pool ~fee:my_fee sl seen in
              match work with
              | [] -> return ()
              | job ->
                  [%test_result: Bool.t]
                    ~message:"Should not get any cheap jobs" ~expect:true
                    (Selector.For_tests.does_not_have_better_fee ~snark_pool
                       ~fee:my_fee job) ;
                  go (i + 1) seen
            in
            go 0 Selector.State.init ) )
end
