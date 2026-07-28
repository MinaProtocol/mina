open Core
open Async
open Mina_base
module Ledger = Mina_ledger.Ledger

let underToCamel s = String.lowercase s |> Mina_graphql.Reflection.underToCamel

let graphql_zkapp_command (zkapp_command : Zkapp_command.Stable.Latest.t) =
  sprintf
    {|
mutation MyMutation {
  __typename
  sendZkapp(input: { zkappCommand: %s }) {
    zkapp {
      hash
    }
  }
}
    |}
    (Zkapp_command.arg_query_string zkapp_command)

let parse_field_element_or_hash_string s ~f =
  match Or_error.try_with (fun () -> Snark_params.Tick.Field.of_string s) with
  | Ok field ->
      f field
  | Error e1 ->
      Error.raise (Error.tag ~tag:"Expected a field element" e1)

let vk_and_prover = lazy (Transaction_snark.For_tests.create_trivial_snapp ())

let get_second_pass_ledger_mask ~ledger ~constraint_constants ~global_slot
    ~state_body zkapp_command =
  let second_pass_ledger =
    let new_mask =
      Mina_ledger.Ledger.Mask.create ~depth:(Mina_ledger.Ledger.depth ledger) ()
    in
    Mina_ledger.Ledger.register_mask ledger new_mask
  in
  let _partial_stmt =
    Mina_ledger.Ledger.apply_transaction_first_pass ~signature_kind:Testnet
      ~constraint_constants ~global_slot
      ~txn_state_view:(Mina_state.Protocol_state.Body.view state_body)
      second_pass_ledger
      (Mina_transaction.Transaction.Command (Zkapp_command zkapp_command))
    |> Or_error.ok_exn
  in
  second_pass_ledger

