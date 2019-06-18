open Core_kernel
open Async
open Currency

module Make_test (Make_selection_method : Intf.Make_selection_method_intf) =
struct
  module T = Inputs.Test_inputs
  module Lib = Work_lib.Make (T)
  module Selection_method = Make_selection_method (T) (Lib)

  let%test_unit "Workspec chunk doesn't send same things again" =
    Backtrace.elide := false ;
    let p = 50 in
    let g = Int.gen_incl 1 p in
    let snark_pool = T.Snark_pool.create () in
    let fee = Fee.of_int 0 in
    Quickcheck.test g ~trials:100 ~f:(fun i ->
        Async.Thread_safe.block_on_async_exn (fun () ->
            let open Deferred.Let_syntax in
            let sl : T.Staged_ledger.t = List.init i ~f:Fn.id in
            let rec go i seen =
              [%test_result: Bool.t]
                ~message:"Exceeded time expected to exhaust work" ~expect:true
                (i <= p) ;
              let stuff, seen =
                Selection_method.work ~snark_pool ~fee sl seen
              in
              match stuff with [] -> return () | _ -> go (i + 1) seen
            in
            go 0 Lib.State.init ) )

  let gen_snark_pool works fee =
    let cheap_work_fee = Option.value_exn Fee.(sub fee one) in
    let expensive_work_fee = Option.value_exn Fee.(add fee one) in
    let snark_pool = T.Snark_pool.create () in
    let gen_add_work work =
      let open Quickcheck.Generator.Let_syntax in
      let%bind should_add_work = Bool.quickcheck_generator in
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
            let works =
              T.Staged_ledger.chunks_of sl ~n:2
              |> List.map ~f:(List.map ~f:Fee.of_int)
            in
            let my_fee = Fee.of_int 2 in
            let snark_pool = gen_snark_pool works my_fee in
            let rec go i seen =
              [%test_result: Bool.t]
                ~message:"Exceeded time expected to exhaust work" ~expect:true
                (i <= p) ;
              let work, seen =
                Selection_method.work ~snark_pool ~fee:my_fee sl seen
              in
              match work with
              | [] ->
                  return ()
              | job ->
                  [%test_result: Bool.t]
                    ~message:"Should not get any cheap jobs" ~expect:true
                    (Lib.For_tests.does_not_have_better_fee ~snark_pool
                       ~fee:my_fee job) ;
                  go (i + 1) seen
            in
            go 0 Lib.State.init ) )
end
