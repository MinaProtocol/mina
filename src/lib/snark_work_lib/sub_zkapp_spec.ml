open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('witness, 'proof) t =
        | Segment of
            { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
            ; witness : 'witness
            ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
            }
        | Merge of { proof1 : 'proof; proof2 : 'proof }
      [@@deriving sexp, yojson]
    end
  end]

  [%%define_locally Stable.Latest.(t_of_sexp, sexp_of_t, to_yojson, of_yojson)]

  let map ~f_witness ~f_proof = function
    | Segment { statement; witness; spec } ->
        Segment { statement; witness = f_witness witness; spec }
    | Merge { proof1; proof2 } ->
        Merge { proof1 = f_proof proof1; proof2 = f_proof proof2 }

  let statement : _ t -> Transaction_snark.Statement.t = function
    | Segment { statement; _ } ->
        Mina_state.Snarked_ledger_state.Poly.drop_sok statement
    | Merge { proof1; proof2; _ } -> (
        let stmt1 = Ledger_proof.Poly.statement proof1 in
        let stmt2 = Ledger_proof.Poly.statement proof2 in
        let stmt = Mina_state.Snarked_ledger_state.merge stmt1 stmt2 in
        match stmt with
        | Ok stmt ->
            stmt
        | Error e ->
            failwithf
              "Failed to construct a statement from zkapp merge command %s"
              (Error.to_string_hum e) () )
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      ( Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
      , Ledger_proof.Stable.V2.t )
      Poly.Stable.V1.t
    [@@deriving sexp, yojson]

    let statement : t -> Transaction_snark.Statement.t = Poly.statement

    let to_latest = Fn.id
  end
end]

type t =
  ( Transaction_snark.Zkapp_command_segment.Witness.t
  , Ledger_proof.Cached.t )
  Poly.t

let read_all_proofs_from_disk : t -> Stable.Latest.t =
  Poly.map
    ~f_witness:
      Transaction_snark.Zkapp_command_segment.Witness.read_all_proofs_from_disk
    ~f_proof:Ledger_proof.Cached.read_proof_from_disk

let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
    Stable.Latest.t -> t =
  Poly.map
    ~f_witness:
      (Transaction_snark.Zkapp_command_segment.Witness.write_all_proofs_to_disk
         ~proof_cache_db )
    ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
