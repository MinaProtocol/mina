open Core_kernel
open Parallel_scan

let%test_module "state operations" =
  ( module struct
    let job_done (job : (int, int) Available_job.t) : int =
      match job with Base i -> i | Merge (i, j) -> i + j

    (* --- empty state properties --- *)
    let%test_unit "empty state free_space matches max_base_jobs" =
      let s = empty ~max_base_jobs:16 ~delay:2 in
      [%test_eq: int] (free_space s) 16

    let%test_unit "empty state has no emitted value" =
      let s = empty ~max_base_jobs:8 ~delay:1 in
      assert (Option.is_none (last_emitted_value s))

    let%test_unit "empty state free space equals max_base_jobs" =
      let s = empty ~max_base_jobs:32 ~delay:0 in
      [%test_eq: int] (free_space s) 32

    let%test_unit "empty state sequence number is zero" =
      let s = empty ~max_base_jobs:8 ~delay:1 in
      [%test_eq: int] (current_job_sequence_number s) 0

    let%test_unit "empty state has no pending data" =
      let s = empty ~max_base_jobs:8 ~delay:1 in
      let pending = pending_data s in
      assert (List.for_all pending ~f:List.is_empty)

    let%test_unit "empty state next_on_new_tree is true" =
      let s = empty ~max_base_jobs:8 ~delay:1 in
      assert (next_on_new_tree s)

    (* --- free_space is constant max_base_jobs --- *)
    let%test_unit "free_space equals max_base_jobs" =
      let s = empty ~max_base_jobs:8 ~delay:1 in
      [%test_eq: int] (free_space s) 8 ;
      let data = [ 1; 2; 3 ] in
      let jobs = List.concat (jobs_for_slots s ~slots:(List.length data)) in
      let completed = List.map jobs ~f:job_done in
      let _, s' = Or_error.ok_exn (update ~data ~completed_jobs:completed s) in
      [%test_eq: int] (free_space s') 8

    (* --- partition_if_overflowing --- *)
    let%test_unit "partition_if_overflowing on empty state" =
      let s = empty ~max_base_jobs:8 ~delay:1 in
      let p = partition_if_overflowing s in
      assert (Int.( > ) (fst p.first) 0)

    (* --- sequence number increases --- *)
    let%test_unit "sequence number increases after update" =
      let s = empty ~max_base_jobs:4 ~delay:0 in
      let data = [ 1; 2; 3; 4 ] in
      let jobs = List.concat (jobs_for_slots s ~slots:(List.length data)) in
      let completed = List.map jobs ~f:job_done in
      let _, s' = Or_error.ok_exn (update ~data ~completed_jobs:completed s) in
      assert (current_job_sequence_number s' > current_job_sequence_number s)

    (* --- State.map --- *)
    let%test_unit "State.map preserves structure" =
      let s = empty ~max_base_jobs:4 ~delay:1 in
      let data = [ 10; 20; 30; 40 ] in
      let jobs = List.concat (jobs_for_slots s ~slots:(List.length data)) in
      let completed = List.map jobs ~f:job_done in
      let _, s' = Or_error.ok_exn (update ~data ~completed_jobs:completed s) in
      let s_mapped = State.map s' ~f1:(fun x -> x * 2) ~f2:(fun x -> x * 2) in
      [%test_eq: int] (free_space s_mapped) (free_space s')

    (* --- State.hash determinism --- *)
    let%test_unit "State.hash is deterministic" =
      let s = empty ~max_base_jobs:4 ~delay:1 in
      let data = [ 1; 2; 3; 4 ] in
      let jobs = List.concat (jobs_for_slots s ~slots:(List.length data)) in
      let completed = List.map jobs ~f:job_done in
      let _, s' = Or_error.ok_exn (update ~data ~completed_jobs:completed s) in
      let h1 = State.hash s' Int.to_string Int.to_string in
      let h2 = State.hash s' Int.to_string Int.to_string in
      assert (Digestif.SHA256.equal h1 h2)

    (* --- all_jobs / jobs_for_next_update --- *)
    let%test_unit "all_jobs on empty state returns empty jobs" =
      let s = empty ~max_base_jobs:4 ~delay:1 in
      let jobs = all_jobs s in
      assert (List.for_all jobs ~f:List.is_empty)

    let%test_unit "jobs_for_next_update provides enough work" =
      let s = empty ~max_base_jobs:4 ~delay:0 in
      let data = [ 1; 2; 3; 4 ] in
      let jobs = jobs_for_slots s ~slots:(List.length data) in
      let completed = List.map (List.concat jobs) ~f:job_done in
      let (_ : _ option * _) =
        Or_error.ok_exn (update ~data ~completed_jobs:completed s)
      in
      ()

    (* --- fold_chronological --- *)
    let%test_unit "fold_chronological visits all jobs" =
      let s = empty ~max_base_jobs:4 ~delay:0 in
      let data = [ 1; 2; 3; 4 ] in
      let jobs = List.concat (jobs_for_slots s ~slots:(List.length data)) in
      let completed = List.map jobs ~f:job_done in
      let _, s' = Or_error.ok_exn (update ~data ~completed_jobs:completed s) in
      let base_count =
        State.fold_chronological s' ~init:0
          ~f_merge:(fun acc _ -> acc)
          ~f_base:(fun acc _ -> acc + 1)
      in
      assert (base_count > 0)

    (* --- update with empty data --- *)
    let%test_unit "update with empty data and empty completed_jobs" =
      let s = empty ~max_base_jobs:4 ~delay:1 in
      let _, s' = Or_error.ok_exn (update ~data:[] ~completed_jobs:[] s) in
      [%test_eq: int] (free_space s') (free_space s)

    (* --- multiple updates produce result --- *)
    let%test_unit "multiple full updates eventually produce a result" =
      let max_base_jobs = 4 in
      let s = empty ~max_base_jobs ~delay:0 in
      let got_result = ref false in
      let _s =
        List.fold (List.init 20 ~f:Fn.id) ~init:s ~f:(fun state i ->
            let data =
              List.init max_base_jobs ~f:(fun j -> (i * max_base_jobs) + j)
            in
            let jobs =
              List.concat (jobs_for_slots state ~slots:(List.length data))
            in
            let completed = List.map jobs ~f:job_done in
            let result_opt, state' =
              Or_error.ok_exn (update ~data ~completed_jobs:completed state)
            in
            if Option.is_some result_opt then got_result := true ;
            state' )
      in
      assert !got_result
  end )
