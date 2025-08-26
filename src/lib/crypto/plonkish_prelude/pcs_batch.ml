open Core_kernel

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

let combine_split_commitments ~scale_and_add ~init:i ~xi
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
