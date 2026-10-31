open Core

module Cql = struct
  (** Render [s] as a CQL string literal. CQL has no backslash escapes: a
      single quote inside a literal is written as two. *)
  let string_literal s =
    "'" ^ String.substr_replace_all s ~pattern:"'" ~with_:"''" ^ "'"

  let%test_module "string_literal" =
    ( module struct
      let%test "plain text is wrapped in quotes" =
        String.equal (string_literal "dlog_check") "'dlog_check'"

      let%test "the empty string is an empty literal" =
        String.equal (string_literal "") "''"

      let%test "embedded single quotes are doubled" =
        String.equal
          (string_literal "can't open '/tmp/x'")
          "'can''t open ''/tmp/x'''"

      let%test "backslashes are not escapes" =
        String.equal (string_literal "a\\'b") "'a\\''b'"
    end )
end

(** The outcome of verifying a submission.

    [verified] and [validation_error] are two views of the same fact, so both
    are always emitted together from here: a submission is verified exactly
    when it carries no validation error. Building the two fields separately at
    each output site is what let them disagree, reporting [verified: true]
    alongside a proof failure. *)
module Verification_status = struct
  type t = Verified | Failed of string

  let of_or_error = function
    | Ok _ ->
        Verified
    | Error e ->
        Failed (Error.to_string_hum e)

  let to_json_fields = function
    | Verified ->
        [ ("verified", `Bool true); ("validation_error", `Null) ]
    | Failed e ->
        [ ("verified", `Bool false); ("validation_error", `String e) ]

  let to_cassandra_updates = function
    | Verified ->
        [ ("verified", "true"); ("validation_error", "NULL") ]
    | Failed e ->
        [ ("verified", "false"); ("validation_error", Cql.string_literal e) ]

  let%test_module "verified and validation_error cannot disagree" =
    ( module struct
      let statuses = [ Verified; Failed "(Pickles.verify dlog_check)" ]

      let field fields name =
        List.Assoc.find_exn fields name ~equal:String.equal

      let%test "json: verified is true exactly when there is no error" =
        List.for_all statuses ~f:(fun status ->
            let fields = to_json_fields status in
            let verified =
              match field fields "verified" with
              | `Bool b ->
                  b
              | _ ->
                  failwith "verified is not a boolean"
            in
            let no_error =
              match field fields "validation_error" with
              | `Null ->
                  true
              | _ ->
                  false
            in
            Bool.equal verified no_error )

      (* An absent validation_error column counts as no error: a caller reading
         the row cannot tell it from an explicit NULL. *)
      let%test "cassandra: verified is true exactly when there is no error" =
        List.for_all statuses ~f:(fun status ->
            let fields = to_cassandra_updates status in
            let no_error =
              match
                List.Assoc.find fields "validation_error" ~equal:String.equal
              with
              | None | Some "NULL" ->
                  true
              | Some _ ->
                  false
            in
            Bool.equal (String.equal (field fields "verified") "true") no_error )

      let%test "a failed submission reports its reason" =
        let fields = to_json_fields (Failed "(Pickles.verify dlog_check)") in
        match (field fields "verified", field fields "validation_error") with
        | `Bool false, `String "(Pickles.verify dlog_check)" ->
            true
        | _ ->
            false

      let%test "cassandra: quotes in the reason are escaped" =
        let fields = to_cassandra_updates (Failed "can't read 'block.dat'") in
        String.equal
          (field fields "validation_error")
          "'can''t read ''block.dat'''"

      let%test "of_or_error carries the error text through" =
        match of_or_error (Error (Error.of_string "boom")) with
        | Failed "boom" ->
            true
        | Verified | Failed _ ->
            false
    end )
end

(** Ties the attached snark work to the submitted block.

    The sok message binds a proof to the submitter and the fee only, so a
    valid proof could be reattached to every later submission of the same
    submitter. The uptime service picks the job whose target second-pass
    ledger is the staged ledger of the block it reports
    ([Uptime_service.send_block_and_transaction_snark]); the verifier requires
    the same relation, so the work has to come from the submitted block. *)
module Snark_work = struct
  open Mina_base

  let check_belongs_to_block ~(block_staged_ledger_hash : Staged_ledger_hash.t)
      ~(proof : Ledger_proof.t) =
    let block_ledger_hash =
      Staged_ledger_hash.ledger_hash block_staged_ledger_hash
    in
    let proof_target_ledger_hash =
      (Ledger_proof.statement proof).target.second_pass_ledger
    in
    if Ledger_hash.equal proof_target_ledger_hash block_ledger_hash then Ok ()
    else
      Or_error.errorf
        "proof's target ledger %s does not match the submitted block's staged \
         ledger %s"
        (Ledger_hash.to_base58_check proof_target_ledger_hash)
        (Ledger_hash.to_base58_check block_ledger_hash)

  let%test_module "check_belongs_to_block" =
    ( module struct
      let ledger_hashes =
        Quickcheck.random_value
          ~seed:(`Deterministic "delegation-verify-block-binding")
          (Quickcheck.Generator.list_with_length 2 Frozen_ledger_hash.gen)

      let block_ledger_hash = List.nth_exn ledger_hashes 0

      let other_ledger_hash = List.nth_exn ledger_hashes 1

      let fee = Currency.Fee.of_nanomina_int_exn 1_000_000

      let prover =
        Quickcheck.random_value
          ~seed:(`Deterministic "delegation-verify-submitter")
          Signature_lib.Public_key.Compressed.gen

      (* A proof whose statement ends on [target_ledger], as the uptime service
         produces for a block whose staged ledger is [target_ledger]. *)
      let proof_targeting target_ledger =
        let statement =
          Mina_state.Snarked_ledger_state.genesis
            ~genesis_ledger_hash:other_ledger_hash
        in
        let statement =
          { statement with
            target =
              { statement.target with second_pass_ledger = target_ledger }
          }
        in
        Ledger_proof.For_tests.mk_dummy_proof ~statement ~fee ~prover

      let staged_ledger_hash_of ledger_hash =
        Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
          (Staged_ledger_hash.Aux_hash.of_bytes (String.make 32 '\000'))
          ledger_hash
          (Pending_coinbase.create ~depth:3 () |> Or_error.ok_exn)

      let%test "work on the submitted block is accepted" =
        check_belongs_to_block
          ~block_staged_ledger_hash:(staged_ledger_hash_of block_ledger_hash)
          ~proof:(proof_targeting block_ledger_hash)
        |> Or_error.is_ok

      (* A valid proof for a different block, with the same fee and submitter,
         used to pass: nothing related the work to the submitted block. *)
      let%test "work on another block is rejected" =
        match
          check_belongs_to_block
            ~block_staged_ledger_hash:(staged_ledger_hash_of block_ledger_hash)
            ~proof:(proof_targeting other_ledger_hash)
        with
        | Ok () ->
            false
        | Error e ->
            String.is_substring (Error.to_string_hum e)
              ~substring:"does not match the submitted block's staged ledger"
    end )
end
