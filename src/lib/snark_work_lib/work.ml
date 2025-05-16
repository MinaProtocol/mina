(*
  The better name for this file should really be poly.ml, because the types here
  are polymorphic, and we really need the concretized version in selector.ml
 *)
open Core_kernel

module Single = struct
  module Spec = struct
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

    type ('witness, 'ledger_proof) t =
          ('witness, 'ledger_proof) Stable.Latest.t =
      | Transition of Transaction_snark.Statement.t * 'witness
      | Merge of Transaction_snark.Statement.t * 'ledger_proof * 'ledger_proof
    [@@deriving sexp, yojson]

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
end

module Spec = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'single t =
        { instances : 'single One_or_two.Stable.V1.t
        ; fee : Currency.Fee.Stable.V1.t
        }
      [@@deriving fields, sexp, yojson]

      let to_latest single_latest { instances; fee } =
        { instances = One_or_two.Stable.V1.to_latest single_latest instances
        ; fee
        }

      let of_latest single_latest { instances; fee } =
        let open Result.Let_syntax in
        let%map instances =
          One_or_two.Stable.V1.of_latest single_latest instances
        in
        { instances; fee }
    end
  end]

  type 'single t = 'single Stable.Latest.t =
    { instances : 'single One_or_two.t; fee : Currency.Fee.t }
  [@@deriving fields, sexp, yojson]

  let map ~f { instances; fee } =
    { instances = One_or_two.map ~f instances; fee }

  let map_opt ~f_single { instances; fee } =
    let%map.Option instances = One_or_two.Option.map ~f:f_single instances in
    { instances; fee }
end

module Result = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('spec, 'single) t =
        { proofs : 'single One_or_two.Stable.V1.t
        ; metrics :
            (Core.Time.Stable.Span.V1.t * [ `Transition | `Merge ])
            One_or_two.Stable.V1.t
        ; spec : 'spec
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }
      [@@deriving fields]
    end
  end]

  let map ~f_spec ~f_single { proofs; metrics; spec; prover } =
    { proofs = One_or_two.map ~f:f_single proofs
    ; metrics
    ; spec = f_spec spec
    ; prover
    }
end
