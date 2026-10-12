module Make (Lib : Intf.Lib_intf) = struct
  let work ~snark_pool ~fee ~logger (state : Lib.State.t) =
    match Lib.State.all_unscheduled_expensive_works ~snark_pool ~fee state with
    | [] ->
        None
    | x :: _ ->
        Lib.State.schedule_and_build_spec ~logger state x
end

let%test_module "test" =
  ( module struct
    module Test = Test.Make_test (Make)
  end )