let print_witnesses ~constraint_constants ~proof_level witnesses =
  let module T = Transaction_snark.Make (struct
    let signature_kind = Mina_signature_kind.t_DEPRECATED

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  Async.Deferred.List.iter (List.rev witnesses)
    ~f:(fun (witness, spec, statement) ->
      printf "%s"
        (sprintf
           !"current witness \
             %{sexp:(Transaction_witness.Zkapp_command_segment_witness.Stable.Latest.t \
             * Transaction_snark.Zkapp_command_segment.Basic.t * \
             Transaction_snark.Statement.With_sok.t) }%!"
           ( Transaction_witness.Zkapp_command_segment_witness
             .read_all_proofs_from_disk witness
           , spec
           , statement ) ) ;
      Deferred.ignore_m
      @@ T.of_zkapp_command_segment_exn ~statement ~witness ~spec )

let gen_proof ?(zkapp_account = None) (zkapp_command : Zkapp_command.t)
    ~(genesis_constants : Genesis_constants.t)
    ~(proof_level : Genesis_constants.Proof_level.t)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let ledger = Ledger.create ~depth:constraint_constants.ledger_depth () in
  let _v =
    let id =
      zkapp_command.fee_payer.body.public_key
      |> fun pk -> Account_id.create pk Token_id.default
    in
    Ledger.get_or_create_account ledger id
      (Account.create id Currency.Balance.(of_mina_int_exn 1_000))
    |> Or_error.ok_exn
  in
  let%bind () =
    Option.value_map zkapp_account ~default:(Deferred.return ()) ~f:(fun pk ->
        let `VK vk, `Prover _ = Lazy.force @@ vk_and_prover in
        let%map vk = vk in
        let id = Account_id.create pk Token_id.default in
        Ledger.get_or_create_account ledger id
          { (Account.create id Currency.Balance.(of_mina_int_exn 1_000)) with
            permissions =
              { Permissions.user_default with
                edit_state = Proof
              ; set_verification_key = (Proof, Mina_numbers.Txn_version.current)
              ; set_zkapp_uri = Proof
              ; set_token_symbol = Proof
              }
          ; zkapp =
              Some { Zkapp_account.default with verification_key = Some vk }
          }
        |> Or_error.ok_exn |> ignore )
  in
  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:genesis_constants.protocol
  in
  let state_body =
    let compile_time_genesis =
      let open Staged_ledger_diff in
      (*not using Precomputed_values.for_unit_test because of dependency cycle*)
      Mina_state.Genesis_protocol_state.t
        ~genesis_ledger:
          (Consensus.Genesis_data.Ledger.to_hashed Genesis_ledger.for_unit_tests)
        ~genesis_epoch_data:
          (Consensus.Genesis_data.Epoch.to_hashed
             Consensus.Genesis_data.Epoch.for_unit_tests )
        ~constraint_constants ~consensus_constants ~genesis_body_reference
    in
    compile_time_genesis.data |> Mina_state.Protocol_state.body
  in
  let global_slot =
    Mina_state.Protocol_state.Body.consensus_state state_body
    |> Consensus.Data.Consensus_state.global_slot_since_genesis
    |> Mina_numbers.Global_slot_since_genesis.succ
  in
  let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
  let pending_coinbase_init_stack = Pending_coinbase.Stack.empty in
  let pending_coinbase_state_stack =
    { Transaction_snark.Pending_coinbase_stack_state.source =
        pending_coinbase_init_stack
    ; target =
        Pending_coinbase.Stack.push_state state_body_hash global_slot
          pending_coinbase_init_stack
    }
  in
  let witnesses =
    let second_pass_ledger =
      get_second_pass_ledger_mask ~ledger ~constraint_constants ~global_slot
        ~state_body zkapp_command
    in
    Transaction_snark.zkapp_command_witnesses_exn ~signature_kind
      ~constraint_constants ~global_slot ~state_body
      ~fee_excess:Currency.Amount.Signed.zero
      [ ( `Pending_coinbase_init_stack pending_coinbase_init_stack
        , `Pending_coinbase_of_statement pending_coinbase_state_stack
        , `Ledger ledger
        , `Ledger second_pass_ledger
        , `Connecting_ledger_hash (Ledger.merkle_root second_pass_ledger)
        , zkapp_command )
      ]
  in
  print_witnesses ~constraint_constants ~proof_level witnesses

let generate_zkapp_txn (keypair : Signature_lib.Keypair.t) (ledger : Ledger.t)
    ~zkapp_kp ~(genesis_constants : Genesis_constants.t) ~proof_level
    ~constraint_constants =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let receiver =
    Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
  in
  let spec =
    { Mina_transaction_logic.For_tests.Transaction_spec.sender =
        (keypair, Account.Nonce.zero)
    ; fee = Currency.Fee.of_mina_int_exn 10
    ; receiver
    ; amount = Currency.Amount.of_mina_int_exn 10 (*10 Mina*)
    }
  in
  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:genesis_constants.protocol
  in
  let open Staged_ledger_diff in
  let compile_time_genesis =
    (*not using Precomputed_values.for_unit_test because of dependency cycle*)
    Mina_state.Genesis_protocol_state.t
      ~genesis_ledger:
        (Consensus.Genesis_data.Ledger.to_hashed Genesis_ledger.for_unit_tests)
      ~genesis_epoch_data:
        (Consensus.Genesis_data.Epoch.to_hashed
           Consensus.Genesis_data.Epoch.for_unit_tests )
      ~constraint_constants ~consensus_constants ~genesis_body_reference
  in
  let protocol_state_predicate =
    let protocol_state_predicate_view =
      Mina_state.Protocol_state.Body.view compile_time_genesis.data.body
    in
    Mina_generators.Zkapp_command_generators.gen_protocol_state_precondition
      protocol_state_predicate_view
    |> Base_quickcheck.Generator.generate ~size:1
         ~random:(Splittable_random.State.create Random.State.default)
  in
  let%bind zkapp_command =
    Transaction_snark.For_tests.create_trivial_predicate_snapp
      ~protocol_state_predicate spec ledger ~snapp_kp:zkapp_kp
  in
  printf "ZkApp transaction yojson: %s\n\n%!"
    (Zkapp_command.to_yojson zkapp_command |> Yojson.Safe.to_string) ;
  printf "(ZkApp transaction graphQL input %s\n\n%!"
    ( graphql_zkapp_command
    @@ Zkapp_command.read_all_proofs_from_disk zkapp_command ) ;
  printf "Updated accounts\n" ;
  let%bind accounts = Ledger.to_list ledger in
  List.iter accounts ~f:(fun acc ->
      printf "Account: %s\n%!"
        ( Genesis_ledger_helper_lib.Accounts.Single.of_account acc None
        |> Runtime_config.Accounts.Single.to_yojson |> Yojson.Safe.to_string ) ) ;
  let state_body =
    compile_time_genesis.data |> Mina_state.Protocol_state.body
  in
  let global_slot =
    Mina_state.Protocol_state.Body.consensus_state state_body
    |> Consensus.Data.Consensus_state.global_slot_since_genesis
    |> Mina_numbers.Global_slot_since_genesis.succ
  in
  let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
  let pending_coinbase_init_stack = Pending_coinbase.Stack.empty in
  let pending_coinbase_state_stack =
    { Transaction_snark.Pending_coinbase_stack_state.source =
        pending_coinbase_init_stack
    ; target =
        Pending_coinbase.Stack.push_state state_body_hash global_slot
          pending_coinbase_init_stack
    }
  in
  let witnesses =
    let second_pass_ledger =
      get_second_pass_ledger_mask ~ledger ~constraint_constants ~global_slot
        ~state_body zkapp_command
    in
    Transaction_snark.zkapp_command_witnesses_exn ~signature_kind
      ~constraint_constants ~global_slot ~state_body
      ~fee_excess:Currency.Amount.Signed.zero
      [ ( `Pending_coinbase_init_stack pending_coinbase_init_stack
        , `Pending_coinbase_of_statement pending_coinbase_state_stack
        , `Ledger ledger
        , `Ledger second_pass_ledger
        , `Connecting_ledger_hash (Ledger.merkle_root second_pass_ledger)
        , zkapp_command )
      ]
  in
  print_witnesses ~constraint_constants ~proof_level witnesses

module App_state = struct
  type t = Snark_params.Tick.Field.t

  let of_string str : t Zkapp_basic.Set_or_keep.t =
    match str with
    | "" ->
        Zkapp_basic.Set_or_keep.Keep
    | _ ->
        parse_field_element_or_hash_string str ~f:(fun result ->
            Zkapp_basic.Set_or_keep.Set result )
end

module Events = struct
  type t = Snark_params.Tick.Field.t

  let of_string_array (arr : string Array.t) =
    Array.map arr ~f:(fun s ->
        match s with
        | "" ->
            Snark_params.Tick.Field.zero
        | _ ->
            parse_field_element_or_hash_string s ~f:Fn.id )
end

module Util = struct
  let keypair_of_file ~which f =
    printf "%s keyfile\n" which ;
    Secrets.Keypair.Terminal_stdin.read_exn ~which f

  let fee_payer_keypair_of_file = keypair_of_file ~which:"Fee payer"

  let snapp_keypair_of_file = keypair_of_file ~which:"Zkapp Account"

  let print_snapp_transaction ~debug zkapp_command =
    if debug then (
      printf
        !"Zkapp_command sexp:\n %{sexp: Zkapp_command.t}\n\n%!"
        zkapp_command ;
      printf "Zkapp transaction yojson:\n %s\n\n%!"
        (Zkapp_command.to_yojson zkapp_command |> Yojson.Safe.to_string) ;
      printf "Zkapp transaction graphQL input %s\n\n%!"
        ( graphql_zkapp_command
        @@ Zkapp_command.read_all_proofs_from_disk zkapp_command ) )
    else
      printf "%s\n%!"
        ( graphql_zkapp_command
        @@ Zkapp_command.read_all_proofs_from_disk zkapp_command )

  let memo =
    Option.value_map ~default:Signed_command_memo.empty ~f:(fun m ->
        Signed_command_memo.create_from_string_exn m )

  let app_state_of_list lst =
    let app_state = List.map ~f:App_state.of_string lst in
    List.append app_state
      (List.init
         (Zkapp_state.max_size_int - List.length app_state)
         ~f:(fun _ -> Zkapp_basic.Set_or_keep.Keep) )
    |> Zkapp_state.V.of_list_exn

  let action_state_of_list array_lst : Snark_params.Tick.Field.t array list =
    List.map ~f:Events.of_string_array array_lst

  (* How many events/actions arrays to generate. [Max] saturates the protocol
     cap instead of naming a number, so that one command line stays valid
     across protocol versions that cap events and actions differently. *)
  type array_count = Count of int | Max

  let array_count_of_string s =
    match String.lowercase (String.strip s) with
    | "max" ->
        Max
    | _ -> (
        match Option.try_with (fun () -> Int.of_string s) with
        | Some n when n >= 0 ->
            Count n
        | _ ->
            failwithf "expected a non-negative integer or \"max\", got %s" s ()
        )

  (* Generate the events or actions of a zkApp command: [count] field-arrays of
     [elements_per] field elements each.

     [max_elements] is the cap that Zkapp_command.valid_size enforces, and it
     bounds the *total* number of field elements of one kind across the whole
     command, not the length of a single array. Going over it builds a command
     that every daemon rejects, so fail here with a message naming the total.

     With [repeat] every array holds the same elements, which defeats the
     content-based deduplication that consumers such as the archive node apply
     to event and action arrays. *)

  (* Pick the zkApp state fields to set: either the ones named explicitly, or
     [count] generated ones. How many fields a zkApp account has is fixed when
     the tool is built, so asking for [Max] is the only way to set all of them
     without naming a number that a different protocol version rejects.
     [max_fields] is that limit, read once at the entrypoint and passed down
     rather than looked up here. *)
  let state_fields ~explicit ~count ~max_fields =
    match count with
    | Count 0 ->
        explicit
    | _ ->
        if not (List.is_empty explicit) then
          failwith
            "--zkapp-state and --num-state-fields both set the zkApp state; \
             pass one or the other" ;
        let n = match count with Count n -> n | Max -> max_fields in
        if n > max_fields then
          failwithf
            "%d zkApp state fields is above the %d this protocol version \
             defines"
            n max_fields () ;
        List.init n ~f:(fun i -> Int.to_string (i + 1))

  let gen_field_arrays ~kind ~max_elements ~count ~elements_per ~repeat :
      Snark_params.Tick.Field.t array list =
    if elements_per < 1 then
      failwithf "%s arrays need at least 1 field element, got %d" kind
        elements_per () ;
    let count =
      match count with
      | Count n ->
          n
      | Max ->
          if elements_per > max_elements then
            failwithf
              "a single %s array of %d field elements is already above the \
               maximum of %d (genesis constant max_%s_elements)"
              kind elements_per max_elements kind () ;
          max_elements / elements_per
    in
    let total = count * elements_per in
    if total > max_elements then
      failwithf
        "%d %s arrays of %d field elements is %d elements, above the maximum \
         of %d (genesis constant max_%s_elements)"
        count kind elements_per total max_elements kind () ;
    List.init count ~f:(fun i ->
        Array.init elements_per ~f:(fun j ->
            let ndx = if repeat then j else (i * elements_per) + j in
            Snark_params.Tick.Field.of_int (ndx + 1) ) )

  let auth_of_string s : Permissions.Auth_required.t =
    match String.lowercase s with
    | "none" ->
        None
    | "proof" ->
        Proof
    | "signature" ->
        Signature
    | "either" ->
        Either
    | "impossible" ->
        Impossible
    | _ ->
        failwith (sprintf "Invalid authorization: %s" s)
end

let test_zkapp_with_genesis_ledger_main keyfile zkapp_keyfile config_file () =
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let genesis_constants = Genesis_constants.Compiled.genesis_constants in
  let open Deferred.Let_syntax in
  let%bind keypair = Util.fee_payer_keypair_of_file keyfile in
  let%bind zkapp_kp = Util.snapp_keypair_of_file zkapp_keyfile in
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
        ~logger:(Logger.create ()) ~depth:constraint_constants.ledger_depth
        ~genesis_backing_type:Stable_db accounts
    in
    Lazy.force (Genesis_ledger.Packed.t packed)
  in
  generate_zkapp_txn keypair ledger ~zkapp_kp ~constraint_constants
    ~proof_level:Full ~genesis_constants

let create_zkapp_account ~debug ~sender ~sender_nonce ~fee ~fee_payer
    ~fee_payer_nonce ~zkapp_keyfile ~amount ~memo =
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let genesis_constants = Genesis_constants.Compiled.genesis_constants in
  let open Deferred.Let_syntax in
  let%bind sender_keypair = Util.keypair_of_file sender ~which:"Sender" in
  let%bind fee_payer_keypair = Util.fee_payer_keypair_of_file fee_payer in
  let%bind zkapp_keypair = Util.snapp_keypair_of_file zkapp_keyfile in
  let spec =
    { Transaction_snark.For_tests.Deploy_snapp_spec.sender =
        (sender_keypair, sender_nonce)
    ; fee
    ; fee_payer = Some (fee_payer_keypair, fee_payer_nonce)
    ; amount
    ; zkapp_account_keypairs = [ zkapp_keypair ]
    ; memo = Util.memo memo
    ; new_zkapp_account = true
    ; snapp_update = Account_update.Update.dummy
    ; preconditions = None
    ; authorization_kind = Signature
    }
  in
  let%bind zkapp_command =
    Transaction_snark.For_tests.deploy_snapp
      ~permissions:Permissions.user_default ~constraint_constants
      ~signature_kind:Testnet spec
  in
  let%map () =
    if debug then
      gen_proof ~genesis_constants ~constraint_constants ~proof_level:Full
        zkapp_command
    else return ()
  in
  zkapp_command

let upgrade_zkapp ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
    ~constraint_constants ~genesis_constants ~verification_key ~zkapp_uri ~auth
    =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.fee_payer_keypair_of_file keyfile in
  let%bind zkapp_account_keypair = Util.snapp_keypair_of_file zkapp_keyfile in
  let verification_key =
    let data =
      match Side_loaded_verification_key.of_base64 verification_key with
      | Ok vk_data ->
          vk_data
      | Error err ->
          failwith (Error.to_string_hum err)
    in
    let hash = Zkapp_account.digest_vk data in
    Zkapp_basic.Set_or_keep.Set { With_hash.data; hash }
  in
  let spec =
    { Transaction_snark.For_tests.Update_states_spec.sender = (keypair, nonce)
    ; fee
    ; fee_payer = None
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; zkapp_account_keypairs = [ zkapp_account_keypair ]
    ; memo = Util.memo memo
    ; new_zkapp_account = false
    ; snapp_update =
        { Account_update.Update.dummy with verification_key; zkapp_uri }
    ; current_auth = auth
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; actions = []
    ; preconditions = None
    }
  in
  let%bind zkapp_command =
    let `VK vk, `Prover prover = Lazy.force @@ vk_and_prover in
    Transaction_snark.For_tests.update_states ~zkapp_prover_and_vk:(prover, vk)
      ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof zkapp_command ~constraint_constants ~genesis_constants
        ~proof_level:Full
        ~zkapp_account:
          (Some
             (Signature_lib.Public_key.compress zkapp_account_keypair.public_key)
          )
    else return ()
  in
  zkapp_command

let transfer_funds ~debug ~sender ~sender_nonce ~fee ~fee_payer ~fee_payer_nonce
    ~memo ~receivers ~genesis_constants ~constraint_constants =
  let open Deferred.Let_syntax in
  let%bind receivers = receivers in
  let amount =
    List.fold ~init:Currency.Amount.zero receivers ~f:(fun acc (_, a) ->
        Option.value_exn (Currency.Amount.add acc a) )
  in
  let%bind sender_keypair = Util.keypair_of_file ~which:"Sender" sender in
  let%bind fee_payer_keypair = Util.fee_payer_keypair_of_file fee_payer in
  let spec =
    { Transaction_snark.For_tests.Multiple_transfers_spec.sender =
        (sender_keypair, sender_nonce)
    ; fee
    ; fee_payer = Some (fee_payer_keypair, fee_payer_nonce)
    ; receivers
    ; amount
    ; zkapp_account_keypairs = []
    ; memo = Util.memo memo
    ; new_zkapp_account = false
    ; snapp_update = Account_update.Update.dummy
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; actions = []
    ; preconditions = None
    }
  in
  let zkapp_command =
    Transaction_snark.For_tests.multiple_transfers
      ~constraint_constants:
        Genesis_constants.For_unit_tests.Constraint_constants.t spec
  in
  let%map () =
    if debug then
      gen_proof zkapp_command ~zkapp_account:None ~genesis_constants
        ~constraint_constants ~proof_level:Full
    else return ()
  in
  zkapp_command

let update_state ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile ~app_state
    ~num_events ~num_actions ~event_elements_per ~action_elements_per
    ~repeat_arrays ~num_state_fields ~max_state_fields ~genesis_constants
    ~constraint_constants =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.fee_payer_keypair_of_file keyfile in
  let%bind zkapp_keypair = Util.snapp_keypair_of_file zkapp_keyfile in
  let app_state =
    Util.app_state_of_list
      (Util.state_fields ~explicit:app_state ~count:num_state_fields
         ~max_fields:max_state_fields )
  in
  let Genesis_constants.{ max_event_elements; max_action_elements; _ } =
    genesis_constants
  in
  let events =
    Util.gen_field_arrays ~kind:"event" ~max_elements:max_event_elements
      ~count:num_events ~elements_per:event_elements_per ~repeat:repeat_arrays
  in
  let actions =
    Util.gen_field_arrays ~kind:"action" ~max_elements:max_action_elements
      ~count:num_actions ~elements_per:action_elements_per ~repeat:repeat_arrays
  in
  let spec =
    { Transaction_snark.For_tests.Update_states_spec.sender = (keypair, nonce)
    ; fee
    ; fee_payer = None
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; zkapp_account_keypairs = [ zkapp_keypair ]
    ; memo = Util.memo memo
    ; new_zkapp_account = false
    ; snapp_update = { Account_update.Update.dummy with app_state }
    ; current_auth = Permissions.Auth_required.Signature
    ; call_data = Snark_params.Tick.Field.zero
    ; events
    ; actions
    ; preconditions = None
    }
  in
  let%bind zkapp_command =
    let `VK vk, `Prover prover = Lazy.force @@ vk_and_prover in
    Transaction_snark.For_tests.update_states ~zkapp_prover_and_vk:(prover, vk)
      ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof zkapp_command ~genesis_constants ~constraint_constants
        ~proof_level:Full
        ~zkapp_account:
          (Some (Signature_lib.Public_key.compress zkapp_keypair.public_key))
    else return ()
  in
  zkapp_command

let update_zkapp_uri ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~zkapp_uri
    ~auth ~constraint_constants ~genesis_constants =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.fee_payer_keypair_of_file keyfile in
  let%bind zkapp_account_keypair = Util.snapp_keypair_of_file snapp_keyfile in
  let zkapp_uri = Zkapp_basic.Set_or_keep.Set zkapp_uri in
  let spec =
    { Transaction_snark.For_tests.Update_states_spec.sender = (keypair, nonce)
    ; fee
    ; fee_payer = None
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; zkapp_account_keypairs = [ zkapp_account_keypair ]
    ; memo = Util.memo memo
    ; new_zkapp_account = false
    ; snapp_update = { Account_update.Update.dummy with zkapp_uri }
    ; current_auth = auth
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; actions = []
    ; preconditions = None
    }
  in
  let%bind zkapp_command =
    let `VK vk, `Prover prover = Lazy.force @@ vk_and_prover in
    Transaction_snark.For_tests.update_states ~zkapp_prover_and_vk:(prover, vk)
      ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof zkapp_command ~genesis_constants ~constraint_constants
        ~proof_level:Full
        ~zkapp_account:
          (Some
             (Signature_lib.Public_key.compress zkapp_account_keypair.public_key)
          )
    else return ()
  in
  zkapp_command

let update_action_state ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile
    ~action_state ~genesis_constants ~constraint_constants =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.fee_payer_keypair_of_file keyfile in
  let%bind zkapp_keypair = Util.snapp_keypair_of_file zkapp_keyfile in
  let actions = Util.action_state_of_list action_state in
  let spec =
    { Transaction_snark.For_tests.Update_states_spec.sender = (keypair, nonce)
    ; fee
    ; fee_payer = None
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; zkapp_account_keypairs = [ zkapp_keypair ]
    ; memo = Util.memo memo
    ; new_zkapp_account = false
    ; snapp_update = Account_update.Update.dummy
    ; current_auth = Permissions.Auth_required.Signature
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; actions
    ; preconditions = None
    }
  in
  let%bind zkapp_command =
    let `VK vk, `Prover prover = Lazy.force @@ vk_and_prover in
    Transaction_snark.For_tests.update_states ~zkapp_prover_and_vk:(prover, vk)
      ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof zkapp_command ~genesis_constants ~constraint_constants
        ~proof_level:Full
        ~zkapp_account:
          (Some (Signature_lib.Public_key.compress zkapp_keypair.public_key))
    else return ()
  in
  zkapp_command

let update_token_symbol ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
    ~token_symbol ~auth ~genesis_constants ~constraint_constants =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.fee_payer_keypair_of_file keyfile in
  let%bind zkapp_account_keypair = Util.snapp_keypair_of_file snapp_keyfile in
  let token_symbol = Zkapp_basic.Set_or_keep.Set token_symbol in
  let spec =
    { Transaction_snark.For_tests.Update_states_spec.sender = (keypair, nonce)
    ; fee
    ; fee_payer = None
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; zkapp_account_keypairs = [ zkapp_account_keypair ]
    ; memo = Util.memo memo
    ; new_zkapp_account = false
    ; snapp_update = { Account_update.Update.dummy with token_symbol }
    ; current_auth = auth
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; actions = []
    ; preconditions = None
    }
  in
  let%bind zkapp_command =
    let `VK vk, `Prover prover = Lazy.force @@ vk_and_prover in
    Transaction_snark.For_tests.update_states ~zkapp_prover_and_vk:(prover, vk)
      ~constraint_constants spec
  in
  let%map () =
    if debug then
      gen_proof zkapp_command ~genesis_constants ~constraint_constants
        ~proof_level:Full
        ~zkapp_account:
          (Some
             (Signature_lib.Public_key.compress zkapp_account_keypair.public_key)
          )
    else return ()
  in
  zkapp_command

let update_snapp ~debug ~keyfile ~fee ~nonce ~memo ~zkapp_keyfile ~snapp_update
    ~current_auth ~genesis_constants ~constraint_constants =
  let open Deferred.Let_syntax in
  let%bind keypair = Util.fee_payer_keypair_of_file keyfile in
  let%bind zkapp_keypair = Util.snapp_keypair_of_file zkapp_keyfile in
  let spec =
    { Transaction_snark.For_tests.Update_states_spec.sender = (keypair, nonce)
    ; fee
    ; fee_payer = None
    ; receivers = []
    ; amount = Currency.Amount.zero
    ; zkapp_account_keypairs = [ zkapp_keypair ]
    ; memo = Util.memo memo
    ; new_zkapp_account = false
    ; snapp_update
    ; current_auth
    ; call_data = Snark_params.Tick.Field.zero
    ; events = []
    ; actions = []
    ; preconditions = None
    }
  in
  let%bind zkapp_command =
    let `VK vk, `Prover prover = Lazy.force @@ vk_and_prover in
    Transaction_snark.For_tests.update_states ~zkapp_prover_and_vk:(prover, vk)
      ~constraint_constants spec
  in
  (*Util.print_snapp_transaction zkapp_command ;*)
  let%map () =
    if debug then
      gen_proof zkapp_command ~genesis_constants ~constraint_constants
        ~proof_level:Full
        ~zkapp_account:
          (Some (Signature_lib.Public_key.compress zkapp_keypair.public_key))
    else return ()
  in
  zkapp_command

let%test_module "ZkApps test transaction" =
  ( module struct
    let execute mina schema query =
      match Graphql_parser.parse query with
      | Ok doc ->
          let%map res = Graphql_async.Schema.execute schema mina doc in
          Ok res
      | Error e ->
          Deferred.return (Error e)

    let print_diff_yojson ?(path = []) expected got =
      let success = ref true in
      let rec go path expected got =
        let print_unexpected () =
          success := false ;
          printf "At path %s:\nExpected:\n%s\nGot:\n%s\n"
            (String.concat ~sep:"." (List.rev path))
            (Yojson.Safe.to_string expected)
            (Yojson.Safe.to_string got)
        in
        match (expected, got) with
        | `Null, `Null ->
            ()
        | `Bool b1, `Bool b2 when Bool.equal b1 b2 ->
            ()
        | `Int i1, `Int i2 when Int.equal i1 i2 ->
            ()
        | `Intlit s1, `Intlit s2 when String.equal s1 s2 ->
            ()
        | `Float f1, `Float f2 when Float.equal f1 f2 ->
            ()
        | `String s1, `String s2 when String.equal s1 s2 ->
            ()
        | `Assoc l1, `Assoc l2 ->
            let rec go_assoc l1 l2 =
              match (l1, l2) with
              | [], [] ->
                  ()
              | (s1, x1) :: l1, (s2, x2) :: l2 when String.equal s1 s2 ->
                  go (s1 :: path) x1 x2 ;
                  go_assoc l1 l2
              | (s1, x1) :: l1, (s2, x2) :: l2 ->
                  (* NB: Assumes that fields appear in the same order. *)
                  go (s1 :: path) x1 `Null ;
                  go (s2 :: path) `Null x2 ;
                  go_assoc l1 l2
              | (s1, x1) :: l1, [] ->
                  go (s1 :: path) x1 `Null ;
                  go_assoc l1 []
              | [], (s2, x2) :: l2 ->
                  go (s2 :: path) `Null x2 ;
                  go_assoc [] l2
            in
            go_assoc l1 l2
        | `List l1, `List l2 | `Tuple l1, `Tuple l2 ->
            let rec go_list i l1 l2 =
              match (l1, l2) with
              | [], [] ->
                  ()
              | x1 :: l1, x2 :: l2 ->
                  go (string_of_int i :: path) x1 x2 ;
                  go_list (i + 1) l1 l2
              | x1 :: l1, [] ->
                  go (string_of_int i :: path) x1 `Null ;
                  go_list (i + 1) l1 []
              | [], x2 :: l2 ->
                  go (string_of_int i :: path) `Null x2 ;
                  go_list (i + 1) [] l2
            in
            go_list 0 l1 l2
        | `Variant (s1, x1), `Variant (s2, x2) when String.equal s1 s2 -> (
            match (x1, x2) with
            | None, None ->
                ()
            | Some x1, None ->
                go ("0" :: path) x1 `Null
            | None, Some x2 ->
                go ("0" :: path) `Null x2
            | Some x1, Some x2 ->
                go ("0" :: path) x1 x2 )
        | _ ->
            print_unexpected ()
      in
      go path expected got ; !success

    let hit_server (zkapp_command : Zkapp_command.t) query =
      let typ = Mina_graphql.Types.Input.SendZkappInput.arg_typ.arg_typ in
      let query_top_level =
        Graphql_async.Schema.(
          io_field "sendZkapp" ~typ:(non_null string)
            ~args:Arg.[ arg "input" ~typ:(non_null typ) ]
            ~doc:"sample query"
            ~resolve:(fun _ () (zkapp_command' : Zkapp_command.Stable.Latest.t) ->
              let ok_fee_payer =
                print_diff_yojson ~path:[ "fee_payer" ]
                  (Account_update.Fee_payer.to_yojson zkapp_command.fee_payer)
                  (Account_update.Fee_payer.to_yojson zkapp_command'.fee_payer)
              in
              let _, ok_account_updates =
                Zkapp_command.Call_forest.Tree.fold_forest2_exn ~init:(0, true)
                  zkapp_command.account_updates zkapp_command.account_updates
                  ~f:(fun (i, ok) expected got ->
                    ( i + 1
                    , print_diff_yojson
                        ~path:[ string_of_int i; "account_updates" ]
                        (Account_update.to_yojson expected)
                        (Account_update.to_yojson got)
                      && ok ) )
              in
              if ok_fee_payer && ok_account_updates then return (Ok "Passed")
              else return (Error "invalid snapp transaction generated") ))
      in
      let schema =
        Graphql_async.Schema.(
          schema [] ~mutations:[ query_top_level ] ~subscriptions:[])
      in
      let%map res = execute () schema query in
      match res with
      | Ok res -> (
          match res with
          | Ok (`Response data) ->
              Ok (data |> Yojson.Basic.to_string)
          | Ok (`Stream _reader) ->
              Error "Unexpected response"
          | Error e ->
              Error (Yojson.Basic.to_string e) )
      | Error e ->
          Error e

    let%test_unit "zkapps transaction graphql round trip" =
      Quickcheck.test ~trials:20
        (Mina_generators.User_command_generators.zkapp_command_with_ledger
           ~genesis_constants:Genesis_constants.For_unit_tests.t
           ~constraint_constants:
             Genesis_constants.For_unit_tests.Constraint_constants.t () )
        ~f:(fun (user_cmd, _, _, _) ->
          match user_cmd with
          | Zkapp_command p ->
              let p = Zkapp_command.Valid.forget p in
              let q =
                graphql_zkapp_command
                  (Zkapp_command.read_all_proofs_from_disk p)
              in
              Async.Thread_safe.block_on_async_exn (fun () ->
                  match%map hit_server p q with
                  | Ok _res ->
                      ()
                  | Error e ->
                      printf
                        "Invalid graphql query %s for zkapp_command \
                         transaction %s. Error %s"
                        q
                        (Zkapp_command.to_yojson p |> Yojson.Safe.to_string)
                        e ;
                      failwith "Invalid graphql query" )
          | Signed_command _ ->
              failwith "Expected a Zkapp_command command" )
  end )
