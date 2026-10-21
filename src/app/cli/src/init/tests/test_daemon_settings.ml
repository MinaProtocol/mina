(* Tests of daemon-setting resolution. These pin its existing behaviour,
   including the quirks (port keys keeping their flag's dashes, overridden
   values not being decoded). *)

open Core
open Init

let logger = Logger.null ()

let compile_config = Mina_compile_config.of_node_config (module Node_config)

let parse_flags args =
  let result = ref None in
  Command.run ~argv:("test" :: args)
    (Command.basic ~summary:"test"
       (Command.Param.map
          (Daemon_flags.param ~itn_features:false
             ~default_snark_worker_fee:compile_config.default_snark_worker_fee )
          ~f:(fun flags () -> result := Some flags) ) ) ;
  Option.value_exn !result

(** [files] are (name, [daemon] section) pairs, earliest-read first. *)
let daemon_file files =
  Daemon_file.of_config_jsons
    (List.map files ~f:(fun (name, daemon) ->
         (name, `Assoc [ ("daemon", Yojson.Safe.from_string daemon) ]) ) )

let resolve ?(files = []) args =
  Daemon_settings.Ports_and_work.resolve ~logger ~compile_config
    (daemon_file files) (parse_flags args)

let public_key () =
  Signature_lib.(Public_key.compress (Keypair.create ()).public_key)

let raises_user_error f =
  match f () with
  | _ ->
      Alcotest.fail "expected Mina_user_error"
  | exception Mina_stdlib.Mina_user_error.Mina_user_error _ ->
      ()

let test_defaults () =
  let r = resolve [] in
  Alcotest.(check int) "libp2p port" 8302 r.libp2p_port ;
  Alcotest.(check int) "client port" 8301 r.client_port ;
  Alcotest.(check int) "rest port" 3085 r.rest_server_port ;
  Alcotest.(check (option int)) "limited graphql" None r.limited_graphql_port ;
  Alcotest.(check bool)
    "fee" true
    (Currency.Fee.equal r.snark_work_fee_flag
       compile_config.default_snark_worker_fee ) ;
  Alcotest.(check bool)
    "work selection" true
    (match r.work_selection_method with Random -> true | _ -> false) ;
  Alcotest.(check int)
    "reassignment wait" Cli_lib.Default.work_reassignment_wait
    r.work_reassignment_wait ;
  Alcotest.(check bool) "log block creation" true r.log_block_creation ;
  Alcotest.(check bool) "log txn gossip" false r.log_transaction_pool_diff ;
  Alcotest.(check bool)
    "snark worker" true
    (Option.is_none r.run_snark_worker_flag)

let test_flag_beats_config () =
  let r =
    resolve ~files:[ ("a", {|{"--client-port": 2}|}) ] [ "--client-port"; "1" ]
  in
  Alcotest.(check int) "client port" 1 r.client_port

(* The port keys are the flags' names, leading dashes included. *)
let test_port_keys_are_dashed_flag_names () =
  let r = resolve ~files:[ ("a", {|{"--client-port": 2}|}) ] [] in
  Alcotest.(check int) "--client-port" 2 r.client_port ;
  let r = resolve ~files:[ ("a", {|{"client-port": 2}|}) ] [] in
  Alcotest.(check int) "client-port is ignored" 8301 r.client_port

let test_latest_file_wins () =
  let r =
    resolve
      ~files:
        [ ("a", {|{"work-reassignment-wait": 1}|})
        ; ("b", {|{"work-reassignment-wait": 2}|})
        ]
      []
  in
  Alcotest.(check int) "reassignment wait" 2 r.work_reassignment_wait

let test_null_falls_through () =
  let r =
    resolve
      ~files:
        [ ("a", {|{"work-reassignment-wait": 1}|})
        ; ("b", {|{"work-reassignment-wait": null}|})
        ]
      []
  in
  Alcotest.(check int) "reassignment wait" 1 r.work_reassignment_wait

(* A value of the wrong type does not fall through: it is a configuration
   error. *)
let test_wrong_type_is_user_error () =
  raises_user_error (fun () ->
      resolve
        ~files:
          [ ("a", {|{"work-reassignment-wait": 1}|})
          ; ("b", {|{"work-reassignment-wait": "2"}|})
          ]
        [] ) ;
  raises_user_error (fun () ->
      resolve ~files:[ ("a", {|{"work-selection": 5}|}) ] [] ) ;
  raises_user_error (fun () ->
      resolve ~files:[ ("a", {|{"snark-worker-fee": -1}|}) ] [] )

let test_work_selection () =
  let r = resolve ~files:[ ("a", {|{"work-selection": "seq"}|}) ] [] in
  Alcotest.(check bool)
    "seq" true
    (match r.work_selection_method with Sequence -> true | _ -> false)

let test_bad_public_key_is_user_error () =
  raises_user_error (fun () ->
      resolve ~files:[ ("a", {|{"run-snark-worker": "not-a-key"}|}) ] [] )

(* A config value overridden by its flag is never decoded. *)
let test_overridden_value_not_decoded () =
  let pk = public_key () in
  let r =
    resolve
      ~files:[ ("a", {|{"run-snark-worker": "not-a-key"}|}) ]
      [ "--run-snark-worker"
      ; Signature_lib.Public_key.Compressed.to_base58_check pk
      ]
  in
  Alcotest.(check bool)
    "snark worker" true
    (Option.equal Signature_lib.Public_key.Compressed.equal (Some pk)
       r.run_snark_worker_flag )

let resolve_block_producer ?(files = []) args =
  Daemon_settings.Block_producer.resolve ~logger (daemon_file files)
    (parse_flags args)

let test_block_producer_defaults () =
  let r = resolve_block_producer [] in
  Alcotest.(check (option string)) "key" None r.block_production_key ;
  Alcotest.(check bool) "pubkey" true (Option.is_none r.block_production_pubkey) ;
  Alcotest.(check (option string)) "password" None r.block_production_password

let test_block_producer_from_config () =
  let pk = public_key () in
  let r =
    resolve_block_producer
      ~files:
        [ ( "a"
          , sprintf
              {|{"block-producer-key": "a-key", "block-producer-pubkey": "%s",
                 "block-producer-password": "pw"}|}
              (Signature_lib.Public_key.Compressed.to_base58_check pk) )
        ]
      []
  in
  Alcotest.(check (option string)) "key" (Some "a-key") r.block_production_key ;
  Alcotest.(check bool)
    "pubkey" true
    (Option.equal Signature_lib.Public_key.Compressed.equal (Some pk)
       r.block_production_pubkey ) ;
  Alcotest.(check (option string))
    "password" (Some "pw") r.block_production_password

let test_block_producer_flag_beats_config () =
  let r =
    resolve_block_producer
      ~files:[ ("a", {|{"block-producer-key": "file-key"}|}) ]
      [ "--block-producer-key"; "flag-key" ]
  in
  Alcotest.(check (option string))
    "key" (Some "flag-key") r.block_production_key

let test_block_producer_bad_pubkey_is_user_error () =
  raises_user_error (fun () ->
      resolve_block_producer
        ~files:[ ("a", {|{"block-producer-pubkey": "not-a-key"}|}) ]
        [] )

let keypair_source ?env_private_key ?key ?pubkey () =
  Daemon_settings.Block_producer.keypair_source ~env_private_key
    { block_production_key = key
    ; block_production_pubkey = pubkey
    ; block_production_password = None
    }

let source_name : Daemon_settings.Block_producer.keypair_source -> string =
  function
  | No_block_producer ->
      "none"
  | Env_private_key s ->
      "env " ^ s
  | Key_file s ->
      "file " ^ s
  | Tracked_pubkey _ ->
      "tracked"

let check_source name expected source =
  Alcotest.(check string) name expected (source_name source)

let test_keypair_source () =
  let pubkey = public_key () in
  check_source "nothing" "none" (keypair_source ()) ;
  check_source "env" "env sk" (keypair_source ~env_private_key:"sk" ()) ;
  check_source "file" "file f" (keypair_source ~key:"f" ()) ;
  check_source "tracked" "tracked" (keypair_source ~pubkey ())

(* The key file takes precedence over MINA_BP_PRIVKEY. *)
let test_key_file_beats_env () =
  check_source "file" "file f"
    (keypair_source ~env_private_key:"sk" ~key:"f" ())

let test_conflicting_sources_are_user_errors () =
  let pubkey = public_key () in
  raises_user_error (fun () -> keypair_source ~key:"f" ~pubkey ()) ;
  raises_user_error (fun () ->
      keypair_source ~env_private_key:"sk" ~key:"f" ~pubkey () ) ;
  raises_user_error (fun () -> keypair_source ~env_private_key:"sk" ~pubkey ())

(* MINA_BP_PRIVKEY is not decoded here: an invalid key is only rejected when
   the keypair is loaded. *)
let test_env_private_key_not_decoded () =
  check_source "env" "env not-a-key"
    (keypair_source ~env_private_key:"not-a-key" ())

let () =
  Alcotest.run "Daemon_settings"
    [ ( "Ports_and_work"
      , [ Alcotest.test_case "defaults" `Quick test_defaults
        ; Alcotest.test_case "flag beats config" `Quick test_flag_beats_config
        ; Alcotest.test_case "port keys are dashed flag names" `Quick
            test_port_keys_are_dashed_flag_names
        ; Alcotest.test_case "latest file wins" `Quick test_latest_file_wins
        ; Alcotest.test_case "null falls through" `Quick test_null_falls_through
        ; Alcotest.test_case "wrong type is a user error" `Quick
            test_wrong_type_is_user_error
        ; Alcotest.test_case "work selection" `Quick test_work_selection
        ; Alcotest.test_case "bad public key is a user error" `Quick
            test_bad_public_key_is_user_error
        ; Alcotest.test_case "overridden value not decoded" `Quick
            test_overridden_value_not_decoded
        ] )
    ; ( "Block_producer"
      , [ Alcotest.test_case "defaults" `Quick test_block_producer_defaults
        ; Alcotest.test_case "from config" `Quick
            test_block_producer_from_config
        ; Alcotest.test_case "flag beats config" `Quick
            test_block_producer_flag_beats_config
        ; Alcotest.test_case "bad pubkey is a user error" `Quick
            test_block_producer_bad_pubkey_is_user_error
        ; Alcotest.test_case "keypair source" `Quick test_keypair_source
        ; Alcotest.test_case "key file beats env" `Quick test_key_file_beats_env
        ; Alcotest.test_case "conflicting sources are user errors" `Quick
            test_conflicting_sources_are_user_errors
        ; Alcotest.test_case "env private key not decoded" `Quick
            test_env_private_key_not_decoded
        ] )
    ]
