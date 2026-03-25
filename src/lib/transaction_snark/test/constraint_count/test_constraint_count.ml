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

open Core_kernel

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
      { constraints = 632
      ; public_input_size = 300
      ; auxiliary_input_size = 1895
      ; digest = "b8879f677f622a1d86648030701f43e1"
      }
  ; transaction_base =
      { constraints = 12875
      ; public_input_size = 300
      ; auxiliary_input_size = 37502
      ; digest = "740db2397b0b01806a48f061a2e2b063"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 16314
      ; public_input_size = 300
      ; auxiliary_input_size = 73512
      ; digest = "20f96be9061c1e15e49e4605b82eda14"
      }
  ; zkapp_opt_signed =
      { constraints = 8915
      ; public_input_size = 300
      ; auxiliary_input_size = 40628
      ; digest = "3bec20ed2f245ab5bf831112efbd6b47"
      }
  ; zkapp_proved =
      { constraints = 5137
      ; public_input_size = 300
      ; auxiliary_input_size = 39194
      ; digest = "69d2537da34047df00f856641b63e255"
      }
  }

let devnet_expected_values =
  { transaction_merge =
      { constraints = 632
      ; public_input_size = 300
      ; auxiliary_input_size = 1895
      ; digest = "b8879f677f622a1d86648030701f43e1"
      }
  ; transaction_base =
      { constraints = 15357
      ; public_input_size = 300
      ; auxiliary_input_size = 63806
      ; digest = "3bf6bb8a97665fe7a9df6fc146e4f942"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 17983
      ; public_input_size = 300
      ; auxiliary_input_size = 91166
      ; digest = "4f386c1183e5eb2339448af2b3561147"
      }
  ; zkapp_opt_signed =
      { constraints = 9772
      ; public_input_size = 300
      ; auxiliary_input_size = 49632
      ; digest = "f3a4815da42338a36753a9a70316b0da"
      }
  ; zkapp_proved =
      { constraints = 5994
      ; public_input_size = 300
      ; auxiliary_input_size = 48198
      ; digest = "0ae9ea554906e54b70040aca15b59b76"
      }
  }

let lightnet_expected_values =
  { transaction_merge =
      { constraints = 632
      ; public_input_size = 300
      ; auxiliary_input_size = 1895
      ; digest = "b8879f677f622a1d86648030701f43e1"
      }
  ; transaction_base =
      { constraints = 15357
      ; public_input_size = 300
      ; auxiliary_input_size = 63806
      ; digest = "3bf6bb8a97665fe7a9df6fc146e4f942"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 17983
      ; public_input_size = 300
      ; auxiliary_input_size = 91166
      ; digest = "4f386c1183e5eb2339448af2b3561147"
      }
  ; zkapp_opt_signed =
      { constraints = 9772
      ; public_input_size = 300
      ; auxiliary_input_size = 49632
      ; digest = "f3a4815da42338a36753a9a70316b0da"
      }
  ; zkapp_proved =
      { constraints = 5994
      ; public_input_size = 300
      ; auxiliary_input_size = 48198
      ; digest = "0ae9ea554906e54b70040aca15b59b76"
      }
  }

let mainnet_expected_values =
  { transaction_merge =
      { constraints = 632
      ; public_input_size = 300
      ; auxiliary_input_size = 1895
      ; digest = "b8879f677f622a1d86648030701f43e1"
      }
  ; transaction_base =
      { constraints = 15357
      ; public_input_size = 300
      ; auxiliary_input_size = 63806
      ; digest = "d31948e661cc662675b0c079458f714a"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 17983
      ; public_input_size = 300
      ; auxiliary_input_size = 91166
      ; digest = "72c5328778d608cfb3dcebbf21bdc34e"
      }
  ; zkapp_opt_signed =
      { constraints = 9772
      ; public_input_size = 300
      ; auxiliary_input_size = 49632
      ; digest = "56902d7807c649e45e6442c923030cbf"
      }
  ; zkapp_proved =
      { constraints = 5994
      ; public_input_size = 300
      ; auxiliary_input_size = 48198
      ; digest = "9c4689245850e55ac1fe69647992462b"
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
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let cs =
    Transaction_snark.base_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"transaction-base"
    ~expected:expected_values.transaction_base cs

(** Test zkapp-opt_signed-opt_signed circuit *)
let test_zkapp_opt_signed_opt_signed () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let cs =
    Transaction_snark.zkapp_opt_signed_opt_signed_constraint_system
      ~signature_kind ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-opt_signed-opt_signed"
    ~expected:expected_values.zkapp_opt_signed_opt_signed cs

(** Test zkapp-opt_signed circuit *)
let test_zkapp_opt_signed () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let cs =
    Transaction_snark.zkapp_opt_signed_constraint_system ~signature_kind
      ~constraint_constants
  in
  check_circuit_stats ~name:"zkapp-opt_signed"
    ~expected:expected_values.zkapp_opt_signed cs

(** Test zkapp-proved circuit *)
let test_zkapp_proved () =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
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
