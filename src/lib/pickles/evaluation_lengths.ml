let create ~num_chunks ~of_int =
  let one = of_int num_chunks in
  let open Pickles_types in
  let open Plonk_types in
  let vec =
    let v = Vector.init Columns.n ~f:(fun _ -> one) in
    fun () -> Array.create ~len:num_chunks v
  in
  Evals.
    { w = vec ()
    ; coefficients = vec ()
    ; z = one
    ; s =
        Array.create ~len:num_chunks
          (Vector.init Permuts_minus_1.n ~f:(fun _ -> one))
    ; generic_selector = Array.create ~len:num_chunks one
    ; poseidon_selector = Array.create ~len:num_chunks one
    ; lookup = None
    }
