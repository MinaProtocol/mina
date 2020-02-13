open Core_kernel
open Async_kernel
open Module_version
open Coda_base

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        | Add_solved_work of
            Transaction_snark_work.Statement.Stable.V1.t
            * Ledger_proof.Stable.V1.t One_or_two.Stable.V1.t
              Priced_proof.Stable.V1.t
      [@@deriving bin_io, compare, sexp, to_yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "snark_pool_diff"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io omitted *)
type t = Stable.Latest.t =
  | Add_solved_work of
      Transaction_snark_work.Statement.Stable.V1.t
      * Ledger_proof.Stable.V1.t One_or_two.t Priced_proof.Stable.V1.t
[@@deriving compare, sexp, to_yojson]

let compact_json = function
  | Add_solved_work (work, {proof= _; fee= {fee; prover}}) ->
      `Assoc
        [ ("work_ids", Transaction_snark_work.Statement.compact_json work)
        ; ("fee", Currency.Fee.to_yojson fee)
        ; ("prover", Signature_lib.Public_key.Compressed.to_yojson prover) ]

let summary = function
  | Stable.V1.Add_solved_work (work, {proof= _; fee}) ->
      Printf.sprintf
        !"Snark_pool_diff for work %s added with fee-prover %s"
        ( Yojson.Safe.to_string
        @@ Transaction_snark_work.Statement.compact_json work )
        (Yojson.Safe.to_string @@ Coda_base.Fee_with_prover.to_yojson fee)

(*
let verify_and_act t ~work ~sender =
  let statements, priced_proof = work in
  let open Deferred.Or_error.Let_syntax in
  let {Priced_proof.proof= proofs; fee= {prover; fee}} = priced_proof in
  let trust_record =
    Trust_system.record_envelope_sender t.config.trust_system t.logger
      sender
  in
  let log_and_punish ?(punish = true) statement e =
    let metadata =
      [ ("work_id", `Int (Transaction_snark.Statement.hash statement))
      ; ("prover", Signature_lib.Public_key.Compressed.to_yojson prover)
      ; ("fee", Currency.Fee.to_yojson fee)
      ; ("error", `String (Error.to_string_hum e)) ]
    in
    Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__ ~metadata
      "Error verifying transaction snark: $error" ;
    if punish then
      trust_record
        ( Trust_system.Actions.Sent_invalid_proof
        , Some ("Error verifying transaction snark: $error", metadata) )
    else Deferred.return ()
  in
  let message = Coda_base.Sok_message.create ~fee ~prover in
  let verify ~proof ~statement =
    let open Deferred.Let_syntax in
    let statement_eq a b =
      Int.(Transaction_snark.Statement.compare a b = 0)
    in
    if not (statement_eq (Ledger_proof.statement proof) statement) then
      let e = Error.of_string "Statement and proof do not match" in
      let%map () = log_and_punish statement e in
      Error e
    else
      match%bind
        Verifier.verify_transaction_snark t.config.verifier proof
          ~message
      with
      | Ok true ->
          Deferred.Or_error.return ()
      | Ok false ->
          (*Invalid proof*)
          let e = Error.of_string "Invalid proof" in
          let%map () = log_and_punish statement e in
          Error e
      | Error e ->
          (* Verifier crashed or other errors at our end. Don't punish the peer*)
          let%map () = log_and_punish ~punish:false statement e in
          Error e
  in
  let%bind pairs = One_or_two.zip statements proofs |> Deferred.return in
  One_or_two.Deferred_result.fold ~init:() pairs
    ~f:(fun _ (statement, proof) ->
      let start = Time.now () in
      let res = verify ~proof ~statement in
      let time_ms =
        Time.abs_diff (Time.now ()) start |> Time.Span.to_ms
      in
      Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          [ ("work_id", `Int (Transaction_snark.Statement.hash statement))
          ; ("time", `Float time_ms) ]
        "Verification of work $work_id took $time ms" ;
      res )
*)

let time_deferred d =
  let start = Time.now () in
  let%map x = d in
  let time_elapsed = Time.(abs_diff (now ()) start |> Span.to_ms) in
  (time_elapsed, x)

(* TODO: include statement checking logic here, or (preferrably) genealize
 * and expose verification logic from staged_ledger.ml (check_completed_works)
 *)
let validate_diffs diffs =
  let snarks, snark_diff_indices =
    List.unzip @@ List.concat
    @@ List.mapi diffs ~f:(fun index diff ->
           let (Add_solved_work (_, bundle)) = diff in
           let proofs = One_or_two.to_list (Priced_proof.proof bundle) in
           let message =
             Sok_message.create ~fee:bundle.fee.fee ~prover:bundle.fee.prover
           in
           List.map proofs ~f:(fun proof -> ((proof, message), index)) )
  in
  let%bind verification_time, verification_results =
    time_deferred @@ Verifier.verify_transaction_snarks verifier snarks
  in
  Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
    ~metadata:[("time", `Float verification_time)]
    "Batch verifying %d proofs in %d snark pool diffs took $time ms"
    (List.length snarks) (List.length diffs) ;
  let invalid_diff_indices =
    List.filter_map (List.zip_exn verification_results snark_diff_indices)
      ~f:(fun snark_is_valid diff_index ->
        Option.some_if (not snark_is_valid) diff_index )
    |> Int.Set.of_list
  in
  let invalid_diffs, valid_diffs =
    List.partition_map (List.mapi diffs ~f:Tuple2.cons)
      ~f:(fun (diff, index) ->
        if Int.Set.mem invalid_indices index then `Fst diff else `Snd diff )
  in
  ( `Invalid_diffs (invalid_diffs :> Diff.t Envelope.Incoming.t invalid list)
  , `Valid_diffs (valid_diffs :> Diff.t Envelope.Incoming.t valid list) )
