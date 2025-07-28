open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      | Segment of
          { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
          ; witness :
              Transaction_snark.Zkapp_command_segment.Witness.Stable.V2.t
          ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
          }
      | Merge of
          { proof1 : Ledger_proof.Stable.V2.t
          ; proof2 : Ledger_proof.Stable.V2.t
          }
    [@@deriving sexp, yojson]

    let statement : t -> Transaction_snark.Statement.t = function
      | Segment { statement; _ } ->
          Mina_state.Snarked_ledger_state.Poly.drop_sok statement
      | Merge { proof1; proof2; _ } -> (
          let stmt1 = Ledger_proof.statement proof1 in
          let stmt2 = Ledger_proof.statement proof2 in
          let stmt = Mina_state.Snarked_ledger_state.merge stmt1 stmt2 in
          match stmt with
          | Ok stmt ->
              stmt
          | Error e ->
              failwithf
                "Failed to construct a statement from zkapp merge command %s"
                (Error.to_string_hum e) () )

    let to_latest = Fn.id
  end
end]

type t =
  | Segment of
      { statement : Transaction_snark.Statement.With_sok.t
      ; witness : Transaction_snark.Zkapp_command_segment.Witness.t
      ; spec : Transaction_snark.Zkapp_command_segment.Basic.t
      }
  | Merge of { proof1 : Ledger_proof.Cached.t; proof2 : Ledger_proof.Cached.t }

let read_all_proofs_from_disk : t -> Stable.Latest.t = function
  | Segment { statement; witness; spec } ->
      Segment
        { statement
        ; witness =
            Transaction_snark.Zkapp_command_segment.Witness
            .read_all_proofs_from_disk witness
        ; spec
        }
  | Merge { proof1; proof2 } ->
      Merge
        { proof1 = Ledger_proof.Cached.read_proof_from_disk proof1
        ; proof2 = Ledger_proof.Cached.read_proof_from_disk proof2
        }

let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
    Stable.Latest.t -> t = function
  | Segment { statement; witness; spec } ->
      Segment
        { statement
        ; witness =
            Transaction_snark.Zkapp_command_segment.Witness
            .write_all_proofs_to_disk ~proof_cache_db witness
        ; spec
        }
  | Merge { proof1; proof2 } ->
      Merge
        { proof1 =
            Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof1
        ; proof2 =
            Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db proof2
        }
