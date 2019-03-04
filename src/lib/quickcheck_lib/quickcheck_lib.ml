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

let gen_imperative_rose_tree ?(p = 0.75) (root_gen : 'a t)
    (node_gen : ('a -> 'a) t) =
  let%bind root = root_gen in
  imperative_fixed_point root ~f:(fun self ->
      match%bind size with
      | 0 -> failwith "there is no rose tree of size 0"
      | 1 ->
          let%map this = node_gen in
          fun parent -> Rose_tree.T (this parent, [])
      | n ->
          let%bind this = node_gen in
          let%bind fork_count = geometric ~p 1 >>| Int.max n in
          let%bind fork_sizes = gen_division (n - 1) fork_count in
          let positive_fork_sizes =
            List.filter fork_sizes ~f:(fun s -> s > 0)
          in
          let%map forks =
            map_gens positive_fork_sizes ~f:(fun s -> with_size ~size:s self)
          in
          fun parent ->
            let x = this parent in
            Rose_tree.T (x, List.map forks ~f:(fun f -> f x)) )

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

let gen_imperative_list (root_gen : 'a t) (node_gen : ('a -> 'a) t) =
  let%bind root = root_gen in
  imperative_fixed_point root ~f:(fun self ->
      match%bind size with
      | 0 -> return (fun _ -> [])
      | n ->
          let%bind this = node_gen in
          let%map f = with_size ~size:(n - 1) self in
          fun parent ->
            let x = this parent in
            x :: f x )

let%test_module "Quickcheck lib tests" =
  ( module struct
    let%test_unit "gen_imperative_list" =
      let increment = ( + ) 2 in
      let root_gen = Int.gen_incl 0 100 in
      let gen =
        Int.gen_incl 2 100
        >>= fun size ->
        Quickcheck.Generator.with_size ~size
          (gen_imperative_list root_gen (return increment))
      in
      Quickcheck.test gen ~f:(fun list ->
          match list with
          | [] -> failwith "We assume that our list has at least one element"
          | x :: xs ->
              let result =
                List.fold_result xs ~init:x ~f:(fun elem next_elem ->
                    if next_elem = increment elem then Result.return next_elem
                    else
                      Or_error.errorf
                        !"elements do not add up correctly %d %d"
                        elem next_elem )
              in
              assert (Result.is_ok result) )
  end )
