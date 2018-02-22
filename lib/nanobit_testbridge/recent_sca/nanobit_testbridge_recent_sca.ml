open Core
open Async
open Nanobit_base

module Digest = Snark_params.Tick.Pedersen.Digest
module Linked_blockchain = struct
  type elt =
    { edges : elt Digest.Table.t
    ; node : Blockchain.t
    }
  type t =
    { roots : elt Digest.Table.t
    ; all_nodes : elt Digest.Table.t
    }

  let create () =
    { roots = Digest.Table.create ()
    ; all_nodes = Digest.Table.create ()
    }

  let key n = Digest.Bits.to_bits n.node.state.block_hash

  let mutate_add t n ~is_root =
    let _ = Digest.Table.add ~key:(key n) ~data:n t.all_nodes in
    if is_root then
      let _ = Digest.Table.add ~key:(key n) ~data:n t.roots in ()
    else ()

  let singleton b = { edges = Digest.Table.create () ; node = b }

  let needs_child : parent:elt -> child_candidate:Blockchain.t -> bool =
    fun ~parent ~child_candidate ->
      Digest.(parent.node.most_recent_block.header.previous_block_hash = child_candidate.state.block_hash)

  let fixup_roots t =
    let non_roots = Digest.Hash_set.create () in
    let rec go (e : elt) =
      Hash_set.add non_roots (key e);
      List.iter (Digest.Table.data e.edges) ~f:go
    in
    List.iter (
      List.join begin
        List.map (Digest.Table.data t.roots) (fun root ->
          (Digest.Table.data root.edges)
        )
      end
    ) ~f:go;
    (* Remove all the things that SHOULDNT be roots *)
    List.iter (Hash_set.to_list non_roots) ~f:(fun non_root ->
      Digest.Table.remove t.roots non_root
    )

  let add t chain =
    (* First check if this chain is a child, if so we're done *)
    let is_done = List.exists (Digest.Table.data t.all_nodes) ~f:(fun parent_possibly ->
      if needs_child ~parent:parent_possibly ~child_candidate:chain then
        let new_elt = singleton chain in
        let _ = Digest.Table.add parent_possibly.edges ~key:(key new_elt) ~data:new_elt in
        mutate_add t new_elt ~is_root:false;
        true
      else
        false
    )
    in
    if is_done then
      ()
    else
      (* Then check if this chain has any children -- add it as a root regardless *)
      let new_elt = singleton chain in
      mutate_add t new_elt ~is_root:true;
      List.iter (Digest.Table.data t.all_nodes) ~f:(fun child_elt ->
        if needs_child ~parent:new_elt ~child_candidate:child_elt.node then
          let _ = Digest.Table.add new_elt.edges ~key:(key child_elt) ~data:child_elt in
          fixup_roots t
        else
          ()
      )

  let deepest_path t =
    let compare_right (_, r) (_, r') = Int.compare r r' in
    let rec go (acc, count) e =
      List.max_elt
        (List.map (Digest.Table.data e.edges) ~f:(fun e -> go (e.node::acc, count+1) e))
        compare_right
      |> Option.value ~default:(acc, count)
    in
    let p, _ =
      List.max_elt
        (List.map (Digest.Table.data t.roots) ~f:(fun e -> go ([e.node], 1) e))
        compare_right
      |> Option.value ~default:([], 0)
    in
    p
end

let main nanobits = 
  printf "host started: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Nanobit.t list] nanobits));
  printf "initing nanobits...\n";
  let%bind args = Nanobit_testbridge.run_main_fully_connected nanobits ~should_mine:true in
  printf "init'd nanobits: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Rpcs.Main.query list] args));
  printf "starting test\n";

  let sca_length = ref 0 in

  don't_wait_for begin
    let rec go last_sca_length = 
      let%bind () = after (sec 30.) in
      let pass = !sca_length > last_sca_length in
      let () = 
        if not pass
        then printf "no new block in 30 seconds";
      in
      assert pass;
      go !sca_length
    in
    go !sca_length
  end;

  let check_sca (chains : Linked_blockchain.t list) =
    let by_length l l' =
      let by_len = List.length in
      Int.compare (by_len l) (by_len l')
    in
    let dump_path_hashes ~tag (p : Blockchain.t list) =
      printf "Dumping %s:\n" tag;
      List.iter p ~f:(fun chain ->
        printf "%s, "
          (Md5.to_hex (Md5.digest_string (Sexp.to_string_hum ([%sexp_of: Digest.t] chain.state.block_hash))))
      );
      printf "\n"
    in
    let shortest_path =
      Option.value_exn begin
        List.min_elt
          (chains |>
            List.map ~f:Linked_blockchain.deepest_path)
          by_length
      end
    in
    let shortest_path_len = List.length shortest_path in
    printf "Shortest path len: %d\n" shortest_path_len;
    dump_path_hashes ~tag:"shortest_path" shortest_path;
    if List.length shortest_path < 1
    then ()
    else 
      let longest_path = 
        Option.value_exn begin
          List.max_elt
            (chains |>
              List.map ~f:Linked_blockchain.deepest_path)
            by_length
        end
      in
      let longest_path_len = List.length longest_path in
      printf "Longest path len: %d\n" longest_path_len;
      dump_path_hashes ~tag:"longest_path" longest_path;

      let oldest_to_newest = List.zip_exn
        shortest_path
        (longest_path |> Fn.flip List.take (List.length shortest_path))
      in
      let newest_match =
        (List.findi oldest_to_newest ~f:(fun idx (s, l) ->
            not Digest.(s.state.block_hash = l.state.block_hash)
        )) |> Option.map ~f:(fun (idx, _) -> idx)
          |> Option.value ~default:shortest_path_len
      in
      let ancestor_age = longest_path_len - newest_match in
      let pass = ancestor_age < 4 in
      sca_length := newest_match;
      printf "got blockchain longest_path:%d shortest_path:%d anc_age:%d newest_match:%d pass:%b\n" longest_path_len shortest_path_len ancestor_age newest_match pass;
      assert pass
  in

  let assert_connected (chain : Blockchain.t list) =
    let rec go current_hash (chain : Blockchain.t list) =
      match (current_hash, chain) with
      | _, [] -> ()
      | Some h, blockchain::rest ->
          assert Digest.(blockchain.state.block_hash = h);
          go (Some blockchain.most_recent_block.header.previous_block_hash) rest
      | None, blockchain::rest ->
          go (Some blockchain.most_recent_block.header.previous_block_hash) rest
    in
    go None chain
  in

  let update_chain states nanobit i (blockchain : Blockchain.t) =
    printf "got blockchain %s %s %s\n"
      (Sexp.to_string_hum ([%sexp_of: Host_and_port.t] nanobit.Nanobit_testbridge.Nanobit.swim_addr))
      (Sexp.to_string_hum ([%sexp_of: Int64.t] blockchain.most_recent_block.body))
      (Md5.to_hex (Md5.digest_string (Sexp.to_string_hum ([%sexp_of: Digest.t] blockchain.state.block_hash))));
    let lb = List.nth_exn states i in
    Linked_blockchain.add lb blockchain;
    (* Sanity check -- make sure linked_blockchain isn't busted *)
    assert_connected (Linked_blockchain.deepest_path lb |> List.rev);
    check_sca states;
  in

  don't_wait_for begin
    let states = List.init (List.length nanobits) ~f:(fun n -> Linked_blockchain.create ()) in
    Deferred.List.iteri ~how:`Parallel nanobits
      ~f:(fun i nanobit ->
        Deferred.ignore begin
          Nanobit_testbridge.get_strongest_blocks 
            nanobit
            ~f:(fun pipe -> 
              let%map () = 
                Pipe.iter_without_pushback pipe ~f:(update_chain states nanobit i)
              in
              Ok ()
            )
        end
      )
  end;

  printf "done\n";
  Async.never ()
;;

let () = Nanobit_testbridge.cmd main
;;

let () = never_returns (Scheduler.go ())
;;
