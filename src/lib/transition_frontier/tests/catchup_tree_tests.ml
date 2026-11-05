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

let%test_module "Tracking the blocks the frontier adds" =
  ( module struct
    module Tree = Transition_frontier.Full_catchup_tree

    let hash name =
      Quickcheck.random_value ~seed:(`Deterministic name) State_hash.gen

    let downloading (t : Tree.t) h ~parent =
      let length = Mina_numbers.Length.zero in
      let node : Tree.Node.t =
        { state =
            To_download
              { Downloader.Job.key = (h, length)
              ; attempts = Tree.Attempt_history.empty
              ; res = Async_kernel.Ivar.create ()
              }
        ; attempts = Tree.Attempt_history.empty
        ; state_hash = h
        ; blockchain_length = length
        ; parent
        ; result = Async_kernel.Ivar.create ()
        }
      in
      Tree.add_state t.states node ;
      Hashtbl.add_exn t.nodes ~key:h ~data:node ;
      node

    let%test_unit "A block without a node is not tracked" =
      let t = Tree.create ~logger:(Logger.null ()) in
      Tree.block_added t (hash "added") ;
      [%test_eq: int] (Hashtbl.length t.nodes) 0

    let%test_unit "The node for an added block finishes" =
      let t = Tree.create ~logger:(Logger.null ()) in
      let node = downloading t (hash "added") ~parent:(hash "parent") in
      Tree.block_added t (hash "added") ;
      [%test_eq: Tree.Node.State.Enum.t]
        (Tree.Node.State.enum node.state)
        Finished ;
      assert (
        match Async_kernel.Ivar.peek node.result with
        | Some (Ok `Added_to_frontier) ->
            true
        | Some (Error _) | None ->
            false )
  end )
