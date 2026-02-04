(** Tests for the blockchain SNARK.

    This includes constraint count, public input size, auxiliary input size,
    and digest tests.

    In production, the blockchain-step circuit is compiled via [Pickles.compile]
    in [Blockchain_snark_state.Make]. The test helpers here use [Tick.constraint_system]
    via [step_constraint_system] to extract the circuit's constraint system,
    which produces the same constraints as the production compilation.

    IMPORTANT: If the constraint count, public input size, auxiliary input size,
    or digest tests fail due to changed values, update the expected values below
    AND the table in [blockchain_snark_state.mli] to keep the documentation
    in sync.

    NOTE: Expected values vary by profile (dev, devnet, lightnet, mainnet) as
    constraint counts depend on configuration parameters like ledger depth. *)

open Core_kernel

(** Expected values for the blockchain-step circuit *)
type circuit_stats =
  { constraints : int
  ; public_input_size : int
  ; auxiliary_input_size : int
  ; digest : string
  }

let dev_expected_values =
  { constraints = 9168
  ; public_input_size = 1
  ; auxiliary_input_size = 31925
  ; digest = "36786c300e37c2a2f1341ad6374aa113"
  }

let devnet_expected_values =
  { constraints = 10224
  ; public_input_size = 1
  ; auxiliary_input_size = 39397
  ; digest = "35f0209250e81bc60f7729f734498e43"
  }

let lightnet_expected_values =
  { constraints = 10126
  ; public_input_size = 1
  ; auxiliary_input_size = 38359
  ; digest = "c480c7b16d46d52d439c93a9a84a5848"
  }

let mainnet_expected_values =
  { constraints = 10224
  ; public_input_size = 1
  ; auxiliary_input_size = 39397
  ; digest = "35f0209250e81bc60f7729f734498e43"
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

(** Test blockchain-step circuit stats *)
let test_blockchain_step () =
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let proof_level = Genesis_constants.Proof_level.Full in
  let cs =
    Blockchain_snark.Blockchain_snark_state.step_constraint_system ~proof_level
      ~constraint_constants
  in
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
    "blockchain-step constraint count" expected_values.constraints
    actual_constraints ;
  Alcotest.(check int)
    "blockchain-step public input size" expected_values.public_input_size
    actual_public_input_size ;
  Alcotest.(check int)
    "blockchain-step auxiliary input size" expected_values.auxiliary_input_size
    actual_auxiliary_input_size ;
  Alcotest.(check string)
    "blockchain-step digest" expected_values.digest actual_digest

let () =
  let open Alcotest in
  run "Blockchain Snark Tests"
    [ ("blockchain-step", [ test_case "stats" `Slow test_blockchain_step ]) ]
