open Core
open Mina_base

let%test_module "Discarding catchup nodes when the root moves" =
  ( module struct
    let hash name =
      Quickcheck.random_value ~seed:(`Deterministic name) State_hash.gen

    let%test_unit "Only the blocks that left, and their descendants, end" =
      let r = hash "previous root"
      and a = hash "new root"
      and b = hash "discarded sibling"
      and c = hash "below the sibling"
      and d = hash "below that"
      and e = hash "below the new root"
      and f = hash "below a block not in the tree"
      and x = hash "a block not in the tree"
      and before_r = hash "the previous root's parent" in
      let parents =
        [ (r, before_r); (a, r); (b, r); (c, b); (d, c); (e, a); (f, x) ]
      in
      [%test_eq: State_hash.t list]
        ( Transition_frontier.Full_catchup_tree.discarded ~parents ~new_root:a
            ~left:[ r; b ]
        |> List.sort ~compare:State_hash.compare )
        (List.sort [ r; b; c; d ] ~compare:State_hash.compare)
  end )
