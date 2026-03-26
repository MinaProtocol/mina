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
      { constraints = 681
      ; public_input_size = 306
      ; auxiliary_input_size = 2357
      ; digest = "30707032b2f4ea75e1212304127cf79b"
      }
  ; transaction_base =
      { constraints = 12983
      ; public_input_size = 306
      ; auxiliary_input_size = 38008
      ; digest = "9dbaec8f42108bdfdc99fc4cb79b9993"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 14660
      ; public_input_size = 306
      ; auxiliary_input_size = 57199
      ; digest = "e3e8aa98b4c004ee9c251ba27dad1f5a"
      }
  ; zkapp_opt_signed =
      { constraints = 8102
      ; public_input_size = 306
      ; auxiliary_input_size = 32608
      ; digest = "23161295e4dd41f60ae2ee225befd85a"
      }
  ; zkapp_proved =
      { constraints = 4325
      ; public_input_size = 306
      ; auxiliary_input_size = 31174
      ; digest = "ba5cc9369f5e33db912b97d3db46e1e0"
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
      ; auxiliary_input_size = 63811
      ; digest = "d333a8775f3933ee95a8479ada9a4c6d"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 16198
      ; public_input_size = 300
      ; auxiliary_input_size = 74236
      ; digest = "8100029bd1bde94883d99934fc2b60c9"
      }
  ; zkapp_opt_signed =
      { constraints = 8879
      ; public_input_size = 300
      ; auxiliary_input_size = 41167
      ; digest = "a5dcb1ab276ea0d9180830982686a410"
      }
  ; zkapp_proved =
      { constraints = 5102
      ; public_input_size = 300
      ; auxiliary_input_size = 39733
      ; digest = "10499e2f8137a48a59b5948d0a0016da"
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
      ; auxiliary_input_size = 63811
      ; digest = "d333a8775f3933ee95a8479ada9a4c6d"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 16198
      ; public_input_size = 300
      ; auxiliary_input_size = 74236
      ; digest = "8100029bd1bde94883d99934fc2b60c9"
      }
  ; zkapp_opt_signed =
      { constraints = 8879
      ; public_input_size = 300
      ; auxiliary_input_size = 41167
      ; digest = "a5dcb1ab276ea0d9180830982686a410"
      }
  ; zkapp_proved =
      { constraints = 5102
      ; public_input_size = 300
      ; auxiliary_input_size = 39733
      ; digest = "10499e2f8137a48a59b5948d0a0016da"
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
      ; auxiliary_input_size = 63811
      ; digest = "73c5b4e21f6175030826168835add14f"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 16198
      ; public_input_size = 300
      ; auxiliary_input_size = 74236
      ; digest = "8dd71a49b71810a5739f434f6149c6d9"
      }
  ; zkapp_opt_signed =
      { constraints = 8879
      ; public_input_size = 300
      ; auxiliary_input_size = 41167
      ; digest = "3ba55ee30ff7c329427319456eb9affe"
      }
  ; zkapp_proved =
      { constraints = 5102
      ; public_input_size = 300
      ; auxiliary_input_size = 39733
      ; digest = "1513ccb8649556051c855f66cb18026b"
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
