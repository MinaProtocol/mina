open Core
open Async
open Mina_base
open Signature_lib

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let proof_level = Genesis_constants.Proof_level.Full

(* transform JSON into a string for a Javascript object,
   some special handling of cases where the GraphQL schema
   differs from OCaml code
*)
let jsobj_of_json ?(fee_payer = false) (json : Yojson.Safe.t) : string =
  let indent n = String.make n ' ' in
  let rec go json level =
    match json with
    | `Tuple _ | `Variant _ | `Intlit _ ->
        failwith "JSON not generated from OCaml"
    | `Bool b ->
        if b then "true" else "false"
    | `Null ->
        "null"
    (* special handling of sign in Currency.Amount.Signed.t *)
    | `Assoc [ ("magnitude", m); ("sgn", `List [ `String sgn ]) ] ->
        let sgn' =
          match sgn with
          | "Pos" ->
              "PLUS"
          | "Neg" ->
              "MINUS"
          | _ ->
              failwithf "Unexpected sign \"%s\" for currency amount" sgn ()
        in
        go (`Assoc [ ("magnitude", m); ("sign", `String sgn') ]) level
    | `Assoc pairs ->
        sprintf "{%s}"
          ( List.map pairs ~f:(fun (s, json) ->
                let cameled =
                  (* special handling for balance_change in Party.Fee_payer.t *)
                  if fee_payer && String.equal s "balance_change" then "fee"
                  else Mina_graphql.Reflection.underToCamel s
                in
                sprintf "%s:%s" cameled (go json (level + 2)))
          |> String.concat ~sep:(sprintf ",\n%s" (indent level)) )
    (* Set_or_keep *)
    | `List [ `String "Set"; v ] ->
        go v level
    | `List [ `String "Keep" ] ->
        "null"
    (* Check_or_ignore *)
    | `List [ `String "Check"; v ] ->
        go v level
    | `List [ `String "Ignore" ] ->
        "null"
    (* Predicate special handling *)
    | `List [ `String "Accept" ] ->
        go (`Assoc [ ("account", `Null); ("nonce", `Null) ]) level
    | `List [ `String "Nonce"; n ] ->
        go (`Assoc [ ("nonce", n) ]) level
    | `List [ `String "Full"; account ] ->
        go (`Assoc [ ("account", account) ]) level
    (* other constructors *)
    | `List [ `String name; value ] ->
        go (`Assoc [ (Mina_graphql.Reflection.underToCamel name, value) ]) level
    | `List jsons ->
        sprintf "[%s]"
          ( List.map jsons ~f:(fun json -> sprintf "%s" (go json (level + 2)))
          |> String.concat ~sep:(sprintf ",\n%s" (indent level)) )
    | `Int n ->
        sprintf "%d" n
    | `Float f ->
        sprintf "%f" f
    | `String s ->
        sprintf "\"%s\"" s
  in
  go json 4

let graphql_snapp_command (parties : Parties.t) =
  sprintf
    {|
mutation MyMutation {
  __typename
  sendSnapp(input: {
    feePayer:%s,
    otherParties:[%s] })
}
    |}
    ( jsobj_of_json ~fee_payer:true
    @@ Party.Fee_payer.to_yojson parties.fee_payer )
    ( List.map parties.other_parties ~f:(fun party ->
          Party.to_yojson party |> jsobj_of_json)
    |> String.concat ~sep:",\n    " )

let parse_field_element_or_hash_string s ~f =
  match Or_error.try_with (fun () -> Snark_params.Tick.Field.of_string s) with
  | Ok field ->
      f field
  | Error e1 -> (
      match Signed_command_memo.create_from_string s with
      | Ok memo ->
          Random_oracle.Legacy.(
            hash ~init:Hash_prefix.snapp_test
              ( Signed_command_memo.to_bits memo
              |> Random_oracle_input.Legacy.bitstring |> pack_input ))
          |> f
      | Error e2 ->
          failwith
            (sprintf
               "Neither a field element nor a suitable memo string: Errors \
                (%s, %s)"
               (Error.to_string_hum e1) (Error.to_string_hum e2)) )

let gen_proof ?(snapp_account = None) (parties : Parties.t) =
  let ledger = Ledger.create ~depth:constraint_constants.ledger_depth () in
  let _v =
    let id =
      parties.fee_payer.data.body.public_key
      |> fun pk -> Account_id.create pk Token_id.default
    in
    Ledger.get_or_create_account ledger id
      (Account.create id Currency.Balance.(of_int 1000000000000))
    |> Or_error.ok_exn
  in
  let _v =
    Option.value_map snapp_account ~default:() ~f:(fun (pk, vk) ->
        let id = Account_id.create pk Token_id.default in
        Ledger.get_or_create_account ledger id
          { (Account.create id Currency.Balance.(of_int 1000000000000)) with
            permissions =
              { Permissions.user_default with
                edit_state = Proof
              ; set_verification_key = Proof
              ; set_snapp_uri = Proof
              ; set_token_symbol = Proof
              }
          ; snapp =
              Some { Snapp_account.default with verification_key = Some vk }
          }
        |> Or_error.ok_exn |> ignore)
  in
  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:Genesis_constants.compiled.protocol
  in
  let state_body =
    let compile_time_genesis =
      (*not using Precomputed_values.for_unit_test because of dependency cycle*)
      Mina_state.Genesis_protocol_state.t
        ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
        ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
        ~constraint_constants ~consensus_constants
    in
    compile_time_genesis.data |> Mina_state.Protocol_state.body
  in
  let witnesses =
    Transaction_snark.parties_witnesses_exn ~constraint_constants ~state_body
      ~fee_excess:Currency.Amount.Signed.zero
      ~pending_coinbase_init_stack:Pending_coinbase.Stack.empty (`Ledger ledger)
      [ parties ]
  in
  let open Async.Deferred.Let_syntax in
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let%map _ =
    Async.Deferred.List.fold ~init:((), ()) (List.rev witnesses)
      ~f:(fun _ ((witness, spec, statement, snapp_statement) as w) ->
        printf "%s"
          (sprintf
             !"current witness \
               %{sexp:(Transaction_witness.Parties_segment_witness.t * \
               Transaction_snark.Parties_segment.Basic.t * \
               Transaction_snark.Statement.With_sok.t * (int * \
               Snapp_statement.t)option) }%!"
             w) ;
        let%map _ =
          T.of_parties_segment_exn ~snapp_statement ~statement ~witness ~spec
        in
        ((), ()))
  in
  ()

let generate_snapp_txn (keypair : Signature_lib.Keypair.t) (ledger : Ledger.t) =
  let open Deferred.Let_syntax in
  let receiver =
    Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
  in
  let spec =
    { Transaction_logic.For_tests.Transaction_spec.sender =
        (keypair, Account.Nonce.zero)
    ; fee = Currency.Fee.of_int 10000000000 (*1 Mina*)
    ; receiver
    ; amount = Currency.Amount.of_int 10000000000 (*10 Mina*)
    }
  in
  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:Genesis_constants.compiled.protocol
  in
  let compile_time_genesis =
    (*not using Precomputed_values.for_unit_test because of dependency cycle*)
    Mina_state.Genesis_protocol_state.t
      ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
      ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
      ~constraint_constants ~consensus_constants
  in
  let protocol_state_predicate =
    let protocol_state_predicate_view =
      Mina_state.Protocol_state.Body.view compile_time_genesis.data.body
    in
    Snapp_generators.gen_protocol_state_predicate protocol_state_predicate_view
    |> Base_quickcheck.Generator.generate ~size:1
         ~random:(Splittable_random.State.create Random.State.default)
  in
  let%bind parties =
    Transaction_snark.For_tests.create_trivial_predicate_snapp
      ~constraint_constants ~protocol_state_predicate spec ledger
  in
  printf "Snapp transaction yojson: %s\n\n%!"
    (Parties.to_yojson parties |> Yojson.Safe.to_string) ;
  printf "(Snapp transaction graphQL input %s\n\n%!"
    (graphql_snapp_command parties) ;
  printf "Updated accounts\n" ;
  List.iter (Ledger.to_list ledger) ~f:(fun acc ->
      printf "Account: %s\n%!"
        ( Genesis_ledger_helper_lib.Accounts.Single.of_account acc None
        |> Runtime_config.Accounts.Single.to_yojson |> Yojson.Safe.to_string )) ;
  let state_body =
    compile_time_genesis.data |> Mina_state.Protocol_state.body
  in
  let witnesses =
    Transaction_snark.parties_witnesses_exn ~constraint_constants ~state_body
      ~fee_excess:Currency.Amount.Signed.zero
      ~pending_coinbase_init_stack:Pending_coinbase.Stack.empty (`Ledger ledger)
      [ parties ]
  in
  let open Async.Deferred.Let_syntax in
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let%map _ =
    Async.Deferred.List.fold ~init:((), ()) (List.rev witnesses)
      ~f:(fun _ ((witness, spec, statement, snapp_statement) as w) ->
        printf "%s"
          (sprintf
             !"current witness \
               %{sexp:(Transaction_witness.Parties_segment_witness.t * \
               Transaction_snark.Parties_segment.Basic.t * \
               Transaction_snark.Statement.With_sok.t * (int * \
               Snapp_statement.t)option) }%!"
             w) ;
        let%map _ =
          T.of_parties_segment_exn ~snapp_statement ~statement ~witness ~spec
        in
        ((), ()))
  in
  ()

module App_state = struct
  type t = Snark_params.Tick.Field.t

  let of_string str : t Snapp_basic.Set_or_keep.t =
    match str with
    | "" ->
        Snapp_basic.Set_or_keep.Keep
    | _ ->
        parse_field_element_or_hash_string str ~f:(fun result ->
            Snapp_basic.Set_or_keep.Set result)
end

module Events = struct
  type t = Snark_params.Tick.Field.t

  let of_string_array (arr : string Array.t) =
    Array.map arr ~f:(fun s ->
        match s with
        | "" ->
            Snark_params.Tick.Field.zero
        | _ ->
            parse_field_element_or_hash_string s ~f:Fn.id)
end

module Util = struct
  let keypair_of_file =
    Secrets.Keypair.Terminal_stdin.read_exn ~should_prompt_user:false
      ~which:"payment keypair"

  let print_snapp_transaction parties =
    printf !"Parties sexp:\n %{sexp: Parties.t}\n\n%!" parties ;
    printf "Snapp transaction yojson:\n %s\n\n%!"
      (Parties.to_yojson parties |> Yojson.Safe.to_string) ;
    printf "Snapp transaction graphQL input %s\n\n%!"
      (graphql_snapp_command parties)

  let memo =
    Option.value_map ~default:Signed_command_memo.empty ~f:(fun m ->
        Signed_command_memo.create_from_string_exn m)

  let app_state_of_list lst =
    List.map ~f:App_state.of_string lst |> Snapp_state.V.of_list_exn

  let sequence_state_of_list array_lst : Snark_params.Tick.Field.t array list =
    List.map ~f:Events.of_string_array array_lst

  let auth_of_string s : Permissions.Auth_required.t =
    match String.lowercase s with
    | "none" ->
        None
    | "proof" ->
        Proof
    | "signature" ->
        Signature
    | "both" ->
        Both
    | "either" ->
        Either
    | "impossible" ->
        Impossible
    | _ ->
        failwith "Invalid authorization"
end

let test_snapp_with_genesis_ledger_main keyfile config_file () =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.keypair_of_file keyfile in
  let%bind ledger =
    let%map config_json = Genesis_ledger_helper.load_config_json config_file in
    let runtime_config =
      Or_error.ok_exn config_json
      |> Runtime_config.of_yojson |> Result.ok_or_failwith
    in
    let accounts =
      let config = Option.value_exn runtime_config.Runtime_config.ledger in
      match config.base with
      | Accounts accounts ->
          lazy (Genesis_ledger_helper.Accounts.to_full accounts)
      | _ ->
          failwith "Invalid genesis ledger, does not contain the accounts"
    in
    let packed =
      Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
        ~depth:constraint_constants.ledger_depth accounts
    in
    Lazy.force (Genesis_ledger.Packed.t packed)
  in
  generate_snapp_txn keypair ledger

let create_snapp_account ~debug ~keyfile ~fee ~snapp_keyfile ~amount ~nonce
    ~memo =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.keypair_of_file keyfile in
  let%bind snapp_keypair = Util.keypair_of_file snapp_keyfile in
  let spec =
    { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
    ; fee
    ; receivers = []
    ; amount
    ; snapp_account_keypair = Some snapp_keypair
    ; memo = Util.memo memo
    ; new_snapp_account = true
    ; snapp_update = Party.Update.dummy
    ; current_auth = Permissions.Auth_required.Signature
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; sequence_events = []
    }
  in
  let parties =
    Transaction_snark.For_tests.deploy_snapp ~constraint_constants spec
  in
  let%map () = if debug then gen_proof parties else return () in
  parties

let upgrade_snapp ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
    ~verification_key ~snapp_uri ~auth =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.keypair_of_file keyfile in
  let%bind snapp_account_keypair = Util.keypair_of_file snapp_keyfile in
  let verification_key =
    let data =
      Side_loaded_verification_key.of_base58_check_exn verification_key
    in
    let hash = Snapp_account.digest_vk data in
    Snapp_basic.Set_or_keep.Set { With_hash.data; hash }
  in
  let spec =
    { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
    ; fee
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; snapp_account_keypair = Some snapp_account_keypair
    ; memo = Util.memo memo
    ; new_snapp_account = false
    ; snapp_update = { Party.Update.dummy with verification_key; snapp_uri }
    ; current_auth = auth
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; sequence_events = []
    }
  in
  let%bind parties, vk =
    Transaction_snark.For_tests.update_state ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof parties
        ~snapp_account:
          (Some
             ( Signature_lib.Public_key.compress snapp_account_keypair.public_key
             , vk ))
    else return ()
  in
  parties

let transfer_funds ~debug ~keyfile ~fee ~nonce ~memo ~receivers =
  let open Deferred.Let_syntax in
  let%bind receivers = receivers in
  let amount =
    List.fold ~init:Currency.Amount.zero receivers ~f:(fun acc (_, a) ->
        Option.value_exn (Currency.Amount.add acc a))
  in
  let%bind keypair = Util.keypair_of_file keyfile in
  let spec =
    { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
    ; fee
    ; receivers
    ; amount
    ; snapp_account_keypair = None
    ; memo = Util.memo memo
    ; new_snapp_account = false
    ; snapp_update = Party.Update.dummy
    ; current_auth = Permissions.Auth_required.Proof
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; sequence_events = []
    }
  in
  let parties = Transaction_snark.For_tests.multiple_transfers spec in
  let%map () =
    if debug then gen_proof parties ~snapp_account:None else return ()
  in
  parties

let update_state ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~app_state =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.keypair_of_file keyfile in
  let%bind snapp_keypair = Util.keypair_of_file snapp_keyfile in
  let app_state = Util.app_state_of_list app_state in
  let spec =
    { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
    ; fee
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; snapp_account_keypair = Some snapp_keypair
    ; memo = Util.memo memo
    ; new_snapp_account = false
    ; snapp_update = { Party.Update.dummy with app_state }
    ; current_auth = Permissions.Auth_required.Proof
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; sequence_events = []
    }
  in
  let%bind parties, vk =
    Transaction_snark.For_tests.update_state ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof parties
        ~snapp_account:
          (Some (Signature_lib.Public_key.compress snapp_keypair.public_key, vk))
    else return ()
  in
  parties

let update_snapp_uri ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~snapp_uri
    ~auth =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.keypair_of_file keyfile in
  let%bind snapp_account_keypair = Util.keypair_of_file snapp_keyfile in
  let snapp_uri = Snapp_basic.Set_or_keep.Set snapp_uri in
  let spec =
    { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
    ; fee
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; snapp_account_keypair = Some snapp_account_keypair
    ; memo = Util.memo memo
    ; new_snapp_account = false
    ; snapp_update = { Party.Update.dummy with snapp_uri }
    ; current_auth = auth
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; sequence_events = []
    }
  in
  let%bind parties, vk =
    Transaction_snark.For_tests.update_state ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof parties
        ~snapp_account:
          (Some
             ( Signature_lib.Public_key.compress snapp_account_keypair.public_key
             , vk ))
    else return ()
  in
  parties

let update_sequence_state ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
    ~sequence_state =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.keypair_of_file keyfile in
  let%bind snapp_keypair = Util.keypair_of_file snapp_keyfile in
  let sequence_events = Util.sequence_state_of_list sequence_state in
  let spec =
    { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
    ; fee
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; snapp_account_keypair = Some snapp_keypair
    ; memo = Util.memo memo
    ; new_snapp_account = false
    ; snapp_update = Party.Update.dummy
    ; current_auth = Permissions.Auth_required.Proof
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; sequence_events
    }
  in
  let%bind parties, vk =
    Transaction_snark.For_tests.update_state ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof parties
        ~snapp_account:
          (Some (Signature_lib.Public_key.compress snapp_keypair.public_key, vk))
    else return ()
  in
  parties

let update_token_symbol ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
    ~token_symbol ~auth =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.keypair_of_file keyfile in
  let%bind snapp_account_keypair = Util.keypair_of_file snapp_keyfile in
  let token_symbol = Snapp_basic.Set_or_keep.Set token_symbol in
  let spec =
    { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
    ; fee
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; snapp_account_keypair = Some snapp_account_keypair
    ; memo = Util.memo memo
    ; new_snapp_account = false
    ; snapp_update = { Party.Update.dummy with token_symbol }
    ; current_auth = auth
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; sequence_events = []
    }
  in
  let%bind parties, vk =
    Transaction_snark.For_tests.update_state ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof parties
        ~snapp_account:
          (Some
             ( Signature_lib.Public_key.compress snapp_account_keypair.public_key
             , vk ))
    else return ()
  in
  parties

let update_permissions ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
    ~permissions ~current_auth =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.keypair_of_file keyfile in
  let%bind snapp_keypair = Util.keypair_of_file snapp_keyfile in
  let spec =
    { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
    ; fee
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; snapp_account_keypair = Some snapp_keypair
    ; memo = Util.memo memo
    ; new_snapp_account = false
    ; snapp_update = { Party.Update.dummy with permissions }
    ; current_auth
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; sequence_events = []
    }
  in
  let%bind parties, vk =
    Transaction_snark.For_tests.update_state ~constraint_constants spec
  in
  (*Util.print_snapp_transaction parties ;*)
  let%map () =
    if debug then
      gen_proof parties
        ~snapp_account:
          (Some (Signature_lib.Public_key.compress snapp_keypair.public_key, vk))
    else return ()
  in
  parties

let mina () =
  let addrs_and_ports =
    let base = 23000 in
    let libp2p_port = base in
    let client_port = base + 1 in
    let ip = Unix.Inet_addr.of_string "127.0.0.1" in
    { Node_addrs_and_ports.external_ip = ip
    ; bind_ip = ip
    ; peer = None
    ; libp2p_port
    ; client_port
    }
  in
  let block_production_key = None in
  let chain_id = "snapps-tool-test" in
  let peers = [] in
  let is_archive_rocksdb = false in
  let archive_process_location = None in
  let logger =
    Logger.create
      ~metadata:
        [ ( "host"
          , `String (Unix.Inet_addr.to_string addrs_and_ports.external_ip) )
        ; ("port", `Int addrs_and_ports.libp2p_port)
        ]
      ()
  in
  let precomputed_values =
    Option.value_exn Precomputed_values.compiled |> Lazy.force
  in
  let constraint_constants = precomputed_values.constraint_constants in
  let (module Genesis_ledger) = precomputed_values.genesis_ledger in
  let pids = Child_processes.Termination.create_pid_table () in
  let%bind conf_dir = Unix.mkdtemp "tmp/snapp-test-config" in
  let%bind trust_dir = Unix.mkdtemp (conf_dir ^/ "trust") in
  let trace_database_initialization typ location =
    (* can't use %log because location is passed-in *)
    Logger.trace logger "Creating %s at %s" ~module_:__MODULE__ ~location typ
  in
  let trust_system = Trust_system.create trust_dir in
  trace_database_initialization "trust_system" __LOC__ trust_dir ;
  let time_controller =
    Block_time.Controller.create (Block_time.Controller.basic ~logger)
  in
  let block_production_keypair =
    Option.map block_production_key ~f:(fun i ->
        List.nth_exn (Lazy.force Genesis_ledger.accounts) i
        |> Genesis_ledger.keypair_of_account_record_exn)
  in
  let block_production_keypairs =
    block_production_keypair
    |> Option.map ~f:(fun kp -> (kp, Public_key.compress kp.Keypair.public_key))
    |> Option.to_list |> Keypair.And_compressed_pk.Set.of_list
  in
  let block_production_pubkeys =
    block_production_keypairs |> Keypair.And_compressed_pk.Set.to_list
    |> List.map ~f:snd |> Public_key.Compressed.Set.of_list
  in
  let epoch_ledger_location = conf_dir ^/ "epoch_ledger" in
  let consensus_local_state =
    Consensus.Data.Local_state.create block_production_pubkeys
      ~genesis_ledger:Genesis_ledger.t
      ~genesis_epoch_data:precomputed_values.genesis_epoch_data
      ~epoch_ledger_location ~ledger_depth:constraint_constants.ledger_depth
      ~genesis_state_hash:
        (With_hash.hash precomputed_values.protocol_state_with_hash)
  in
  let gossip_net_params =
    Gossip_net.Libp2p.Config.
      { timeout = Time.Span.of_sec 3.
      ; initial_peers = peers
      ; addrs_and_ports
      ; metrics_port = None
      ; conf_dir
      ; chain_id
      ; logger
      ; seed_peer_list_url = None
      ; unsafe_no_trust_ip = true
      ; isolate = false
      ; trust_system
      ; flooding = false
      ; direct_peers = peers
      ; min_connections = 20
      ; max_connections = 50
      ; validation_queue_size = 150
      ; peer_exchange = true
      ; mina_peer_exchange = true
      ; keypair = None
      ; all_peers_seen_metric = false
      }
  in
  let is_seed = List.is_empty peers in
  let net_config =
    { Mina_networking.Config.logger
    ; trust_system
    ; time_controller
    ; consensus_local_state
    ; is_seed
    ; genesis_ledger_hash = Ledger.merkle_root (Lazy.force Genesis_ledger.t)
    ; constraint_constants
    ; log_gossip_heard =
        { snark_pool_diff = true
        ; transaction_pool_diff = true
        ; new_state = true
        }
    ; creatable_gossip_net =
        Mina_networking.Gossip_net.(
          Any.Creatable ((module Libp2p), Libp2p.create gossip_net_params ~pids))
    }
  in
  let monitor = Async.Monitor.create ~name:"coda" () in
  let start_time = Time.now () in
  Mina_lib.create
    (Mina_lib.Config.make ~logger ~pids ~trust_system ~conf_dir ~chain_id
       ~is_seed ~disable_node_status:true ~super_catchup:true
       ~coinbase_receiver:`Producer ~net_config ~gossip_net_params
       ~initial_protocol_version:Protocol_version.zero
       ~proposed_protocol_version_opt:None
       ~work_selection_method:(module Work_selector.Selection_methods.Sequence)
       ~snark_worker_config:
         Mina_lib.Config.Snark_worker_config.
           { initial_snark_worker_key = None
           ; shutdown_on_disconnect = true
           ; num_threads = None
           }
       ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
       ~persistent_root_location:(conf_dir ^/ "root")
       ~persistent_frontier_location:(conf_dir ^/ "frontier")
       ~epoch_ledger_location ~wallets_disk_location:(conf_dir ^/ "wallets")
       ~time_controller ~snark_work_fee:(Currency.Fee.of_int 0)
       ~block_production_keypairs ~monitor ~consensus_local_state
       ~is_archive_rocksdb ~work_reassignment_wait:420000 ~precomputed_values
       ~start_time ~upload_blocks_to_gcloud:false
       ~archive_process_location:
         (Option.map archive_process_location ~f:(fun host_and_port ->
              Cli_lib.Flag.Types.{ name = "dummy"; value = host_and_port }))
       ~log_precomputed_blocks:false ~stop_time:48 ())

let%test_module "Snapps test transaction" =
  ( module struct
    let schema = Mina_graphql.schema

    let execute mina query =
      match Graphql_parser.parse query with
      | Ok doc ->
          let%map res = Graphql_async.Schema.execute schema mina doc in
          Ok res
      | Error e ->
          Deferred.return (Error e)

    let hit_server query =
      let%bind mina = mina () in
      match%map execute mina query with
      | Ok res -> (
          match res with
          | Ok (`Response data) ->
              Ok (data |> Yojson.Basic.to_string)
          | _ ->
              Error "Unexpected response" )
      | Error e ->
          Error e

    let%test_unit "snapps transaction" =
      Quickcheck.test ~trials:10
        (User_command_generators.parties_with_ledger ())
        ~f:(fun (user_cmd, _, _, _) ->
          match user_cmd with
          | Parties p ->
              let q = graphql_snapp_command p in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Deferred.ignore_m (hit_server q))
          | Signed_command _ ->
              failwith "Expected a Parties command")
  end )
