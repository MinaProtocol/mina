open Core_kernel

module Make (Lib : Intf.Lib_intf) = struct
  let work ~snark_pool ~fee ~logger:_ (state : Lib.State.t) =
    match Lib.State.all_unscheduled_expensive_works ~snark_pool ~fee state with
    | [] ->
        None
    | expensive_work ->
        let i = Random.int (List.length expensive_work) in
        let x = List.nth_exn expensive_work i in
        Lib.State.mark_scheduled state x ;
        Some x
end

let%test_module "test" =
  ( module struct
    module Test = Test.Make_test (Make)
  end )
