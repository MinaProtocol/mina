(* The [create] function used to be there. It was just instantiated with the constant
   value that  is now called {!commitment_lengths}*)
let create ~of_int =
  let one = of_int 1 in
  let t = of_int 7 in
  let z = one in
  let w = Pickles_types.(Vector.init Plonk_types.Columns.n ~f:(fun _ -> one)) in
  Pickles_types.Plonk_types.Messages.Poly.{ w; z; t }

let commitment_lengths = create ~of_int:(fun x -> x)
