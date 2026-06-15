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
end
