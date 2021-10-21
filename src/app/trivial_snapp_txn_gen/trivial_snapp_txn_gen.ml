open Core
open Async
open Mina_base

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let proof_level = Genesis_constants.Proof_level.Full

let generate_snapp_txn (keypair : Signature_lib.Keypair.t) (ledger : Ledger.t) =
  let open Deferred.Let_syntax in
  let receiver =
    Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
  in
  let spec =
    { Transaction_logic.For_tests.Transaction_spec.sender =
        (keypair, Account.Nonce.zero)
    ; fee = Currency.Amount.of_int 1000000000 (*1 Mina*)
    ; receiver
    ; amount = Currency.Amount.of_int 10000000000 (*10 Mina*)
    }
  in
  let%map parties =
    Transaction_snark.For_tests.create_trivial_predicate_snapp spec ledger
  in
  Core.printf "Snapp transaction: %s\n%!"
    (Parties.to_yojson parties |> Yojson.Safe.to_string)

let main keyfile config_file () =
  let open Deferred.Let_syntax in
  let%bind keypair =
    Secrets.Keypair.Terminal_stdin.read_exn ~should_prompt_user:false
      ~which:"payment keypair" keyfile
  in
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

let () =
  Command.(
    run
      (let open Let_syntax in
      Command.async ~summary:"Generate a trivial snapp transaction for testing"
        (let%map keyfile =
           Param.flag "--fee-payer-key"
             ~doc:
               "KEYFILE Private key file for the fee payer of the transaction"
             Param.(required string)
         and config_file =
           Param.flag "--config-file" ~aliases:[ "config-file" ]
             ~doc:
               "PATH path to a configuration file consisting the genesis ledger"
             Param.(required string)
         in
         main keyfile config_file)))
