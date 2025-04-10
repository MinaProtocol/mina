open Core_kernel

type ('a, 'n, 'm) t =
  { without_degree_bound : 'n Nat.t; with_degree_bound : ('a, 'm) Vector.t }

let map t ~f = { t with with_degree_bound = Vector.map t.with_degree_bound ~f }

let num_bits n = Int.floor_log2 n + 1

let pow ~one ~mul x n =
  assert (n >= 0) ;
  let k = num_bits n in
  let rec go acc i =
    if i < 0 then acc
    else
      let acc = mul acc acc in
      let b = (n lsr i) land 1 = 1 in
      let acc = if b then mul x acc else acc in
      go acc (i - 1)
  in
  go one (k - 1)

let create ~without_degree_bound ~with_degree_bound =
  { without_degree_bound; with_degree_bound }

let combine_commitments _t ~scale ~add ~xi (type n)
    (without_degree_bound : (_, n) Vector.t) with_degree_bound =
  match without_degree_bound with
  | [] ->
      failwith "combine_commitments: empty list"
  | init :: without_degree_bound ->
      let polys =
        Vector.to_list without_degree_bound
        @ List.concat_map (Vector.to_list with_degree_bound)
            ~f:(fun (unshifted, shifted) -> [ unshifted; shifted ])
      in
      List.fold_left polys ~init ~f:(fun acc p -> add p (scale acc xi))

let combine_evaluations' (type a n m)
    ({ without_degree_bound = _; with_degree_bound } : (a, n Nat.s, m) t)
    ~shifted_pow ~mul ~add ~one:_ ~evaluation_point ~xi
    (init :: evals0 : (_, n Nat.s) Vector.t) (evals1 : (_, m) Vector.t) =
  let evals =
    Vector.to_list evals0
    @ List.concat
        (Vector.to_list
           (Vector.map2 with_degree_bound evals1 ~f:(fun deg fx ->
                [ fx; mul (shifted_pow deg evaluation_point) fx ] ) ) )
  in
  List.fold_left evals ~init ~f:(fun acc fx -> add fx (mul acc xi))

let[@warning "-45"] combine_evaluations' (type n) (t : (_, n, _) t) ~shifted_pow
    ~mul ~add ~one ~evaluation_point ~xi (evals0 : (_, n) Vector.t) evals1 =
  match evals0 with
  | Vector.[] ->
      failwith "Empty evals0"
  | _ :: _ ->
      combine_evaluations' t ~shifted_pow ~mul ~add ~one ~evaluation_point ~xi
        evals0 evals1

let combine_evaluations (type f) t ~crs_max_degree ~(mul : f -> f -> f) ~add
    ~one ~evaluation_point ~xi evals0 evals1 =
  let pow = pow ~one ~mul in
  combine_evaluations' t evals0 evals1
    ~shifted_pow:(fun deg x -> pow x (crs_max_degree - deg))
    ~mul ~add ~one ~evaluation_point ~xi

let combine_split_commitments _t ~scale_and_add ~init:i ~xi
    ~reduce_without_degree_bound ~reduce_with_degree_bound (type n)
    (without_degree_bound : (_, n) Vector.t) with_degree_bound =
  let flat =
    List.concat_map
      (Vector.to_list without_degree_bound)
      ~f:reduce_without_degree_bound
    @ List.concat_map
        (Vector.to_list with_degree_bound)
        ~f:reduce_with_degree_bound
  in
  let rec go = function
    | [] ->
        failwith "combine_split_commitments: empty"
    | init :: comms -> (
        match i init with
        | None ->
            go comms
        | Some init ->
            List.fold_left comms ~init ~f:(fun acc p ->
                scale_and_add ~acc ~xi p ) )
  in
  go (List.rev flat)

let combine_split_evaluations (type f f')
    ~(mul_and_add : acc:f' -> xi:f' -> f -> f') ~init:(i : f -> f') ~(xi : f')
    (evals0 : f array list) : f' =
  let flat = List.concat_map evals0 ~f:Array.to_list in
  match List.rev flat with
  | [] ->
      failwith "combine_split_evaluations: empty"
  | init :: es ->
      List.fold_left es ~init:(i init) ~f:(fun acc fx ->
          mul_and_add ~acc ~xi fx )
