(* TODO: remove type generalizations #2594 *)

open Core_kernel

module Single = struct
  module Spec = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type ('transition, 'witness, 'ledger_proof) t =
            | Transition of
                Transaction_snark.Statement.Stable.V1.t
                * 'transition
                * 'witness
            | Merge of
                Transaction_snark.Statement.Stable.V1.t
                * 'ledger_proof
                * 'ledger_proof
          [@@deriving bin_io, sexp, version]
        end

        include T
      end

      module Latest = V1
    end

    type ('transition, 'witness, 'ledger_proof) t =
          ('transition, 'witness, 'ledger_proof) Stable.Latest.t =
      | Transition of Transaction_snark.Statement.t * 'transition * 'witness
      | Merge of
          Transaction_snark.Statement.t
          * 'ledger_proof sexp_opaque
          * 'ledger_proof sexp_opaque
    [@@deriving sexp]

    let statement = function Transition (s, _, _) -> s | Merge (s, _, _) -> s

    let gen :
           'transition Quickcheck.Generator.t
        -> 'witness Quickcheck.Generator.t
        -> 'ledger_proof Quickcheck.Generator.t
        -> ('transition, 'witness, 'ledger_proof) t Quickcheck.Generator.t =
     fun gen_trans gen_witness gen_proof ->
      let open Quickcheck.Generator in
      let gen_transition =
        let open Let_syntax in
        let%bind statement = Transaction_snark.Statement.gen in
        let%map transition, witness = tuple2 gen_trans gen_witness in
        Transition (statement, transition, witness)
      in
      let gen_merge =
        let open Let_syntax in
        let%bind statement = Transaction_snark.Statement.gen in
        let%map p1, p2 = tuple2 gen_proof gen_proof in
        Merge (statement, p1, p2)
      in
      union [gen_transition; gen_merge]
  end
end

module Spec = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type 'single t =
          { instances: 'single One_or_two.Stable.V1.t
          ; fee: Currency.Fee.Stable.V1.t }
        [@@deriving bin_io, fields, sexp, version]
      end

      include T
    end

    module Latest = V1
  end

  type 'single t = 'single Stable.Latest.t =
    {instances: 'single One_or_two.t; fee: Currency.Fee.t}
  [@@deriving fields, sexp]
end

module Result = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('spec, 'single) t =
          { proofs: 'single One_or_two.Stable.V1.t
          ; metrics:
              (Core.Time.Stable.Span.V1.t * [`Transition | `Merge])
              One_or_two.Stable.V1.t
          ; spec: 'spec
          ; prover: Signature_lib.Public_key.Compressed.Stable.V1.t }
        [@@deriving bin_io, fields, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('spec, 'single) t = ('spec, 'single) Stable.Latest.t =
    { proofs: 'single One_or_two.t
    ; metrics: (Time.Span.t * [`Transition | `Merge]) One_or_two.t
    ; spec: 'spec
    ; prover: Signature_lib.Public_key.Compressed.t }
  [@@deriving fields]
end
