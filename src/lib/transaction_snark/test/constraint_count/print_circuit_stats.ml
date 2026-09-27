(** Print the constraint system statistics of each transaction SNARK circuit as
    JSON.

    The transaction SNARK has 5 rules:
    1. Base ("transaction") - Single non-zkApp transaction
    2. Merge ("merge") - Combines two proofs
    3. ZkApp Opt_signed_opt_signed - 2 optional signatures
    4. ZkApp Opt_signed - 1 optional signature
    5. ZkApp Proved - Side-loaded proof

    In production these 5 circuits are compiled together via [Pickles.compile]
    in [Transaction_snark.system]. Here each constraint system is extracted
    individually with [Tick.constraint_system], which produces the same
    constraints as the production compilation.

    The output is compared against the checked-in [<profile>_circuit_stats.json]
    by the [runtest] alias, so a change in circuit shape appears as a diff and
    is accepted with [dune promote]. Values vary by profile because constraint
    counts depend on configuration parameters such as the ledger depth.

    If these values change, update the table in [transaction_snark_intf.ml] to
    keep the documentation in sync. *)

open Core

let stats_of_constraint_system cs =
  let constraints = Snark_params.Tick.R1CS_constraint_system.get_rows_len cs in
  let public_input_size =
    Set_once.get_exn
      (Snark_params.Tick.R1CS_constraint_system.get_public_input_size cs)
      [%here]
  in
  let auxiliary_input_size =
    Set_once.get_exn
      (Snark_params.Tick.R1CS_constraint_system.get_auxiliary_input_size cs)
      [%here]
  in
  let digest =
    Md5_lib.to_hex (Snark_params.Tick.R1CS_constraint_system.digest cs)
  in
  `Assoc
    [ ("constraints", `Int constraints)
    ; ("public_input_size", `Int public_input_size)
    ; ("auxiliary_input_size", `Int auxiliary_input_size)
    ; ("digest", `String digest)
    ]

let () =
  Format.eprintf "Profile: %s@." Node_config.profile ;
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let (module G) = Genesis_constants.profiled () in
  let constraint_constants = G.constraint_constants in
  let circuits =
    [ ("transaction-merge", Transaction_snark.merge_constraint_system ())
    ; ( "transaction-base"
      , Transaction_snark.base_constraint_system ~signature_kind
          ~constraint_constants )
    ; ( "zkapp-opt_signed-opt_signed"
      , Transaction_snark.zkapp_opt_signed_opt_signed_constraint_system
          ~signature_kind ~constraint_constants )
    ; ( "zkapp-opt_signed"
      , Transaction_snark.zkapp_opt_signed_constraint_system ~signature_kind
          ~constraint_constants )
    ; ( "zkapp-proved"
      , Transaction_snark.zkapp_proved_constraint_system ~signature_kind
          ~constraint_constants )
    ]
  in
  `Assoc
    (List.map circuits ~f:(fun (name, cs) ->
         (name, stats_of_constraint_system cs) ) )
  |> Yojson.Safe.pretty_to_string |> print_endline
