(** Test to verify the constraint counts, public input sizes, auxiliary
    input sizes, and digests of transaction SNARK circuits.

    Each circuit is tested by creating its constraint system once and
    checking all expected values.

    The transaction SNARK has 5 rules:
    1. Base ("transaction") - Single non-zkApp transaction
    2. Merge ("merge") - Combines two proofs
    3. ZkApp Opt_signed_opt_signed - 2 optional signatures
    4. ZkApp Opt_signed - 1 optional signature
    5. ZkApp Proved - Side-loaded proof

    In production, these 5 circuits are compiled together via [Pickles.compile]
    in [Transaction_snark.system]. The test helpers here use [Tick.constraint_system]
    to extract each circuit's constraint system individually, which produces the
    same constraints as the production compilation.

    This is useful for:
    - Tracking constraint count changes over time
    - Comparing with a Rust reimplementation
    - Performance analysis

    IMPORTANT: If these tests fail due to changed constraint counts, public
    input sizes, auxiliary input sizes, or digests, update the expected values
    below AND the table in [transaction_snark_intf.ml] to keep the documentation
    in sync.

    NOTE: Expected values vary by profile (dev, devnet, lightnet, mainnet) as
    constraint counts depend on configuration parameters like ledger depth. *)

open Core

(** Expected values for a single circuit *)
type circuit_stats =
  { constraints : int
  ; public_input_size : int
  ; auxiliary_input_size : int
  ; digest : string
  }

(** Expected values for all circuits in a profile *)
type profile_expected_values =
  { transaction_merge : circuit_stats
  ; transaction_base : circuit_stats
  ; zkapp_opt_signed_opt_signed : circuit_stats
  ; zkapp_opt_signed : circuit_stats
  ; zkapp_proved : circuit_stats
  }

let dev_expected_values =
  { transaction_merge =
      { constraints = 684
      ; public_input_size = 306
      ; auxiliary_input_size = 2363
      ; digest = "edc7b6980f273553cbbc34d7d18f4032"
      }
  ; transaction_base =
      { constraints = 13004
      ; public_input_size = 306
      ; auxiliary_input_size = 38407
      ; digest = "b6addeadb03dd4167bec186aaf769b2e"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 16494
      ; public_input_size = 306
      ; auxiliary_input_size = 74549
      ; digest = "fa02a6abc93c023d09489c75f0106705"
      }
  ; zkapp_opt_signed =
      { constraints = 9032
      ; public_input_size = 306
      ; auxiliary_input_size = 41436
      ; digest = "9619e5062338a7ce525d8e80a10c5bd4"
      }
  ; zkapp_proved =
      { constraints = 5245
      ; public_input_size = 306
      ; auxiliary_input_size = 39994
      ; digest = "bdb13e750a15a8c3b39834ce6bbb1014"
      }
  }

let devnet_expected_values =
  { transaction_merge =
      { constraints = 684
      ; public_input_size = 306
      ; auxiliary_input_size = 2363
      ; digest = "edc7b6980f273553cbbc34d7d18f4032"
      }
  ; transaction_base =
      { constraints = 15486
      ; public_input_size = 306
      ; auxiliary_input_size = 64711
      ; digest = "daaccb0846ac3e4d9efd1ad16c073ef7"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 18164
      ; public_input_size = 306
      ; auxiliary_input_size = 92203
      ; digest = "cac2babf9be89f5963cf272bbfe591ef"
      }
  ; zkapp_opt_signed =
      { constraints = 9889
      ; public_input_size = 306
      ; auxiliary_input_size = 50440
      ; digest = "a8377c5b84bf865cd9ff98ac69d741b7"
      }
  ; zkapp_proved =
      { constraints = 6102
      ; public_input_size = 306
      ; auxiliary_input_size = 48998
      ; digest = "443762b07f4c0d15ab7c6c9c2d7377be"
      }
  }

let lightnet_expected_values =
  { transaction_merge =
      { constraints = 684
      ; public_input_size = 306
      ; auxiliary_input_size = 2363
      ; digest = "edc7b6980f273553cbbc34d7d18f4032"
      }
  ; transaction_base =
      { constraints = 15486
      ; public_input_size = 306
      ; auxiliary_input_size = 64711
      ; digest = "daaccb0846ac3e4d9efd1ad16c073ef7"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 18164
      ; public_input_size = 306
      ; auxiliary_input_size = 92203
      ; digest = "cac2babf9be89f5963cf272bbfe591ef"
      }
  ; zkapp_opt_signed =
      { constraints = 9889
      ; public_input_size = 306
      ; auxiliary_input_size = 50440
      ; digest = "a8377c5b84bf865cd9ff98ac69d741b7"
      }
  ; zkapp_proved =
      { constraints = 6102
      ; public_input_size = 306
      ; auxiliary_input_size = 48998
      ; digest = "443762b07f4c0d15ab7c6c9c2d7377be"
      }
  }

