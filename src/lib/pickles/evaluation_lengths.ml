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
    ; lookup = None
    }
