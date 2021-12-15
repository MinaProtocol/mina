open Core
open Async
open Mina_base
open Cli_lib.Arg_type

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let proof_level = Genesis_constants.Proof_level.Full

let graphql_snapp_command (parties : Parties.t) =
  let pk_string = Signature_lib.Public_key.Compressed.to_base58_check in
  let authorization (a : Control.t) =
    match a with
    | Proof pi ->
        let p =
          Pickles.Side_loaded.Proof.Stable.V1.sexp_of_t pi
          |> Sexp.to_string |> Base64.encode_exn
        in
        sprintf "{ proof: \"%s\" }" p
    | Signature s ->
        sprintf "{  signature: \"%s\" }" (Signature.to_base58_check s)
    | None_given ->
        "null"
  in
  let app_state
      (state :
        Snark_params.Tick.Field.t Snapp_basic.Set_or_keep.t Snapp_state.V.t) =
    String.concat ~sep:","
      (List.map (Snapp_state.V.to_list state) ~f:(fun s ->
           match s with
           | Snapp_basic.Set_or_keep.Keep ->
               "null"
           | Set s ->
               sprintf "\"%s\"" (Snark_params.Tick.Field.to_string s)))
  in
  let verification_key (update : Party.Update.t) =
    match update.verification_key with
    | Snapp_basic.Set_or_keep.Keep ->
        "null"
    | Set vk_with_hash ->
        sprintf
          {|
          {verificationKey: "%s", hash: %s}
        |}
          (Pickles.Side_loaded.Verification_key.to_base58_check
             vk_with_hash.data)
          ( Pickles.Backend.Tick.Field.to_yojson vk_with_hash.hash
          |> Yojson.Safe.to_string )
  in
  let permissions (p : Mina_base.Permissions.t Snapp_basic.Set_or_keep.t) =
    match p with
    | Keep ->
        "null"
    | Set
        { stake
        ; edit_state
        ; send
        ; receive
        ; set_delegate
        ; set_permissions
        ; set_verification_key
        ; set_snapp_uri
        ; edit_sequence_state
        ; set_token_symbol
        ; increment_nonce
        } ->
        let auth = function
          | Mina_base.Permissions.Auth_required.None ->
              "None"
          | Either ->
              "Either"
          | Proof ->
              "Proof"
          | Signature ->
              "Signature"
          | Both ->
              "Both"
          | Impossible ->
              "Impossible"
        in
        sprintf
          {|
      { stake: %s
  , editState: %s
  , send: %s
  , receive: %s
  , setDelegate: %s
  , setPermissions: %s
  , setVerificationKey: %s
  , setSnappUri: %s
  , editSequenceState: %s
  , setTokenSymbol: %s
  , incrementNonce: %s
      }
    |}
          (if stake then "true" else "false")
          (auth edit_state) (auth send) (auth receive) (auth set_delegate)
          (auth set_permissions)
          (auth set_verification_key)
          (auth set_snapp_uri) (auth edit_sequence_state)
          (auth set_token_symbol) (auth increment_nonce)
  in
  let party (p : Party.t) =
    let authorization = authorization p.authorization in
    let predicate =
      match p.data.predicate with
      | Nonce n ->
          sprintf "{ nonce: \"%s\" }" (Account.Nonce.to_string n)
      | Full _a ->
          (*TODO*)
          "{\n\
          \          account: {\n\
          \            balance:null,\n\
          \            nonce:null,\n\
          \            receiptChainHash:null,\n\
          \            publicKey:null,\n\
          \            delegate:null,\n\
          \            state:\n\
          \              {elements: [null,\n\
          \              null,\n\
          \              null,\n\
          \              null,\n\
          \              null,\n\
          \              null,\n\
          \              null,\n\
          \             null]},\n\
          \            sequenceState:null,\n\
          \            provedState:null}}"
      | Accept ->
          "{account:null, nonce:null}"
    in
    let delta =
      let sgn =
        match Currency.Amount.Signed.sgn p.data.body.delta with
        | Pos ->
            "PLUS"
        | Neg ->
            "MINUS"
      in
      let magnitude =
        Currency.Amount.(to_string (Signed.magnitude p.data.body.delta))
      in
      sprintf "{sign: %s, magnitude: \"%s\"}" sgn magnitude
    in
    let increment_nonce = Bool.to_string p.data.body.increment_nonce in
    let sequence_events =
      `List
        (List.map p.data.body.sequence_events ~f:(fun a ->
             `List
               ( Array.map a ~f:(fun s ->
                     `String (Snark_params.Tick.Field.to_string s))
               |> Array.to_list )))
      |> Yojson.Safe.to_string
    in
    let call_data =
      `String (Snark_params.Tick.Field.to_string p.data.body.call_data)
      |> Yojson.Safe.to_string
    in
    let events =
      `List
        (List.map p.data.body.events ~f:(fun a ->
             `List
               ( Array.map a ~f:(fun s ->
                     `String (Snark_params.Tick.Field.to_string s))
               |> Array.to_list )))
      |> Yojson.Safe.to_string
    in
    let pk = pk_string p.data.body.pk in
    sprintf
      {|
        authorization: %s, 
      data: {
        predicate: %s, 
        body: {
          depth: 0, 
          callData: %s, 
          sequenceEvents: %s, 
          events: %s, 
          delta: %s, 
          tokenId: "1",
          incrementNonce: %s 
          update: {
            timing: null, 
            tokenSymbol: null, 
            snappUri: null, 
            permissions: %s, 
            verificationKey: %s, 
            delegate: null, 
            appState: [%s]}, 
          publicKey: "%s"}}
    |}
      authorization predicate call_data sequence_events events delta
      increment_nonce
      (permissions p.data.body.update.permissions)
      (verification_key p.data.body.update)
      (app_state p.data.body.update.app_state)
      pk
  in
  let fee_payer =
    let p = parties.fee_payer in
    let authorization = Signature.to_base58_check p.authorization in
    let nonce = Account.Nonce.to_string p.data.predicate in
    let fee = Currency.Fee.to_string p.data.body.delta in
    let pk = pk_string p.data.body.pk in
    sprintf
      {|
        authorization: "%s", 
      data: {
        predicate: "%s", 
        body: {
          depth: "0", 
          callData: "0x0000000000000000000000000000000000000000000000000000000000000000", 
          sequenceEvents:[], 
          events: [], 
          fee: "%s", 
          update: {
            timing: null, 
            tokenSymbol: null, 
            snappUri: null, 
            permissions: %s, 
            verificationKey: %s, 
            delegate: null, 
            appState: [%s]}, 
          pk: "%s" }
        |}
      authorization nonce fee
      (permissions p.data.body.update.permissions)
      (verification_key p.data.body.update)
      (app_state p.data.body.update.app_state)
      pk
  in
  let other_parties =
    let start = ref true in
    let a =
      List.fold ~init:"[" parties.other_parties ~f:(fun acc p ->
          let p = party p in
          let sep =
            if !start then (
              start := false ;
              "" )
            else ","
          in
          acc ^ sprintf "%s { %s }" sep p)
    in
    a ^ "]"
  in
  sprintf
    {|
mutation MyMutation {
  __typename
  sendSnapp(input: {
        protocolState: {
      nextEpochData: {
        epochLength: null, 
        lockCheckpoint: null, 
        startCheckpoint: null, 
        seed: null, 
        ledger: {
          totalCurrency: null, 
          hash: null}}, 
      stakingEpochData: {
        epochLength: null, 
        lockCheckpoint: null, 
        startCheckpoint: null, 
        seed: null, 
        ledger: {
          totalCurrency: null, 
          hash: null}}, 
      globalSlotSinceGenesis: null, 
      globalSlotSinceHardFork: null, 
      totalCurrency: null, 
      minWindowDensity: null, 
      blockchainLength: null, 
      timestamp: null, 
      snarkedNextAvailableToken: null, 
      snarkedLedgerHash: null}, 
    otherParties: %s, 
    feePayer: {%s} }})
}
    |}
    other_parties fee_payer

let gen_proof ?(snapp_account = None) (parties : Parties.t) =
  let ledger = Ledger.create ~depth:constraint_constants.ledger_depth () in
  let _v =
    let id =
      parties.fee_payer.data.body.pk
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
            permissions = { Permissions.user_default with edit_state = Proof }
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
        Core.printf "%s"
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
  let%bind parties =
    Transaction_snark.For_tests.create_trivial_predicate_snapp
      ~constraint_constants spec ledger
  in
  Core.printf "Snapp transaction yojson: %s\n\n%!"
    (Parties.to_yojson parties |> Yojson.Safe.to_string) ;
  Core.printf "Snapp transaction graphQL input %s\n\n%!"
    (graphql_snapp_command parties) ;
  Core.printf "Updated accounts\n" ;
  List.iter (Ledger.to_list ledger) ~f:(fun acc ->
      Core.printf "Account: %s\n%!"
        ( Genesis_ledger_helper_lib.Accounts.Single.of_account acc None
        |> Runtime_config.Accounts.Single.to_yojson |> Yojson.Safe.to_string )) ;
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
        Core.printf "%s"
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

module Flags = struct
  open Command

  let default_fee = Currency.Fee.of_formatted_string "1"

  let min_fee = Currency.Fee.of_formatted_string "0.003"

  let memo =
    Param.flag "--memo" ~doc:"STRING Memo accompanying the transaction"
      Param.(optional string)

  let fee =
    Param.flag "--fee"
      ~doc:
        (Printf.sprintf
           "FEE Amount you are willing to pay to process the transaction \
            (default: %s) (minimum: %s)"
           (Currency.Fee.to_formatted_string default_fee)
           (Currency.Fee.to_formatted_string min_fee))
      (Param.optional txn_fee)

  let snapp_account_key =
    Param.flag "--snapp-account-key" ~doc:"Public Key of the new snapp account"
      Param.(required public_key_compressed)

  let amount =
    Param.flag "--receiver-amount" ~doc:"Receiver amount"
      (Param.required txn_amount)

  let nonce =
    Param.flag "--nonce" ~doc:"Nonce of the fee payer account"
      Param.(required txn_nonce)

  let snapp_state =
    Param.flag "--snapp-state"
      ~doc:
        "A list of 8 values that can be Integers, arbitrarty strings,  hashes, \
         or field elements"
      Param.(required txn_nonce)
end

module App_state = struct
  type t = Snark_params.Tick.Field.t

  let of_string str : t Snapp_basic.Set_or_keep.t =
    match str with
    | "" ->
        Snapp_basic.Set_or_keep.Keep
    | _ -> (
        match
          Or_error.try_with (fun () -> Snark_params.Tick.Field.of_string str)
        with
        | Ok f ->
            Snapp_basic.Set_or_keep.Set f
        | Error e1 -> (
            match Signed_command_memo.create_from_string str with
            | Ok d ->
                let s =
                  Random_oracle.(
                    hash ~init:Hash_prefix.snapp_test
                      ( Signed_command_memo.to_bits d
                      |> Random_oracle_input.bitstring |> pack_input ))
                in
                Snapp_basic.Set_or_keep.Set s
            | Error e2 ->
                failwith
                  (sprintf
                     "Neither a field element nor limited length string Errors \
                      (%s, %s)"
                     (Error.to_string_hum e1) (Error.to_string_hum e2)) ) )
end

module Events = struct
  type t = Snark_params.Tick.Field.t

  let of_string_array (arr : string Array.t) =
    Array.map arr ~f:(fun x ->
        match x with
        | "" ->
            Snark_params.Tick.Field.zero
        | _ -> (
            match
              Or_error.try_with (fun () -> Snark_params.Tick.Field.of_string x)
            with
            | Ok f ->
                f
            | Error e1 -> (
                match Signed_command_memo.create_from_string x with
                | Ok d ->
                    Random_oracle.(
                      hash ~init:Hash_prefix.snapp_test
                        ( Signed_command_memo.to_bits d
                        |> Random_oracle_input.bitstring |> pack_input ))
                | Error e2 ->
                    failwith
                      (sprintf
                         "Neither a field element nor limited length string \
                          Errors (%s, %s)"
                         (Error.to_string_hum e1) (Error.to_string_hum e2)) ) ))
end

module Util = struct
  let keypair_of_file =
    Secrets.Keypair.Terminal_stdin.read_exn ~should_prompt_user:false
      ~which:"payment keypair"

  let print_snapp_transaction parties =
    Core.printf !"Parties sexp: %{sexp: Parties.t}\n%!" parties ;
    Core.printf "Snapp transaction yojson: %s\n\n%!"
      (Parties.to_yojson parties |> Yojson.Safe.to_string) ;
    Core.printf "Snapp transaction graphQL input %s\n\n%!"
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
          failwith "invlaid genesis ledger- pass all the accounts"
    in
    let packed =
      Genesis_ledger_helper.Ledger.packed_genesis_ledger_of_accounts
        ~depth:constraint_constants.ledger_depth accounts
    in
    Lazy.force (Genesis_ledger.Packed.t packed)
  in
  generate_snapp_txn keypair ledger

let create_snapp_account =
  let create_command ~keyfile ~fee ~snapp_keyfile ~amount ~nonce ~memo () =
    let open Deferred.Let_syntax in
    let%bind keypair = Util.keypair_of_file keyfile in
    let%bind snapp_account_keypair = Util.keypair_of_file snapp_keyfile in
    let spec =
      { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
      ; fee
      ; receivers = []
      ; amount
      ; snapp_account_keypair
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
    Util.print_snapp_transaction parties ;
    let%map () = gen_proof parties in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that creates a snapp account"
      (let%map keyfile =
         Param.flag "--fee-payer-key"
           ~doc:
             "KEYFILE Private key file for the fee payer of the transaction \
              (should already be in the ledger)"
           Param.(required string)
       and fee = Flags.fee
       and nonce = Flags.nonce
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and memo = Flags.memo
       and amount = Flags.amount in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~keyfile ~fee ~snapp_keyfile ~amount ~nonce ~memo))

let upgrade_snapp =
  Command.(async ~summary:"" (Param.return (fun () -> Deferred.unit)))

let transfer_funds =
  Command.(async ~summary:"" (Param.return (fun () -> Deferred.unit)))

let update_state =
  let create_command ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~app_state () =
    let open Deferred.Let_syntax in
    let%bind keypair = Util.keypair_of_file keyfile in
    let%bind snapp_account_keypair = Util.keypair_of_file snapp_keyfile in
    let app_state = Util.app_state_of_list app_state in
    let spec =
      { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
      ; fee
      ; receivers = []
      ; amount = Currency.Amount.zero
      ; snapp_account_keypair
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
    Util.print_snapp_transaction parties ;
    let%map () =
      gen_proof parties
        ~snapp_account:
          (Some
             ( Signature_lib.Public_key.compress snapp_account_keypair.public_key
             , vk ))
    in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates snapp state"
      (let%map keyfile =
         Param.flag "--fee-payer-key"
           ~doc:
             "KEYFILE Private key file for the fee payer of the transaction \
              (should already be in the ledger)"
           Param.(required string)
       and fee = Flags.fee
       and nonce = Flags.nonce
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and memo = Flags.memo
       and app_state =
         Param.flag "--snapp-state"
           ~doc:
             "String(hash)|Integer(field element) a list of 8 elements that \
              represent the snapp state (null if unspecified)"
           Param.(listed string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~app_state))

let update_snapp_uri =
  Command.(async ~summary:"" (Param.return (fun () -> Deferred.unit)))

let update_sequence_state =
  let create_command ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~sequence_state
      () =
    let open Deferred.Let_syntax in
    let%bind keypair = Util.keypair_of_file keyfile in
    let%bind snapp_account_keypair = Util.keypair_of_file snapp_keyfile in
    let sequence_events = Util.sequence_state_of_list sequence_state in
    let spec =
      { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
      ; fee
      ; receivers = []
      ; amount = Currency.Amount.zero
      ; snapp_account_keypair
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
    Util.print_snapp_transaction parties ;
    let%map () =
      gen_proof parties
        ~snapp_account:
          (Some
             ( Signature_lib.Public_key.compress snapp_account_keypair.public_key
             , vk ))
    in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates snapp state"
      (let%map keyfile =
         Param.flag "--fee-payer-key"
           ~doc:
             "KEYFILE Private key file for the fee payer of the transaction \
              (should already be in the ledger)"
           Param.(required string)
       and fee = Flags.fee
       and nonce = Flags.nonce
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and memo = Flags.memo
       and sequence_state0 =
         Param.flag "--sequence-state0"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             required
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string))
       and sequence_state1 =
         Param.flag "--sequence-state1"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             optional_with_default []
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string))
       and sequence_state2 =
         Param.flag "--sequence-state2"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             optional_with_default []
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string))
       and sequence_state3 =
         Param.flag "--sequence-state3"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             optional_with_default []
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string))
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let sequence_state =
         List.filter_map
           ~f:(fun s ->
             if List.is_empty s then None else Some (Array.of_list s))
           [ sequence_state0
           ; sequence_state1
           ; sequence_state2
           ; sequence_state3
           ]
       in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~sequence_state))

let update_token_symbol =
  Command.(async ~summary:"" (Param.return (fun () -> Deferred.unit)))

let update_permissions =
  let create_command ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~permissions
      ~current_auth () =
    let open Deferred.Let_syntax in
    let%bind keypair = Util.keypair_of_file keyfile in
    let%bind snapp_account_keypair = Util.keypair_of_file snapp_keyfile in
    let spec =
      { Transaction_snark.For_tests.Spec.sender = (keypair, nonce)
      ; fee
      ; receivers = []
      ; amount = Currency.Amount.zero
      ; snapp_account_keypair
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
    Util.print_snapp_transaction parties ;
    let%map () =
      gen_proof parties
        ~snapp_account:
          (Some
             ( Signature_lib.Public_key.compress snapp_account_keypair.public_key
             , vk ))
    in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a snapp transaction that updates the permissions of a snapp \
         account"
      (let%map keyfile =
         Param.flag "--fee-payer-key"
           ~doc:
             "KEYFILE Private key file for the fee payer of the transaction \
              (should already be in the ledger)"
           Param.(required string)
       and fee = Flags.fee
       and nonce = Flags.nonce
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and memo = Flags.memo
       and edit_state =
         Param.flag "--edit-stake" ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and send =
         Param.flag "--send" ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and receive =
         Param.flag "--receive" ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and set_permissions =
         Param.flag "--set-permissions" ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and set_delegate =
         Param.flag "--set-delegate" ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and set_verification_key =
         Param.flag "--set-verification-key"
           ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and set_snapp_uri =
         Param.flag "--set-snapp-uri" ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and edit_sequence_state =
         Param.flag "--set-sequence-state"
           ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and set_token_symbol =
         Param.flag "--set-token-symbol" ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and increment_nonce =
         Param.flag "--increment-nonce" ~doc:"Proof|Signature|Both|Either|None"
           Param.(required string)
       and current_auth =
         Param.flag "--current-auth"
           ~doc:
             "Proof|Signature|Both|Either|None Current authorization in the \
              account to change permissions"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let permissions : Permissions.t Snapp_basic.Set_or_keep.t =
         Snapp_basic.Set_or_keep.Set
           { Permissions.Poly.stake = true
           ; edit_state = Util.auth_of_string edit_state
           ; send = Util.auth_of_string send
           ; receive = Util.auth_of_string receive
           ; set_permissions = Util.auth_of_string set_permissions
           ; set_delegate = Util.auth_of_string set_delegate
           ; set_verification_key = Util.auth_of_string set_verification_key
           ; set_snapp_uri = Util.auth_of_string set_snapp_uri
           ; edit_sequence_state = Util.auth_of_string edit_sequence_state
           ; set_token_symbol = Util.auth_of_string set_token_symbol
           ; increment_nonce = Util.auth_of_string increment_nonce
           }
       in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~permissions
         ~current_auth:(Util.auth_of_string current_auth)))

let test_snapp_with_genesis_ledger =
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a trivial snapp transaction and genesis ledger with \
         verification key for testing"
      (let%map keyfile =
         Param.flag "--fee-payer-key"
           ~doc:
             "KEYFILE Private key file for the fee payer of the transaction \
              (should be in the genesis ledger)"
           Param.(required string)
       and config_file =
         Param.flag "--config-file" ~aliases:[ "config-file" ]
           ~doc:
             "PATH path to a configuration file consisting the genesis ledger"
           Param.(required string)
       in
       test_snapp_with_genesis_ledger_main keyfile config_file))

let txn_commands =
  [ ("create-snapp-account", create_snapp_account)
  ; ("upgrade-snapp", upgrade_snapp)
  ; ("transfer-fund", transfer_funds)
  ; ("update-state", update_state)
  ; ("update-snapp-uri", update_snapp_uri)
  ; ("update-sequence-state", update_sequence_state)
  ; ("update-token-symbol", update_token_symbol)
  ; ("update-permissions", update_permissions)
  ; ("test-snapp-with-genesis-ledger", test_snapp_with_genesis_ledger)
  ]

let () =
  Command.run
    (Command.group ~summary:"Snapp test transaction"
       ~preserve_subcommand_order:() txn_commands)
