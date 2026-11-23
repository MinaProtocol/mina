open Core_kernel

let%test_unit "pending coinbase ring size is the scan state's max_trees" =
  List.iter (List.range 0 8) ~f:(fun transaction_capacity_log_2 ->
      List.iter (List.range 0 4) ~f:(fun work_delay ->
          let constraint_constants =
            { Genesis_constants.For_unit_tests.Constraint_constants.t with
              transaction_capacity_log_2
            ; work_delay
            }
          in
          [%test_eq: int]
            (Genesis_constants.Constraint_constants.pending_coinbase_ring_size
               constraint_constants )
            (Transaction_snark_scan_state.max_trees
               (Transaction_snark_scan_state.empty ~constraint_constants ()) ) ) )
