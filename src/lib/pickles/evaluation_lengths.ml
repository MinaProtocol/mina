let create ~of_int =
  let one = of_int 1 in
  let z = one
  and generic_selector = one
  and poseidon_selector = one
  and lookup = None in
  let vinit = Pickles_types.Vector.init ~f:(fun _ -> one) in
  Pickles_types.Plonk_types.Evals.
    { w = vinit Pickles_types.Plonk_types.Columns.n
    ; z
    ; s = vinit Pickles_types.Plonk_types.Permuts_minus_1.n
    ; generic_selector
    ; poseidon_selector
    ; lookup
    }

let constants = create ~of_int:(fun x -> x)
