(* fork-candidate last-filled-block: the last block with internal commands on
   the chain ending at the tip, not the highest such block of the archive. *)

open Core
open Async
open Archive_hardfork_toolbox_lib
module B = Synthetic_archive

(* genesis - a - fork - e1 - e2 (tip): the best chain, empty after [fork].
                \- sibling - sibling_child: an orphaned branch with coinbases,
                   one block higher than [fork]. *)
let scenario () =
  let s = B.create () in
  let producer = B.account s "producer" in
  let block ?parent name height = B.block s ?parent ~name ~height B.Pending in
  let filled ?parent name height =
    let b = block ?parent name height in
    ignore
      (B.coinbase s ~name:(name ^ "_coinbase") ~receiver:producer b : B.coinbase) ;
    b
  in
  let genesis = filled "genesis" 1 in
  let a = filled ~parent:genesis "a" 2 in
  let fork = filled ~parent:a "fork" 3 in
  let sibling = filled ~parent:a "sibling" 3 in
  let sibling_child = filled ~parent:sibling "sibling_child" 4 in
  let e1 = block ~parent:fork "e1" 4 in
  let (_ : B.block) = block ~parent:e1 "e2" 5 in
  (s, fork, sibling_child)

let last_filled_block (db : B.Db.t) ?latest_state_hash () =
  Logic.last_filled_block ~postgres_uri:db.uri ?latest_state_hash ()
  |> Deferred.map ~f:(fun (hash, slot, height) ->
         Ok (hash, (Int64.to_int_exn slot, height)) )

(* (state hash, (slot, height)); slots are [height - 1] in the scenario. *)
let expected b ~height = (B.state_hash b, (height - 1, height))

let block = Alcotest.(pair string (pair int int))

let ignores_orphaned_branches server_uri () =
  let s, fork, sibling_child = scenario () in
  B.Db.with_fresh ~server_uri ~name:"test_toolbox_last_filled_block" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind (_ : B.built) = B.materialize s db in
      let%bind found = last_filled_block db () in
      Alcotest.check block "from the highest block" (expected fork ~height:3)
        found ;
      let%map found =
        last_filled_block db ~latest_state_hash:(B.state_hash sibling_child) ()
      in
      Alcotest.check block "from a given tip"
        (expected sibling_child ~height:4)
        found )

let tests ~server_uri =
  let run f () =
    Thread_safe.block_on_async_exn (f server_uri) |> Or_error.ok_exn
  in
  [ ( "last_filled_block"
    , [ ("ignores orphaned branches", `Quick, run ignores_orphaned_branches) ]
    )
  ]
