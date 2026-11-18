open Core_kernel
open Async_kernel
open Cache_lib
open Mina_base
module Full_catchup_tree = Transition_frontier.Full_catchup_tree

let%test_module "Full_catchup_tree" =
  ( module struct
    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    (* The genesis block, validated as far as a block whose breadcrumb is being
       built is. *)
    let almost_valid_block =
      Mina_block.genesis ~precomputed_values
      |> Mina_block.Validation.reset_staged_ledger_diff_validation

    let state_hash =
      State_hash.With_state_hashes.state_hash
        (Mina_block.Validation.block_with_hash almost_valid_block)

    (* The block as the catchup state machine holds it, registered in a cache. *)
    let cached_block () =
      let cache =
        Cache.create ~name:"test" ~logger ~cache_exceptions:false ~on_add:ignore
          ~on_remove:(fun _ _ -> ())
          ~element_to_string:State_hash.to_base58_check
          (module State_hash)
      in
      Cache.register_exn cache state_hash
      |> Cached.transform ~f:(fun _ ->
             Network_peer.Envelope.Incoming.local almost_valid_block )

    (* A catchup tree holding just the node for [cached], waiting on its
       breadcrumb to be built, as the catchup state machine leaves it. *)
    let tree_building cached =
      let t : Full_catchup_tree.t =
        { nodes = State_hash.Table.create ()
        ; states = Full_catchup_tree.Node.State.Enum.Table.create ()
        ; logger
        }
      in
      let node : Full_catchup_tree.Node.t =
        { state = To_build_breadcrumb (`Parent State_hash.dummy, cached, None)
        ; attempts = Full_catchup_tree.Attempt_history.empty
        ; state_hash
        ; blockchain_length = Mina_numbers.Length.zero
        ; parent = State_hash.dummy
        ; result = Ivar.create ()
        }
      in
      Full_catchup_tree.add_state t.states node ;
      Hashtbl.set t.nodes ~key:state_hash ~data:node ;
      (t, node)

    let%test_unit "Clearing the tree leaves a handed-off breadcrumb to the \
                   transition processor" =
      let cached = cached_block () in
      let t, node = tree_building cached in
      (* As the catchup state machine does once the breadcrumb is built, before
         writing it to the transition processor. *)
      let handed_off = Cached.transform cached ~f:(fun _ -> ()) in
      Full_catchup_tree.clear t ;
      assert (Ivar.is_full node.result) ;
      assert (not (Ivar.is_full (Cached.final_state handed_off))) ;
      (* As the transition processor does with the breadcrumb. *)
      Cached.peek handed_off ;
      Cached.invalidate_with_success handed_off

    let%test_unit "Clearing the tree invalidates a block whose breadcrumb is \
                   still being built" =
      let cached = cached_block () in
      let t, node = tree_building cached in
      Full_catchup_tree.clear t ;
      assert (Ivar.is_full node.result) ;
      match Ivar.peek (Cached.final_state cached) with
      | Some `Failed ->
          ()
      | Some (`Success _) ->
          failwith "The block was finalized as a success"
      | None ->
          failwith "The block wasn't finalized"
  end )
