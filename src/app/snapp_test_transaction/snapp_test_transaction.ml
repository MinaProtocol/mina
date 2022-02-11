open Core_kernel
open Async
open Mina_base
open Cli_lib.Arg_type

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let proof_level = Genesis_constants.Proof_level.Full

(* changes first char to lower case unlike Mina_graphql.Reflection.underToCamel*)
let underToCamel s =
  let regex = lazy (Re2.create_exn {regex|\_(\w)|regex}) in
  String.lowercase s
  |> Re2.replace_exn (Lazy.force regex) ~f:(fun m ->
         let s = Re2.Match.get_exn ~sub:(`Index 1) m in
         String.capitalize s)

(* transform JSON into a string for a Javascript object,
   some special handling of cases where the GraphQL schema
   differs from OCaml code
*)
let jsobj_of_json ?(fee_payer = false) (json : Yojson.Safe.t) : string =
  let indent n = String.make n ' ' in
  let rec go json level =
    match json with
    | `Tuple _ | `Variant _ ->
        failwith
          (sprintf "JSON not generated from OCaml: %s"
             (Yojson.Safe.to_string json))
    | `Intlit i ->
        i
    | `Bool b ->
        if b then "true" else "false"
    | `Null ->
        "null"
    | `Assoc pairs ->
        sprintf "{%s}"
          ( List.filter_map pairs ~f:(fun (s, json) ->
                (* Special handling of fee payer party and verification key field names*)
                match (s, fee_payer) with
                | "use_full_commitment", true
                | "increment_nonce", true
                | "token_id", true ->
                    None
                | "sgn", _ ->
                    Some (sprintf "%s:%s" "sign" (go json level))
                | "verification_key", _ -> (
                    let vk_camel = underToCamel s in
                    match json with
                    | `List [ `String "Keep" ] ->
                        Some (sprintf "%s:%s" vk_camel "null")
                    | `List
                        [ `String "Set"
                        ; `Assoc [ ("data", vk); ("hash", vk_hash) ]
                        ] ->
                        let vk_with_hash =
                          sprintf "{%s:%s, %s:%s}" vk_camel
                            (go vk (level + 2))
                            "hash"
                            (go vk_hash (level + 2))
                        in
                        Some (sprintf "%s:%s" vk_camel vk_with_hash)
                    | _ ->
                        failwith "invalid verification key" )
                | _, _ ->
                    let cameled =
                      (* special handling for balance_change in Party.Fee_payer.t *)
                      if fee_payer && String.equal s "balance_change" then "fee"
                      else underToCamel s
                    in
                    Some (sprintf "%s:%s" cameled (go json (level + 2))))
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
        (* special handling of sign in Currency.Amount.Signed.t as Enums*)
    | `List [ `String "Neg" ] ->
        "MINUS"
    | `List [ `String "Pos" ] ->
        "PLUS"
    (*Special handling of permissions as Enums*)
    | `List [ `String "Proof" ] ->
        "Proof"
    | `List [ `String "Signature" ] ->
        "Signature"
    | `List [ `String "None" ] ->
        "None"
    | `List [ `String "Either" ] ->
        "Either"
    | `List [ `String "Both" ] ->
        "Both"
    | `List [ `String "Impossible" ] ->
        "Impossible"
    (* Predicate special handling *)
    | `List [ `String "Accept" ] ->
        go (`Assoc [ ("account", `Null); ("nonce", `Null) ]) level
    | `List [ `String "Nonce"; n ] ->
        go (`Assoc [ ("nonce", n) ]) level
    | `List [ `String "Full"; account ] ->
        go (`Assoc [ ("account", account) ]) level
    (* other constructors *)
    | `List [ `String name; value ] ->
        go (`Assoc [ (underToCamel name, value) ]) level
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
    Param.flag "--snapp-account-key"
      ~doc:"PUBLIC KEY Base58 encoded public key of the new snapp account"
      Param.(required public_key_compressed)

  let amount =
    Param.flag "--receiver-amount" ~doc:"NN Receiver amount in Mina"
      (Param.required txn_amount)

  let nonce =
    Param.flag "--nonce" ~doc:"NN Nonce of the fee payer account"
      Param.(required txn_nonce)

  let snapp_state =
    Param.flag "--snapp-state"
      ~doc:
        "FIELDS A list of 8 values that can be Integers, arbitrarty strings,  \
         hashes, or field elements"
      Param.(required txn_nonce)

  let common_flags =
    Command.(
      let open Let_syntax in
      let%map keyfile =
        Param.flag "--fee-payer-key"
          ~doc:
            "KEYFILE Private key file for the fee payer of the transaction \
             (should already be in the ledger)"
          Param.(required string)
      and fee = fee
      and nonce = nonce
      and memo = memo
      and debug =
        Param.flag "--debug" Param.no_arg
          ~doc:"Debug mode, generates transaction snark"
      in
      (keyfile, fee, nonce, memo, debug))
end

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
        failwith (sprintf "Invalid authorization: %s" s)
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

let create_snapp_account =
  let create_command ~debug ~keyfile ~fee ~snapp_keyfile ~amount ~nonce ~memo ()
      =
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
    Util.print_snapp_transaction parties ;
    let%map () = if debug then gen_proof parties else return () in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that creates a snapp account"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and amount = Flags.amount in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~snapp_keyfile ~amount ~nonce ~memo))

let upgrade_snapp =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
      ~verification_key ~snapp_uri ~auth () =
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
    Util.print_snapp_transaction parties ;
    let%map () =
      if debug then
        gen_proof parties
          ~snapp_account:
            (Some
               ( Signature_lib.Public_key.compress
                   snapp_account_keypair.public_key
               , vk ))
      else return ()
    in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates the verification key"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and verification_key =
         Param.flag "--verification-key"
           ~doc:"VERIFICATION_KEY the verification key for the snapp account"
           Param.(required string)
       and snapp_uri_str =
         Param.flag "--snapp-uri" ~doc:"URI the URI for the snapp account"
           Param.(optional string)
       and auth =
         Param.flag "--auth"
           ~doc:
             "Proof|Signature|Both|Either|None Current authorization in the \
              account to change the verification key"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let auth = Util.auth_of_string auth in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       let snapp_uri = Snapp_basic.Set_or_keep.of_option snapp_uri_str in
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~verification_key ~snapp_uri ~auth))

