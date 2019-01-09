open Core_kernel
open Quickcheck.Generator
open Quickcheck.Let_syntax

let rec map_gens ls ~f =
  match ls with
  | [] -> return []
  | h :: t ->
      let%bind h' = f h in
      let%map t' = map_gens t ~f in
      h' :: t'

let gen_pair g =
  let%map a = g and b = g in
  (a, b)

let rec gen_division n k =
  if k = 0 then return []
  else if k = 1 then return [n]
  else
    let maximum_value = max 0 (n - k) in
    let%bind h = Int.gen_incl (min 1 maximum_value) maximum_value in
    let%map t = gen_division (n - h) (k - 1) in
    h :: t

let imperative_fixed_point root ~f =
  let%map f' = fixed_point f in
  f' root

let gen_imperative_ktree ?(p = 0.75) (root_gen : 'a t)
    (node_gen : ('a -> 'a) t) =
  let%bind root = root_gen in
  imperative_fixed_point root ~f:(fun self ->
      match%bind size with
      | 0 -> return (fun _ -> [])
      (* this case is optional but more effecient *)
      | 1 ->
          let%map this = node_gen in
          fun parent -> [this parent]
      | n ->
          let%bind this = node_gen in
          let%bind fork_count = geometric ~p 1 >>| Int.max n in
          let%bind fork_sizes = gen_division (n - 1) fork_count in
          let%map forks =
            map_gens fork_sizes ~f:(fun s -> with_size ~size:s self)
          in
          fun parent ->
            let x = this parent in
            x :: List.bind forks ~f:(fun f -> f x) )
