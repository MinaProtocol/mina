module Make (Lib : Intf.Lib_intf) = struct
  let work ~snark_pool ~fee ~logger (state : Lib.State.t) =
    Lib.State.remove_old_assignments state ~logger ;
    let unseen_jobs = Lib.State.all_unseen_works state in
    match Lib.get_expensive_work ~snark_pool ~fee unseen_jobs with
    | [] ->
        None
    | x :: _ ->
        Lib.State.set state x ; Some x
end

let%test_module "test" =
  ( module struct
    module Test = Test.Make_test (Make)
  end )
