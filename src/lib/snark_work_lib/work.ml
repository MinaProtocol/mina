(* TODO: remove type generalizations #2594 *)

open Core_kernel

module Single = struct
  module Spec = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type ('statement, 'transition, 'witness, 'ledger_proof) t =
            | Transition of 'statement * 'transition * 'witness
            | Merge of 'statement * 'ledger_proof * 'ledger_proof
          [@@deriving bin_io, sexp, version]
        end

        include T
      end

      module Latest = V1
    end

    type ('statement, 'transition, 'witness, 'ledger_proof) t =
          ('statement, 'transition, 'witness, 'ledger_proof) Stable.Latest.t =
      | Transition of 'statement * 'transition * 'witness
      | Merge of
          'statement * 'ledger_proof sexp_opaque * 'ledger_proof sexp_opaque
    [@@deriving sexp]

    let statement = function Transition (s, _, _) -> s | Merge (s, _, _) -> s
  end
end

module Spec = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type 'single t =
          {instances: 'single list; fee: Currency.Fee.Stable.V1.t}
        [@@deriving bin_io, fields, sexp, version]
      end

      include T
    end

    module Latest = V1
  end

  type 'single t = 'single Stable.Latest.t =
    {instances: 'single list; fee: Currency.Fee.t}
  [@@deriving fields, sexp]
end

module Result = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('spec, 'single) t =
          { proofs: 'single list
          ; metrics: (Core.Time.Stable.Span.V1.t * [`Transition | `Merge]) list
          ; spec: 'spec
          ; prover: Signature_lib.Public_key.Compressed.Stable.V1.t }
        [@@deriving bin_io, fields, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('spec, 'single) t = ('spec, 'single) Stable.Latest.t =
    { proofs: 'single list
    ; metrics: (Time.Span.t * [`Transition | `Merge]) list
    ; spec: 'spec
    ; prover: Signature_lib.Public_key.Compressed.t }
  [@@deriving fields]
end

let proofs_per_work = 2
