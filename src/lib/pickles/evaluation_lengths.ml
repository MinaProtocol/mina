open Core_kernel

let create ~of_int =
  let one = of_int 1 in
  let open Pickles_types in
  let open Plonk_types in
  Evals.
    { w = Vector.init Columns.n ~f:(fun _ -> one)
    ; coefficients = Vector.init Columns.n ~f:(fun _ -> one)
    ; z = one
    ; s = Vector.init Permuts_minus_1.n ~f:(fun _ -> one)
    ; generic_selector = one
    ; poseidon_selector = one
    ; complete_add_selector = one
    ; mul_selector = one
    ; emul_selector = one
    ; endomul_scalar_selector = one
    ; (* FIXME *)
      range_check0_selector = None
    ; range_check1_selector = None
    ; foreign_field_add_selector = None
    ; foreign_field_mul_selector = None
    ; xor_selector = None
    ; rot_selector = None
    ; lookup_aggregation = None
    ; lookup_table = None
    ; lookup_sorted =
        (let max_columns_num = 5 in
         Array.init max_columns_num ~f:(fun _ -> None) )
    ; runtime_lookup_table = None
    ; runtime_lookup_table_selector = None
    ; xor_lookup_selector = None
    ; lookup_gate_lookup_selector = None
    ; range_check_lookup_selector = None
    ; foreign_field_mul_lookup_selector = None
    }
