let create ~of_int =
  let one = of_int 1 in
  let t = of_int 7 in
  let z = one in
  let w = Pickles_types.(Vector.init Plonk_types.Columns.n ~f:(fun _ -> one)) in
  Pickles_types.Plonk_types.Messages.Poly.{ w; z; t }
