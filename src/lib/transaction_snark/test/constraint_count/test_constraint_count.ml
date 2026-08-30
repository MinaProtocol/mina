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
      { constraints = 564
      ; public_input_size = 298
      ; auxiliary_input_size = 1761
      ; digest = "bdabeb841fc2361392dd6ac6e541a944"
      }
  ; transaction_base =
      { constraints = 12864
      ; public_input_size = 298
      ; auxiliary_input_size = 37375
      ; digest = "84bc56d329c4c4fc1568a5a431373b64"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 16321
      ; public_input_size = 298
      ; auxiliary_input_size = 73353
      ; digest = "471126c9da562837da265347db388edf"
      }
  ; zkapp_opt_signed =
      { constraints = 8913
      ; public_input_size = 298
      ; auxiliary_input_size = 40463
      ; digest = "6922e2397468e7f88ef7a52b0779a6c1"
      }
  ; zkapp_proved =
      { constraints = 5136
      ; public_input_size = 298
      ; auxiliary_input_size = 39029
      ; digest = "4dd774a3dfb922dc016c920a5e479163"
      }
  }

let devnet_expected_values =
  { transaction_merge =
      { constraints = 564
      ; public_input_size = 298
      ; auxiliary_input_size = 1761
      ; digest = "bdabeb841fc2361392dd6ac6e541a944"
      }
  ; transaction_base =
      { constraints = 15357
      ; public_input_size = 298
      ; auxiliary_input_size = 63807
      ; digest = "3bf6bb8a97665fe7a9df6fc146e4f942"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 18001
      ; public_input_size = 298
      ; auxiliary_input_size = 91179
      ; digest = "614aec09ed5e4068f46d010f0070226b"
      }
  ; zkapp_opt_signed =
      { constraints = 9781
      ; public_input_size = 298
      ; auxiliary_input_size = 49639
      ; digest = "0fe3381f501f432744727c296be464b0"
      }
  ; zkapp_proved =
      { constraints = 6003
      ; public_input_size = 298
      ; auxiliary_input_size = 48205
      ; digest = "cad581432831f10fee99161532504937"
      }
  }

let lightnet_expected_values =
  { transaction_merge =
      { constraints = 564
      ; public_input_size = 298
      ; auxiliary_input_size = 1761
      ; digest = "bdabeb841fc2361392dd6ac6e541a944"
      }
  ; transaction_base =
      { constraints = 15357
      ; public_input_size = 298
      ; auxiliary_input_size = 63807
      ; digest = "3bf6bb8a97665fe7a9df6fc146e4f942"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 18001
      ; public_input_size = 298
      ; auxiliary_input_size = 91179
      ; digest = "614aec09ed5e4068f46d010f0070226b"
      }
  ; zkapp_opt_signed =
      { constraints = 9781
      ; public_input_size = 298
      ; auxiliary_input_size = 49639
      ; digest = "0fe3381f501f432744727c296be464b0"
      }
  ; zkapp_proved =
      { constraints = 6003
      ; public_input_size = 298
      ; auxiliary_input_size = 48205
      ; digest = "cad581432831f10fee99161532504937"
      }
  }

let mainnet_expected_values =
  { transaction_merge =
      { constraints = 564
      ; public_input_size = 298
      ; auxiliary_input_size = 1761
      ; digest = "bdabeb841fc2361392dd6ac6e541a944"
      }
  ; transaction_base =
      { constraints = 15357
      ; public_input_size = 298
      ; auxiliary_input_size = 63807
      ; digest = "d31948e661cc662675b0c079458f714a"
      }
  ; zkapp_opt_signed_opt_signed =
      { constraints = 18001
      ; public_input_size = 298
      ; auxiliary_input_size = 91179
      ; digest = "ddaa38405c20a8f7a7cf5235c1ed1713"
      }
  ; zkapp_opt_signed =
      { constraints = 9781
      ; public_input_size = 298
      ; auxiliary_input_size = 49639
      ; digest = "d048877d85e30a1ff9ff4cbdfcc33639"
      }
  ; zkapp_proved =
      { constraints = 6003
      ; public_input_size = 298
      ; auxiliary_input_size = 48205
      ; digest = "2d8810bdbda316e4b1f9f41ae1b28f6c"
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
