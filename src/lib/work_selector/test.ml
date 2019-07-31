open Core_kernel
open Async
open Currency

module Make_test (Make_selection_method : Intf.Make_selection_method_intf) =
struct
  module T = Inputs.Test_inputs
  module Lib = Work_lib.Make (T)
  module Selection_method = Make_selection_method (T) (Lib)

  let gen_staged_ledger =
    Quickcheck.Generator.list
    @@ Snark_work_lib.Work.Single.Spec.gen Int.quickcheck_generator
         Int.quickcheck_generator Fee.gen

  let%test_unit "Workspec chunk doesn't send same things again" =
    Backtrace.elide := false ;
    let p = 50 in
    let snark_pool = T.Snark_pool.create () in
    let fee = Currency.Fee.zero in
    Quickcheck.test gen_staged_ledger ~trials:100 ~f:(fun sl ->
        Async.Thread_safe.block_on_async_exn (fun () ->
            let open Deferred.Let_syntax in
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
    let open Quickcheck.Generator.Let_syntax in
    let cheap_work_fee = Option.value_exn Fee.(sub fee one) in
    let expensive_work_fee = Option.value_exn Fee.(add fee one) in
    let snark_pool = T.Snark_pool.create () in
    let rec add_works = function
      | [] ->
          return ()
      | work :: rest ->
          let%bind fee =
            Quickcheck.Generator.of_list [cheap_work_fee; expensive_work_fee]
          in
          T.Snark_pool.add_snark snark_pool ~work ~fee ;
          add_works rest
    in
    let pair_to_list : 'a * 'a option -> 'b list =
      Snark_work_lib.Work.Single.Spec.(
        function
        | a, Some b -> [statement a; statement b] | a, None -> [statement a])
    in
    let%map () = add_works (List.map ~f:pair_to_list works) in
    snark_pool

  let%test_unit "selector shouldn't get work that it cannot outbid" =
    Backtrace.elide := false ;
    let my_fee = Currency.Fee.of_int 2 in
    let p = 50 in
    let g =
      let open Quickcheck.Generator.Let_syntax in
      let%bind sl = gen_staged_ledger in
      let%map pool =
        gen_snark_pool
          (T.Staged_ledger.all_work_pairs_exn sl)
          (Currency.Fee.of_int 2)
      in
      (sl, pool)
    in
    Quickcheck.test g
      ~sexp_of:
        [%sexp_of:
          (int, int, Fee.t) Lib.Work_spec.t list
          * Fee.t T.Snark_pool.Work.Table.t] ~trials:100
      ~f:(fun (sl, snark_pool) ->
        Async.Thread_safe.block_on_async_exn (fun () ->
            let open Deferred.Let_syntax in
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