let mainnet_expected_values =
  { transaction_merge =
      { constraints = 684
      ; public_input_size = 306
      ; auxiliary_input_size = 2363
      ; digest = "edc7b6980f273553cbbc34d7d18f4032"
      }
  ; transaction_base =
      { constraints = 15486
      ; public_input_size = 306
      ; auxiliary_input_size = 64711
      ; digest = "b289d4418ab5596973b8606115f48e4f"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 18164
      ; public_input_size = 306
      ; auxiliary_input_size = 92203
      ; digest = "1574432e419856ed5134ec2d990e5569"
      }
  ; zkapp_opt_signed =
      { constraints = 9889
      ; public_input_size = 306
      ; auxiliary_input_size = 50440
      ; digest = "33f23f60e9cd56dbb9c5ab40826f3e13"
      }
  ; zkapp_proved =
      { constraints = 6102
      ; public_input_size = 306
      ; auxiliary_input_size = 48998
      ; digest = "b53e1b0f0c11b33b516e6765d2a1bcbb"
      }
  }

let expected_values =
  match Node_config.profile with
  | "dev" ->
      dev_expected_values
  | "devnet" ->
      devnet_expected_values
  | "lightnet" ->
      lightnet_expected_values
  | "mainnet" ->
      mainnet_expected_values
  | p ->
      failwithf "Unknown profile: %s" p ()

(** Helper to check all circuit stats at once *)
let check_circuit_stats ~name ~expected cs =
  let actual_constraints =
    Snark_params.Tick.R1CS_constraint_system.get_rows_len cs
  in
  let actual_public_input_size =
    Set_once.get_exn
      (Snark_params.Tick.R1CS_constraint_system.get_public_input_size cs)
      [%here]
  in
  let actual_auxiliary_input_size =
    Set_once.get_exn
      (Snark_params.Tick.R1CS_constraint_system.get_auxiliary_input_size cs)
      [%here]
  in
  let actual_digest =
    Md5_lib.to_hex (Snark_params.Tick.R1CS_constraint_system.digest cs)
  in
  Alcotest.(check int)
    (Printf.sprintf "%s constraint count" name)
    expected.constraints actual_constraints ;
  Alcotest.(check int)
    (Printf.sprintf "%s public input size" name)
    expected.public_input_size actual_public_input_size ;
  Alcotest.(check int)
    (Printf.sprintf "%s auxiliary input size" name)
    expected.auxiliary_input_size actual_auxiliary_input_size ;
  Alcotest.(check string)
    (Printf.sprintf "%s digest" name)
    expected.digest actual_digest

(** Test transaction-merge circuit *)
let test_transaction_merge () =
  let cs = Transaction_snark.merge_constraint_system () in
  check_circuit_stats ~name:"transaction-merge"
    ~expected:expected_values.transaction_merge cs

(** Test transaction-base circuit *)
let test_transaction_base () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let (module G) = Genesis_constants.profiled () in
  let constraint_constants = G.constraint_constants in
  let cs =
    Transaction_snark.base_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"transaction-base"
    ~expected:expected_values.transaction_base cs

(** Test zkapp-opt_signed-opt_signed circuit *)
let test_zkapp_opt_signed_opt_signed () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let (module G) = Genesis_constants.profiled () in
  let constraint_constants = G.constraint_constants in
  let cs =
    Transaction_snark.zkapp_opt_signed_opt_signed_constraint_system
      ~signature_kind ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-opt_signed-opt_signed"
    ~expected:expected_values.zkapp_opt_signed_opt_signed cs

(** Test zkapp-opt_signed circuit *)
let test_zkapp_opt_signed () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let (module G) = Genesis_constants.profiled () in
  let constraint_constants = G.constraint_constants in
  let cs =
    Transaction_snark.zkapp_opt_signed_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-opt_signed"
    ~expected:expected_values.zkapp_opt_signed cs

(** Test zkapp-proved circuit *)
let test_zkapp_proved () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in

  let (module G) = Genesis_constants.profiled () in
  let constraint_constants = G.constraint_constants in
  let cs =
    Transaction_snark.zkapp_proved_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-proved"
    ~expected:expected_values.zkapp_proved cs

let () =
  let open Alcotest in
  run "Transaction Snark Circuit Stats"
    [ ("transaction-merge", [ test_case "stats" `Slow test_transaction_merge ])
    ; ("transaction-base", [ test_case "stats" `Slow test_transaction_base ])
    ; ( "zkapp-opt_signed-opt_signed"
      , [ test_case "stats" `Slow test_zkapp_opt_signed_opt_signed ] )
    ; ("zkapp-opt_signed", [ test_case "stats" `Slow test_zkapp_opt_signed ])
    ; ("zkapp-proved", [ test_case "stats" `Slow test_zkapp_proved ])
    ]
