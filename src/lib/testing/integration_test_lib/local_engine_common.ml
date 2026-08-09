open Core

(** Shared constants and node operations for the host-local test engines. *)

(** Fixed libp2p identity for the seed node. The [peer_id] MUST correspond to
    [libp2p_keypair]. *)
module Seed = struct
  let peer_id = "12D3KooWMg66eGtSEx5UZ9EAqEp3W7JaGd6WTxdRFuqhskRN55dT"

  let libp2p_keypair =
    {|{"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"7Bbvv2wZ6iCeqVyooU9WR81aygshMrLdXKieaHT","pwsalt":"Bh1WborqSwdzBi7m95iZdrCGspSf","pwdiff":[134217728,6],"ciphertext":"8fgvt4eKSzF5HMr1uEZARVHBoMgDKTx17zV7STVQyhyyEz1SqdH4RrU51MFGMPZJXNznLfz8RnSPsjrVqhc1CenfSLLWP5h7tTn86NbGmzkshCNvUiGEoSb2CrSLsvJsdn13ey9ibbZfdeXyDp9y6mKWYVmefAQLWUC1Kydj4f4yFwCJySEttAhB57647ewBRicTjdpv948MjdAVNf1tTxms4VYg4Jb3pLVeGAPaRtW5QHUkA8LwN5fh3fmaFk1mRudMd67UzGdzrVBeEHAp4zCnN7g2iVdWNmwN3"}|}
end

(** Environment variables every locally-spawned mina node needs. *)
let node_env_vars =
  [ ("RAYON_NUM_THREADS", "8")
  ; ("MINA_PRIVKEY_PASS", "naughty blue worm")
  ; ("MINA_LIBP2P_PASS", "")
  ]

(** A short random lowercase id, used to keep node/service and database names
    unique across concurrent runs. Shared by both engines. *)
let generate_random_id () =
  let rand_char () =
    let ascii_a = int_of_char 'a' in
    let ascii_z = int_of_char 'z' in
    char_of_int (ascii_a + Random.int (ascii_z - ascii_a + 1))
  in
  String.init 4 ~f:(fun _ -> rand_char ())

(** Enforce that every named node in a test has a distinct name. Shared by both
    engines' [Network_config.expand]. *)
let validate_unique_node_names (test_config : Test_config.t) =
  let names =
    List.map test_config.block_producers
      ~f:(fun (bp : Test_config.Block_producer_node.t) -> bp.node_name)
    @
    match test_config.snark_coordinator with
    | None ->
        []
    | Some (sc : Test_config.Snark_coordinator_node.t) ->
        [ sc.node_name ]
  in
  if List.contains_dup ~compare:String.compare names then
    failwith
      "All nodes in testnet must have unique names.  Check to make sure you \
       are not using the same node_name more than once"

module Ops = struct
  (** [run ~prog ~args] executes a command and returns its stdout, hard-erroring
      on failure. *)
  type run = prog:string -> args:string list -> string Malleable_error.t

  (** [write_file ~contents ~dest] writes [contents] to [dest]. *)
  type write_file = contents:string -> dest:string -> unit Malleable_error.t

  let dump_archive_data ~(run : run) ~logger ~service_name ~postgres_uri
      ~data_file =
    let open Malleable_error.Let_syntax in
    [%log info] "Dumping archive data from (node: %s)" service_name ;
    let%map data =
      run ~prog:"pg_dump" ~args:[ "--create"; "--no-owner"; postgres_uri ]
    in
    [%log info] "Dumping archive data to file %s" data_file ;
    Out_channel.with_file data_file ~f:(fun out_ch ->
        Out_channel.output_string out_ch data )

  let run_replayer ~(run : run) ~(write_file : write_file) ~logger ~service_name
      ~runtime_config_path ~replayer_input_dest ~postgres_uri
      ?(start_slot_since_genesis = 0) ?target_state_hash () =
    let open Malleable_error.Let_syntax in
    [%log info] "Running replayer on (node: %s)" service_name ;
    let%bind accounts =
      run ~prog:"jq" ~args:[ "-c"; ".ledger.accounts"; runtime_config_path ]
    in
    let target_hash_json =
      match target_state_hash with
      | None ->
          ""
      | Some hash ->
          sprintf {|, "target_epoch_ledgers_state_hash": "%s"|}
            (Mina_base.State_hash.to_base58_check hash)
    in
    let replayer_input =
      sprintf
        {| { "start_slot_since_genesis": %d,
             "genesis_ledger": { "accounts": %s, "add_genesis_winner": true }%s} |}
        start_slot_since_genesis accounts target_hash_json
    in
    let%bind () =
      write_file ~contents:replayer_input ~dest:replayer_input_dest
    in
    run ~prog:"mina-replayer"
      ~args:
        [ "--archive-uri"
        ; postgres_uri
        ; "--input-file"
        ; replayer_input_dest
        ; "--output-file"
        ; "/dev/null"
        ; "--log-json"
        ; "--continue-on-error"
        ]

  (* [dump_precomputed_blocks_from_logs ~logger ~service_name ~logs] parses a
     node's [logs] for precomputed blocks and writes each one to a
     [<state_hash>.json] file in the current directory. The two engines fetch
     [logs] differently (docker container logs vs. the native node's log file),
     but the parsing and file-writing are identical, so they share this. *)
  let dump_precomputed_blocks_from_logs ~logger ~service_name ~logs =
    let open Async in
    [%log info] "Extracting precomputed blocks from logs for (node: %s)"
      service_name ;
    (* Node logs may include non-JSON output; keep only structured log lines. *)
    let log_lines =
      String.split logs ~on:'\n'
      |> List.filter ~f:(String.is_prefix ~prefix:{|{"timestamp":|})
    in
    let metadata_jsons =
      List.map log_lines ~f:(fun line ->
          let json = Yojson.Safe.from_string line in
          match Yojson.Safe.Util.member "metadata" json with
          | `Null ->
              failwithf "Log line is missing metadata: %s"
                (Yojson.Safe.to_string json)
                ()
          | md ->
              md )
    in
    let state_hash_and_blocks =
      List.fold metadata_jsons ~init:[] ~f:(fun acc json ->
          match Yojson.Safe.Util.member "precomputed_block" json with
          | `Null ->
              acc
          | block -> (
              match Yojson.Safe.Util.member "state_hash" json with
              | `Null ->
                  failwith
                    "Log metadata contains a precomputed block, but no state \
                     hash"
              | state_hash ->
                  (state_hash, block) :: acc ) )
    in
    let%bind.Deferred () =
      Deferred.List.iter state_hash_and_blocks
        ~f:(fun (state_hash_json, block_json) ->
          let state_hash = Yojson.Safe.Util.to_string state_hash_json in
          let block = Yojson.Safe.pretty_to_string block_json in
          let filename = state_hash ^ ".json" in
          match%map.Deferred Sys.file_exists filename with
          | `Yes ->
              [%log info]
                "File already exists for precomputed block with state hash %s"
                state_hash
          | _ ->
              [%log info]
                "Dumping precomputed block with state hash %s to file %s"
                state_hash filename ;
              Out_channel.with_file filename ~f:(fun out_ch ->
                  Out_channel.output_string out_ch block ) )
    in
    Malleable_error.return ()
end
