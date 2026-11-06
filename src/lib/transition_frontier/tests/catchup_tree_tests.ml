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

    (* Nothing these tests remove holds a block. *)
    let release = { Tree.release = (fun _ -> ()) }

    let hash name =
      Quickcheck.random_value ~seed:(`Deterministic name) State_hash.gen

    let downloading_node h ~parent : Tree.Node.t =
      let length = Mina_numbers.Length.zero in
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

    let downloading (t : Tree.t) h ~parent =
      let node = downloading_node h ~parent in
      Tree.add_state t.states node ;
      Hashtbl.add_exn t.nodes ~key:h ~data:node ;
      node

    let%test_unit "A block without a node is not tracked" =
      let t = Tree.create ~logger:(Logger.null ()) ~release in
      Tree.block_added t (hash "added") ;
      [%test_eq: int] (Hashtbl.length t.nodes) 0

    let%test_unit "The node for an added block leaves the tree, added" =
      let t = Tree.create ~logger:(Logger.null ()) ~release in
      let node = downloading t (hash "added") ~parent:(hash "parent") in
      let (_ : Tree.Node.t) =
        downloading t (hash "child") ~parent:(hash "added")
      in
      Tree.block_added t (hash "added") ;
      [%test_eq: State_hash.t list] (Hashtbl.keys t.nodes) [ hash "child" ] ;
      [%test_eq: int]
        (Hashtbl.fold t.states ~init:0 ~f:(fun ~key:_ ~data n ->
             n + Set.length data ) )
        1 ;
      assert (
        match Async_kernel.Ivar.peek node.result with
        | Some (Ok `Added_to_frontier) ->
            true
        | Some (Error _) | None ->
            false )

    let%test_unit "A replaced node's waiters get its replacement's result" =
      let t = Tree.create ~logger:(Logger.null ()) ~release in
      let replaced = downloading t (hash "block") ~parent:(hash "parent") in
      let replacement =
        downloading_node (hash "block") ~parent:(hash "parent")
      in
      Tree.add_node t replacement ;
      assert (Tree.is_current t replacement) ;
      assert (not (Tree.is_current t replaced)) ;
      [%test_eq: int]
        (Hashtbl.fold t.states ~init:0 ~f:(fun ~key:_ ~data n ->
             n + Set.length data ) )
        1 ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%map.Async_kernel.Deferred () =
            Async_kernel.Ivar.fill replacement.result (Ok `Added_to_frontier) ;
            Async.Scheduler.yield_until_no_jobs_remain ()
          in
          assert (
            match Async_kernel.Ivar.peek replaced.result with
            | Some (Ok `Added_to_frontier) ->
                true
            | Some (Error _) | None ->
                false ) )
  end )
