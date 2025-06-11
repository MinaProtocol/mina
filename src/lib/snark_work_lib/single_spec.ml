open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('witness, 'ledger_proof) t =
        | Transition of Transaction_snark.Statement.Stable.V2.t * 'witness
        | Merge of
            Transaction_snark.Statement.Stable.V2.t
            * 'ledger_proof
            * 'ledger_proof
      [@@deriving sexp, yojson]
    end
  end]

  let map ~f_witness ~f_proof = function
    | Transition (s, w) ->
        Transition (s, f_witness w)
    | Merge (s, p1, p2) ->
        Merge (s, f_proof p1, f_proof p2)

  let witness (t : (_, _) t) =
    match t with Transition (_, witness) -> Some witness | Merge _ -> None

  let statement = function Transition (s, _) -> s | Merge (s, _, _) -> s

  let gen :
         'witness Quickcheck.Generator.t
      -> 'ledger_proof Quickcheck.Generator.t
      -> ('witness, 'ledger_proof) t Quickcheck.Generator.t =
   fun gen_witness gen_proof ->
    let open Quickcheck.Generator in
    let gen_transition =
      let open Let_syntax in
      let%bind statement = Transaction_snark.Statement.gen in
      let%map witness = gen_witness in
      Transition (statement, witness)
    in
    let gen_merge =
      let open Let_syntax in
      let%bind statement = Transaction_snark.Statement.gen in
      let%map p1, p2 = tuple2 gen_proof gen_proof in
      Merge (statement, p1, p2)
    in
    union [ gen_transition; gen_merge ]
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      ( Transaction_witness.Stable.V3.t
      , Ledger_proof.Stable.V2.t )
      Poly.Stable.V2.t
    [@@deriving sexp, yojson]

    let to_latest = Fn.id

    let transaction t =
      Option.map (Poly.witness t) ~f:(fun w ->
          w.Transaction_witness.Stable.Latest.transaction )
  end
end]

type t = (Transaction_witness.t, Ledger_proof.Cached.t) Poly.t

let read_all_proofs_from_disk : t -> Stable.Latest.t =
  Poly.map ~f_witness:Transaction_witness.read_all_proofs_from_disk
    ~f_proof:Ledger_proof.Cached.read_proof_from_disk

let write_all_proofs_to_disk ~(proof_cache_db : Proof_cache_tag.cache_db) :
    Stable.Latest.t -> t =
  Poly.map
    ~f_witness:(Transaction_witness.write_all_proofs_to_disk ~proof_cache_db)
    ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
