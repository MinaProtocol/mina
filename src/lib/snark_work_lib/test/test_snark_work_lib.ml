(** Wire round-trip for the zkApp segment spec across the V2/V3 boundary.

    [Sub_zkapp_spec.V3] carries a sok-less [Statement.t], matching what
    [Single_spec] has always done; V2 carried a [Statement.With_sok.t] whose
    digest was a placeholder sitting next to the authoritative one in
    [With_job_meta.sok_message]. A daemon serving a worker built before V3 has
    to convert, so both directions must be total and lossless in the sense that
    matters:

    - downgrade fills the segment's sok field from the job's own sok message, so
      an old worker sees the real digest rather than 32 zero bytes;
    - upgrade drops that field, which is exactly what the old
      [Sub_zkapp_spec.statement] did before returning. *)

open Core
open Mina_base
module Fixture = Transaction_snark_test_helpers.Zkapp_segment_fixture

let sok_message =
  Sok_message.create
    ~fee:(Currency.Fee.of_nanomina_int_exn 1_000_000)
    ~prover:
      (Quickcheck.random_value
         ~seed:(`Deterministic "snark-work-lib-segment-prover")
         Signature_lib.Public_key.Compressed.gen )

(** One real segment. Nothing here proves anything, so no proving circuit is
    compiled. *)
let segment =
  lazy
    (let fixture = Fixture.create ~seed:"snark-work-lib-zkapp-segment" in
     let state_body_hash =
       Mina_state.Protocol_state.Body.hash fixture.state_body
     in
     let witness, spec, statement =
       Transaction_snark.zkapp_command_witnesses_exn
         ~signature_kind:Fixture.signature_kind
         ~constraint_constants:Fixture.constraint_constants
         ~global_slot:fixture.global_slot ~state_body:fixture.state_body
         ~fee_excess:Currency.Amount.Signed.zero
         [ ( `Pending_coinbase_init_stack Pending_coinbase.Stack.empty
           , `Pending_coinbase_of_statement
               { Transaction_snark.Pending_coinbase_stack_state.source =
                   Pending_coinbase.Stack.empty
               ; target =
                   Pending_coinbase.Stack.push_state state_body_hash
                     fixture.global_slot Pending_coinbase.Stack.empty
               }
           , `Ledger fixture.first_pass_ledger
           , `Ledger fixture.second_pass_ledger
           , `Connecting_ledger_hash
               (Mina_ledger.Ledger.merkle_root fixture.second_pass_ledger)
           , fixture.zkapp_command )
         ]
       |> List.hd_exn
     in
     ( Transaction_witness.Zkapp_command_segment_witness
       .read_all_proofs_from_disk witness
     , spec
     , statement ) )

let job_id : Snark_work_lib.Id.Sub_zkapp.Stable.V1.t =
  { which_one = `One; pairing_id = 1L; range = { first = 0; last = 0 } }

let v3_spec () : Snark_work_lib.Spec.Partitioned.Stable.V3.t =
  let witness, spec, statement = Lazy.force segment in
  Sub_zkapp_command
    { spec =
        Snark_work_lib.Spec.Sub_zkapp.Stable.V3.Segment
          { statement; witness; spec }
    ; job_id
    ; sok_message
    }

let segment_statement_v2 (spec : Snark_work_lib.Spec.Partitioned.Stable.V2.t) =
  match spec with
  | Sub_zkapp_command
      { spec = Snark_work_lib.Spec.Sub_zkapp.Stable.V2.Segment { statement; _ }
      ; _
      } ->
      statement
  | _ ->
      failwith "expected a zkApp segment spec"

let segment_statement_v3 (spec : Snark_work_lib.Spec.Partitioned.Stable.V3.t) =
  match spec with
  | Sub_zkapp_command
      { spec = Snark_work_lib.Spec.Sub_zkapp.Stable.V3.Segment { statement; _ }
      ; _
      } ->
      statement
  | _ ->
      failwith "expected a zkApp segment spec"

(* The value the placeholder used to carry, and the value an old worker must no
   longer receive. *)
let test_downgrade_stamps_the_jobs_digest () =
  let statement =
    v3_spec () |> Snark_work_lib.Spec.Partitioned.Stable.V2.of_v3
    |> segment_statement_v2
  in
  let expected = Sok_message.digest sok_message in
  if Sok_message.Digest.equal statement.sok_digest Sok_message.Digest.default
  then
    Alcotest.fail
      "downgraded segment carries Sok_message.Digest.default; a pre-V3 worker \
       would be served the placeholder this change exists to remove"
  else if not (Sok_message.Digest.equal statement.sok_digest expected) then
    Alcotest.fail
      "downgraded segment carries a digest other than the job's sok message"

let test_downgrade_preserves_the_statement () =
  let v3 = v3_spec () in
  let downgraded =
    Snark_work_lib.Spec.Partitioned.Stable.V2.of_v3 v3 |> segment_statement_v2
  in
  Alcotest.(check bool)
    "statement is unchanged modulo the sok field" true
    (Transaction_snark.Statement.equal
       (Mina_state.Snarked_ledger_state.Poly.drop_sok downgraded)
       (segment_statement_v3 v3) )

let test_round_trip_is_the_identity () =
  let v3 = v3_spec () in
  let round_tripped =
    Snark_work_lib.Spec.Partitioned.Stable.V2.of_v3 v3
    |> Snark_work_lib.Spec.Partitioned.Stable.V2.to_latest
  in
  let sexp_of = Snark_work_lib.Spec.Partitioned.Stable.V3.sexp_of_t in
  Alcotest.(check bool)
    "V3 -> V2 -> V3 returns the spec unchanged, witness and segment spec \
     included"
    true
    (Sexp.equal (sexp_of v3) (sexp_of round_tripped))

let () =
  Alcotest.run "snark_work_lib"
    [ ( "zkapp segment spec wire round trip"
      , [ Alcotest.test_case "downgrade stamps the job's sok digest" `Quick
            test_downgrade_stamps_the_jobs_digest
        ; Alcotest.test_case "downgrade preserves the statement" `Quick
            test_downgrade_preserves_the_statement
        ; Alcotest.test_case "V3 -> V2 -> V3 is the identity" `Quick
            test_round_trip_is_the_identity
        ] )
    ]
