(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- \
                  test '^merkle tree$'
    Subject:    Test Merkle trees.
 *)

open Core_kernel
open Snarky_backendless.Merkle_tree

(* Need comparison in order to test hash equality. This implementation
   does not really need to define a decent order on hashes; it's
   sufficient that two different hashes never compare as equal. *)
module Free_hash = struct
  include Free_hash

  let rec compare cmp =
    Tuple.T2.curry (function
      | Hash_empty, Hash_empty ->
          0
      | Hash_empty, _ ->
          -1
      | Hash_value l, Hash_value r ->
          cmp l r
      | Hash_value _, Hash_empty ->
          1
      | Hash_value _, Merge (_, _) ->
          -1
      | Merge (ll, lr), Merge (rl, rr) ->
          let l = compare cmp ll rl in
          if l = 0 then compare cmp lr rr else l
      | Merge (_, _), _ ->
          1 )
end

module Elem = struct
  include Int

  let gen = gen_incl min_value max_value
end

let merge x y = Free_hash.Merge (x, y)

let hash =
  Option.value_map ~default:Free_hash.Hash_empty ~f:(fun x ->
      Free_hash.Hash_value x )

let gen_tree =
  let open Quickcheck in
  let open Generator.Let_syntax in
  let%bind size = Int.gen_incl 0 255 in
  let%bind init_element = Elem.gen in
  let%map elements = Generator.list_with_length size Elem.gen in
  let tree = create ~hash ~merge init_element in
  (init_element :: elements, add_many tree elements)

let merkle_tree_isomorphic_to_list () =
  Quickcheck.test ~trials:10 gen_tree ~f:(fun (elements, tree) ->
      [%test_eq: Elem.t list] elements (to_list tree) )

let index_retrieval () =
  Quickcheck.test ~trials:10
    (let open Quickcheck.Generator.Let_syntax in
    let%bind elements, tree = gen_tree in
    let%map index = Int.gen_incl 0 (List.length elements - 1) in
    (index, List.nth_exn elements index, tree))
    ~f:(fun (index, elem, tree) ->
      [%test_eq: Elem.t option] (Some elem) (get tree index) )

let index_non_existent () =
  Quickcheck.test ~trials:10 gen_tree ~f:(fun (elements, tree) ->
      let size = List.length elements in
      [%test_eq: Elem.t option] None (get tree size) )

let merkle_root () =
  Quickcheck.test ~trials:10 gen_tree ~f:(fun (elements, tree) ->
      List.iteri elements ~f:(fun index element ->
          let path = get_path tree index in
          [%test_eq: Elem.t Free_hash.t]
            (implied_root ~merge index (hash (Some element)) path)
            (root tree) ) )
