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
      { constraints = 12879
      ; public_input_size = 300
      ; auxiliary_input_size = 37508
      ; digest = "1dfb98ac348b112fd877a935e93de981"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 16306
      ; public_input_size = 300
      ; auxiliary_input_size = 73507
      ; digest = "c569c6296559ab2d9283af5be63080d2"
      }
  ; zkapp_opt_signed =
      { constraints = 8911
      ; public_input_size = 300
      ; auxiliary_input_size = 40626
      ; digest = "6fbd294f13e679a5ec6b574c72239976"
      }
  ; zkapp_proved =
      { constraints = 5133
      ; public_input_size = 300
      ; auxiliary_input_size = 39192
      ; digest = "65e2abc406b327579d0cd0bfb8b1d9a7"
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
      { constraints = 15361
      ; public_input_size = 300
      ; auxiliary_input_size = 63812
      ; digest = "d333a8775f3933ee95a8479ada9a4c6d"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 17975
      ; public_input_size = 300
      ; auxiliary_input_size = 91161
      ; digest = "821d4dc159ae412de7eb014ef8fcb4d4"
      }
  ; zkapp_opt_signed =
      { constraints = 9768
      ; public_input_size = 300
      ; auxiliary_input_size = 49630
      ; digest = "531ee48e97f76553bbfc4e0d17d0b0d7"
      }
  ; zkapp_proved =
      { constraints = 5990
      ; public_input_size = 300
      ; auxiliary_input_size = 48196
      ; digest = "687e69d85173bc1d3fb7666e88149294"
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
      { constraints = 15361
      ; public_input_size = 300
      ; auxiliary_input_size = 63812
      ; digest = "d333a8775f3933ee95a8479ada9a4c6d"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 17975
      ; public_input_size = 300
      ; auxiliary_input_size = 91161
      ; digest = "821d4dc159ae412de7eb014ef8fcb4d4"
      }
  ; zkapp_opt_signed =
      { constraints = 9768
      ; public_input_size = 300
      ; auxiliary_input_size = 49630
      ; digest = "531ee48e97f76553bbfc4e0d17d0b0d7"
      }
  ; zkapp_proved =
      { constraints = 5990
      ; public_input_size = 300
      ; auxiliary_input_size = 48196
      ; digest = "687e69d85173bc1d3fb7666e88149294"
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
      { constraints = 15361
      ; public_input_size = 300
      ; auxiliary_input_size = 63812
      ; digest = "73c5b4e21f6175030826168835add14f"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 17975
      ; public_input_size = 300
      ; auxiliary_input_size = 91161
      ; digest = "3b329817520e795ec394410e8035c2bb"
      }
  ; zkapp_opt_signed =
      { constraints = 9768
      ; public_input_size = 300
      ; auxiliary_input_size = 49630
      ; digest = "ae026cc5a7d975bfdc007b430f80fe40"
      }
  ; zkapp_proved =
      { constraints = 5990
      ; public_input_size = 300
      ; auxiliary_input_size = 48196
      ; digest = "c79978a86eeda772692f786c820db168"
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