let transfer_funds =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~receivers () =
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
    Util.print_snapp_transaction parties ;
    let%map () =
      if debug then gen_proof parties ~snapp_account:None else return ()
    in
    ()
  in
  let read_key_and_amount count =
    let read () =
      let open Deferred.Let_syntax in
      printf "Receiver Key:%!" ;
      match%bind Reader.read_line (Lazy.force Reader.stdin) with
      | `Ok key -> (
          let pk =
            Signature_lib.Public_key.Compressed.of_base58_check_exn key
          in
          printf !"Amount:%!" ;
          match%map Reader.read_line (Lazy.force Reader.stdin) with
          | `Ok amt ->
              let amount = Currency.Amount.of_formatted_string amt in
              (pk, amount)
          | `Eof ->
              failwith "Invalid amount" )
      | `Eof ->
          failwith "Invalid key"
    in
    let rec go ?(prompt = true) count keys =
      if count <= 0 then return keys
      else if prompt then (
        printf "Continue? [N/y]\n%!" ;
        match%bind Reader.read_line (Lazy.force Reader.stdin) with
        | `Ok r ->
            if String.Caseless.equal r "y" then
              let%bind key = read () in
              go (count - 1) (key :: keys)
            else return keys
        | `Eof ->
            return keys )
      else
        let%bind key = read () in
        go (count - 1) (key :: keys)
    in
    printf "Enter at most %d receivers (Base58Check encoding) and amounts\n%!"
      count ;
    let%bind ks = go ~prompt:false 1 [] in
    go (count - 1) ks
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a snapp transaction that makes multiple transfers from one \
         account"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwithf "Fee must at least be %s"
           (Currency.Fee.to_formatted_string Flags.min_fee)
           () ;
       let max_keys = 10 in
       let receivers = read_key_and_amount max_keys in
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~receivers))

let update_state =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~app_state
      () =
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
    Util.print_snapp_transaction parties ;
    let%map () =
      if debug then
        gen_proof parties
          ~snapp_account:
            (Some
               (Signature_lib.Public_key.compress snapp_keypair.public_key, vk))
      else return ()
    in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates snapp state"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
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
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~app_state))

let update_snapp_uri =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~snapp_uri
      ~auth () =
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
    Util.print_snapp_transaction parties ;
    let%map () =
      if debug then
        gen_proof parties
          ~snapp_account:
            (Some
               ( Signature_lib.Public_key.compress
                   snapp_account_keypair.public_key
               , vk ))
      else return ()
    in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates the snapp uri"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and snapp_uri =
         Param.flag "--snapp-uri"
           ~doc:"SNAPP_URI The string to be used as the updated snapp uri"
           Param.(required string)
       and auth =
         Param.flag "--auth"
           ~doc:
             "Proof|Signature|Both|Either|None Current authorization in the \
              account to change the snapp uri"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let auth = Util.auth_of_string auth in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~snapp_uri ~auth))

let update_sequence_state =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
      ~sequence_state () =
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
    Util.print_snapp_transaction parties ;
    let%map () =
      if debug then
        gen_proof parties
          ~snapp_account:
            (Some
               (Signature_lib.Public_key.compress snapp_keypair.public_key, vk))
      else return ()
    in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates snapp state"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
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
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~sequence_state))

let update_token_symbol =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
      ~token_symbol ~auth () =
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
    Util.print_snapp_transaction parties ;
    let%map () =
      if debug then
        gen_proof parties
          ~snapp_account:
            (Some
               ( Signature_lib.Public_key.compress
                   snapp_account_keypair.public_key
               , vk ))
      else return ()
    in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates token symbol"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and token_symbol =
         Param.flag "--token-symbol"
           ~doc:"TOKEN_SYMBOL The string to be used as the updated token symbol"
           Param.(required string)
       and auth =
         Param.flag "--auth"
           ~doc:
             "Proof|Signature|Both|Either|None Current authorization in the \
              account to change the token symbol"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let auth = Util.auth_of_string auth in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~token_symbol ~auth))

let update_permissions =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
      ~permissions ~current_auth () =
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
    Util.print_snapp_transaction parties ;
    let%map () =
      if debug then
        gen_proof parties
          ~snapp_account:
            (Some
               (Signature_lib.Public_key.compress snapp_keypair.public_key, vk))
      else return ()
    in
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a snapp transaction that updates the permissions of a snapp \
         account"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
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
       and set_voting_for =
         Param.flag "--set-voting-for" ~doc:"Proof|Signature|Both|Either|None"
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
           ; set_voting_for = Util.auth_of_string set_voting_for
           }
       in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~permissions
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
  ; ("transfer-funds", transfer_funds)
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
