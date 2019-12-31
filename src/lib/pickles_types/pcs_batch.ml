open Core_kernel

type ('n, 'm) t =
  {without_degree_bound: 'n Nat.t; with_degree_bound: (int, 'm) Vector.t}

let create ~without_degree_bound ~with_degree_bound =
  {without_degree_bound; with_degree_bound}

let combine_commitments t ~scale ~add ~xi
    (init :: without_degree_bound : (_, _ Nat.s) Vector.t) with_degree_bound =
  let polys =
    Vector.to_list without_degree_bound
    @ List.concat_map (Vector.to_list with_degree_bound)
        ~f:(fun (unshifted, shifted) -> [unshifted; shifted])
  in
  List.fold_left polys ~init ~f:(fun acc p -> add p (scale acc xi))

let combine_evaluations {without_degree_bound; with_degree_bound}
    ~crs_max_degree ~mul ~add ~one ~evaluation_point ~xi
    (init :: evals0 : (_, _ Nat.s) Vector.t) evals1 =
  let pow x n =
    let k = Int.ceil_log2 n in
    let rec go acc i =
      if i < 0 then acc
      else
        let acc = mul acc acc in
        let b = (n lsr i) land 1 = 1 in
        let acc = if b then mul x acc else acc in
        go acc (i - 1)
    in
    go one (k - 1)
  in
  let evals =
    Vector.to_list evals0
    @ List.concat
        (Vector.to_list
           (Vector.map2 with_degree_bound evals1 ~f:(fun deg fx ->
                [fx; mul (pow evaluation_point (crs_max_degree - deg)) fx] )))
  in
  List.fold_left evals ~init ~f:(fun acc fx -> add fx (mul acc xi))
