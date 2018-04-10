open Core
open Async
open Nanobit_base
open Blockchain_snark

module Digest = Snark_params.Tick.Pedersen.Digest

;;
let dump_path_hashes ~tag (p : Blockchain.t list) =
  printf "Dumping %s:\n" tag;
  List.iter p ~f:(fun chain ->
    printf "%s, "
      (Md5.to_hex (Md5.digest_string (Sexp.to_string_hum ([%sexp_of: Digest.t] chain.state.block_hash))))
  );
  printf "\n"
;;

module Linked_blockchain = struct
  type elt =
    { edges : elt Digest.Table.t
    ; node : Blockchain.t
    }
  type t =
    { _roots : elt Digest.Table.t
    ; _all_nodes : elt Digest.Table.t
    }

  let create () =
    { _roots = Digest.Table.create ()
    ; _all_nodes = Digest.Table.create ()
    }

  let roots t =
    Digest.Table.data t._roots

  let all_nodes t =
    Digest.Table.data t._all_nodes

  let key n = n.node.state.block_hash

  let mutate_add t n ~is_root =
    let _ = Digest.Table.add ~key:(key n) ~data:n t._all_nodes in
    if is_root then
      let _ = Digest.Table.add ~key:(key n) ~data:n t._roots in ()
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
        List.map (roots t) (fun root ->
          (Digest.Table.data root.edges)
        )
      end
    ) ~f:go;
    (* Remove all the things that SHOULDNT be roots *)
    List.iter (Hash_set.to_list non_roots) ~f:(fun non_root ->
      Digest.Table.remove t._roots non_root
    )

  let _add t chain =
    let new_elt = singleton chain in
    mutate_add t new_elt ~is_root:true

  let reconnect t =
    fixup_roots t;
    (* N^2 but whatever, this is just a test *)
    List.iter (all_nodes t) ~f:(fun e ->
      List.iter (all_nodes t) ~f:(fun e' ->
        if needs_child ~parent:e ~child_candidate:e'.node then
          let _ = Digest.Table.add e.edges ~key:(key e') ~data:e' in
          ()
        else
          ()
      )
    )

  let add_all t chains =
    List.iter ~f:(_add t) chains;
    reconnect t

  let add t chain =
    _add t chain;
    reconnect t

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
        (List.map (roots t) ~f:(fun e -> go ([e.node], 1) e))
        compare_right
      |> Option.value ~default:([], 0)
    in
    match List.length p with
    | 0 | 1 ->
      dump_path_hashes ~tag:"roots" (List.map (roots t) ~f:(fun e -> e.node));
      dump_path_hashes ~tag:"all_nodes" (List.map (all_nodes t) ~f:(fun e -> e.node));
      p
    | _ -> p
end

module Nanobit_args = struct
  type t = 
    { nanobit: Nanobit_testbridge.Nanobit.t
    ; args: Nanobit_testbridge.Rpcs.Main.query
    }
end

let kill_nanobit0 alive_nanobits dead_nanobits =
  let nanobits = alive_nanobits in
  let to_kill = List.take nanobits 1 in
  printf "** Killing %s\n"
    (Sexp.to_string_hum
      ([%sexp_of: Host_and_port.t list]
        (List.map to_kill ~f:(fun n -> n.Nanobit_args.nanobit.Nanobit_testbridge.Nanobit.membership_addr))));
  let%map () = Deferred.List.iter to_kill ~f:(fun na -> Nanobit_testbridge.stop na.Nanobit_args.nanobit) in
  (List.drop nanobits 1, List.concat [ to_kill; dead_nanobits ])

let start_nanobit0 alive_nanobits dead_nanobits =
  let nanobits = dead_nanobits in
  let to_start = List.take nanobits 1 in
  printf "** Starting %s\n"
    (Sexp.to_string_hum
      ([%sexp_of: Host_and_port.t list]
        (List.map to_start ~f:(fun n -> n.Nanobit_args.nanobit.Nanobit_testbridge.Nanobit.membership_addr))));
  let%map () =
    Deferred.List.iter to_start ~f:(fun na -> 
      let%bind () = Nanobit_testbridge.start na.Nanobit_args.nanobit in
      Nanobit_testbridge.main na.nanobit na.args
    )
  in
  (List.concat [ to_start; alive_nanobits ], List.drop nanobits 1)

let main nanobits = 
  printf "host started: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Nanobit.t list] nanobits));
  printf "initing nanobits...\n";
  let%bind args = Nanobit_testbridge.run_main_fully_connected nanobits ~should_mine:true in
  printf "init'd nanobits: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Rpcs.Main.query list] args));
  printf "starting test\n";

  let alive_nanobits, dead_nanobits = 
    List.map2_exn nanobits args ~f:(fun nanobit args -> { Nanobit_args.nanobit; args }), [] 
  in

  let sca_length = ref 0 in

  let node0_down = ref false in

  don't_wait_for begin
    let rec go last_sca_length = 
      let%bind () = after (sec 45.) in
      let pass = !sca_length > last_sca_length in
      let () = 
        if not pass
        then printf "no new block in 45 seconds";
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

  (* Catch-up a node by transfering the Linked_blockchain prefix ending in
  * a root blockchain of the node_{idx} *)
  let resync idx (states : Linked_blockchain.t list) (new_chain : Blockchain.t) =
    printf "RESYNCING %d with %s (prior: %s)\n"
      idx
      (Md5.to_hex (Md5.digest_string (Sexp.to_string_hum ([%sexp_of: Digest.t] new_chain.state.block_hash))))
      (Md5.to_hex (Md5.digest_string (Sexp.to_string_hum ([%sexp_of: Digest.t] new_chain.most_recent_block.header.previous_block_hash))));

    let len = List.length states in
    let others =
      (List.slice states 0 idx) @
        (List.slice states (Int.min (idx+1) len) len)
    in
    (* All the deepest blockchain paths for the other nodes *)
    let other_paths =
      List.map others ~f:Linked_blockchain.deepest_path
    in
    (* The deepest most blockchain for each other node *)
    let deepest_tails =
      (List.map ~f:List.rev other_paths)
        |> List.map ~f:List.hd
    in
    (* Mask out which of the paths we can consider *)
    let lb = List.nth_exn states idx in
    let mask =
      List.map deepest_tails ~f:(fun tail_opt ->
        match tail_opt with
        | Some tail ->
          (* Either some other node also has this block *)
          Digest.(new_chain.state.block_hash = tail.state.block_hash) ||
          (* Or they ALMOST have this block *)
          Digest.(new_chain.most_recent_block.header.previous_block_hash =
              tail.state.block_hash)
        | None -> false
      )
    in
    (* Grab the longest path that meets the mask *)
    let best_path =
      List.map2_exn other_paths mask ~f:(fun p b ->
        if b then p else []
      ) |> List.max_elt ~cmp:(fun p p' -> Int.compare (List.length p) (List.length p'))
        |> Option.value_exn
    in

    let old_deepest = Linked_blockchain.deepest_path lb in
    Linked_blockchain.add_all lb best_path;
    let new_deepest = Linked_blockchain.deepest_path lb in
    printf "Length new:%d old:%d\n" (List.length new_deepest) (List.length old_deepest)
  in

  let update_chain states nanobit i (blockchain : Blockchain.t) =
    let () =
      if i = 0 then
        printf "NODE 0 got an update\n"
      else
        ()
    in
    printf "got blockchain idx:%d %s %s %s\n"
      i
      (Sexp.to_string_hum ([%sexp_of: Host_and_port.t] nanobit.Nanobit_testbridge.Nanobit.membership_addr))
      (Sexp.to_string_hum ([%sexp_of: Block.Body.t] blockchain.most_recent_block.body))
      (Md5.to_hex (Md5.digest_string (Sexp.to_string_hum ([%sexp_of: Digest.t] blockchain.state.block_hash))));
    let lb = List.nth_exn states i in
    Linked_blockchain.add lb blockchain;
    (* Sanity check -- make sure linked_blockchain isn't busted *)
    assert_connected (Linked_blockchain.deepest_path lb |> List.rev);
    (* We only care about the alive nodes' chains *)
    let adjusted_states = if !node0_down then (List.drop states 1) else states in
    if i = 0 then
      begin
        (* Maybe node0 is just catching up and only has the latest blockchain, catch it up *)
        resync 0 states blockchain;
        check_sca adjusted_states;
      end
    else
      check_sca adjusted_states
  in

  let states = List.init (List.length nanobits) ~f:(fun n -> Linked_blockchain.create ()) in
  let listen_for_blocks i nanobit =
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
  in

  don't_wait_for begin
    Deferred.List.iteri ~how:`Parallel nanobits ~f:listen_for_blocks
  end;

  (* Periodically kill and restart a random node *)
  don't_wait_for begin
    let rec go () : unit Deferred.t = 
      let%bind () = after (sec 20.) in
      node0_down := true;
      let%bind (alive_nanobits, dead_nanobits) = kill_nanobit0 alive_nanobits dead_nanobits in
      let%bind () = after (sec 10.) in
      let%bind (alive_nanobits, dead_nanobits) = start_nanobit0 alive_nanobits dead_nanobits in
      (* Start listening for blocks again now that we're alive *)
      don't_wait_for begin
        let alive_args : Nanobit_args.t = List.hd_exn alive_nanobits in
        listen_for_blocks 0 alive_args.nanobit
      end;
      (* Let the node "catch up" before we mark it as up *)
      let%bind () = after (sec 10.) in
      node0_down := false;
      go ()
    in
    go ()
  end;

  printf "done\n";
  Async.never ()
;;

let () = Nanobit_testbridge.cmd main
;;

let () = never_returns (Scheduler.go ())
;;
