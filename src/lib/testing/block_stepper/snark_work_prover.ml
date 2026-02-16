open Core
open Async
open Mina_base

type prove_base_input =
  { statement : Mina_state.Snarked_ledger_state.With_sok.t
  ; witness : Transaction_witness.Stable.V2.t
  }

type prove_zkapp_segment_input =
  { statement : Mina_state.Snarked_ledger_state.With_sok.t
  ; witness : Transaction_snark.Zkapp_command_segment.Witness.t
  ; spec : Transaction_snark.Zkapp_command_segment.Basic.t
  }

type prove_merge_input =
  { proof1 : Ledger_proof.t
  ; proof2 : Ledger_proof.t
  ; sok_digest : Sok_message.Digest.t
  }

type t =
  { prove_base : prove_base_input -> Ledger_proof.t Deferred.Or_error.t
  ; prove_zkapp_segment :
      prove_zkapp_segment_input -> Ledger_proof.t Deferred.Or_error.t
  ; prove_merge : prove_merge_input -> Ledger_proof.t Deferred.Or_error.t
  ; how : Monad_sequence.how
  }

let prove_base t input = t.prove_base input

let prove_zkapp_segment t input = t.prove_zkapp_segment input

let prove_merge t input = t.prove_merge input

let how t = t.how

let make ~signature_kind (module T : Transaction_snark.S) =
  let prove_non_zkapp ~statement (w : Transaction_witness.Stable.V2.t)
      valid_transaction =
    Deferred.Or_error.try_with ~here:[%here] (fun () ->
        T.of_non_zkapp_command_transaction ~statement
          { Transaction_protocol_state.Poly.transaction = valid_transaction
          ; block_data = w.protocol_state_body
          ; global_slot = w.block_global_slot
          }
          ~init_stack:w.init_stack
          (unstage (Mina_ledger.Sparse_ledger.handler w.first_pass_ledger)) )
  in
  { prove_base =
      (fun { statement; witness } ->
        match witness.transaction with
        | Command (Signed_command cmd) ->
            let open Deferred.Or_error.Let_syntax in
            (* TODO: This check is included because the daemon's
               [snark_worker/prod.ml] also includes it. However, it seems
               completely redundant, given that our input is already a validated
               command. *)
            let%bind cmd =
              Deferred.return
              @@ Result.of_option
                   (Signed_command.check ~signature_kind cmd)
                   ~error:(Error.of_string "Command has an invalid signature")
            in
            prove_non_zkapp ~statement witness (Command (Signed_command cmd))
        | Fee_transfer ft ->
            prove_non_zkapp ~statement witness (Fee_transfer ft)
        | Coinbase cb ->
            prove_non_zkapp ~statement witness (Coinbase cb)
        | Command (Zkapp_command _) ->
            Deferred.Or_error.error_string
              "Zkapp_command should not reach prove_base" )
  ; prove_zkapp_segment =
      (fun { statement; witness; spec } ->
        Deferred.Or_error.try_with ~here:[%here] (fun () ->
            T.of_zkapp_command_segment_exn ~statement ~witness ~spec ) )
  ; prove_merge =
      (fun { proof1; proof2; sok_digest } -> T.merge proof1 proof2 ~sok_digest)
  ; how = `Sequential
  }
