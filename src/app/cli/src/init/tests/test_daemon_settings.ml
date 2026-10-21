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
  | (_ : Daemon_settings.Ports_and_work.t) ->
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
    ]
