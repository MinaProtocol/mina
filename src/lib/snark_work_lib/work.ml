open Core_kernel

module Single = struct
  module Spec = struct
    type ('statement, 'transition, 'witness, 'ledger_proof) t =
      | Transition of 'statement * 'transition * 'witness sexp_opaque
      | Merge of
          'statement * 'ledger_proof sexp_opaque * 'ledger_proof sexp_opaque
    [@@deriving bin_io, sexp]

    let statement = function Transition (s, _, _) -> s | Merge (s, _, _) -> s
  end
end

module Spec = struct
  type 'single t = {instances: 'single list; fee: Currency.Fee.Stable.V1.t}
  [@@deriving bin_io, fields, sexp]
end

module Result = struct
  (* TODO : version *)
  type ('spec, 'single) t =
    { proofs: 'single list
    ; metrics: (Time.Span.t * [`Transition | `Merge]) list
    ; spec: 'spec
    ; prover: Signature_lib.Public_key.Compressed.Stable.V1.t }
  [@@deriving bin_io, fields]
end

let proofs_per_work = 2
