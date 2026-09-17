open Core

(* Merging two ledger proofs' statements. Shared by every version, since the
   [Merge] arm has never differed between them. *)
let merge_statement_exn proof1 proof2 =
  let stmt1 = Ledger_proof.statement proof1 in
  let stmt2 = Ledger_proof.statement proof2 in
  match Mina_state.Snarked_ledger_state.merge stmt1 stmt2 with
  | Ok stmt ->
      stmt
  | Error e ->
      failwithf "Failed to construct a statement from zkapp merge command %s"
        (Error.to_string_hum e) ()

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V3 = struct
    type t =
      | Segment of
          { statement : Transaction_snark.Statement.Stable.V2.t
          ; witness :
              Transaction_snark.Zkapp_command_segment.Witness.Stable.V2.t
          ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
          }
      | Merge of
          { proof1 : Ledger_proof.Stable.V3.t
          ; proof2 : Ledger_proof.Stable.V3.t
          }
    [@@deriving sexp, yojson]

    let statement : t -> Transaction_snark.Statement.t = function
      | Segment { statement; _ } ->
          statement
      | Merge { proof1; proof2; _ } ->
          merge_statement_exn proof1 proof2

    let to_latest = Fn.id
  end

  module V2 = struct
    type t =
      | Segment of
          { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
          ; witness :
              Transaction_snark.Zkapp_command_segment.Witness.Stable.V2.t
          ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
          }
      | Merge of
          { proof1 : Ledger_proof.Stable.V3.t
          ; proof2 : Ledger_proof.Stable.V3.t
          }
    [@@deriving sexp, yojson]

    let statement : t -> Transaction_snark.Statement.t = function
      | Segment { statement; _ } ->
          Mina_state.Snarked_ledger_state.Poly.drop_sok statement
      | Merge { proof1; proof2; _ } ->
          merge_statement_exn proof1 proof2

    (** Upgrade. The embedded digest is discarded, not read: it is known to be a
        placeholder, and the authoritative sok message rides on
        [With_job_meta.sok_message] alongside. *)
    let to_latest : t -> V3.t = function
      | Segment { statement; witness; spec } ->
          V3.Segment
            { statement =
                Mina_state.Snarked_ledger_state.Poly.drop_sok statement
            ; witness
            ; spec
            }
      | Merge { proof1; proof2 } ->
          V3.Merge { proof1; proof2 }

    (** Downgrade, for serving a worker that predates V3. [sok_digest] comes
        from the enclosing job's sok message, so the field an old worker
        receives is the real digest rather than the zeros it used to get. It
        re-derives from [sok_message] on arrival regardless, so it never reads
        this value. *)
    let of_v3 ~sok_digest : V3.t -> t = function
      | V3.Segment { statement; witness; spec } ->
          Segment
            { statement =
                Mina_state.Snarked_ledger_state.Poly.
                  { statement with sok_digest }
            ; witness
            ; spec
            }
      | V3.Merge { proof1; proof2 } ->
          Merge { proof1; proof2 }
  end
end]

type t =
  | Segment of
      { statement : Transaction_snark.Statement.t
      ; witness : Transaction_snark.Zkapp_command_segment.Witness.t
      ; spec : Transaction_snark.Zkapp_command_segment.Basic.t
      }
  | Merge of { proof1 : Ledger_proof.Cached.t; proof2 : Ledger_proof.Cached.t }
