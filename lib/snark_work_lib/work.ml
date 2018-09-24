open Core_kernel

module Single = struct
  module Spec = struct
    type ('statement, 'transition, 'sparse_ledger, 'ledger_proof) t =
      | Transition of 'statement * 'transition * 'sparse_ledger
      | Merge of 'statement * 'ledger_proof * 'ledger_proof
    [@@deriving bin_io]

    let statement = function Transition (s, _, _) -> s | Merge (s, _, _) -> s
  end
end

module Spec = struct
  type 'single t = {instances: 'single list; fee: Currency.Fee.Stable.V1.t}
  [@@deriving bin_io, fields]
end

module Result = struct
  type ('spec, 'single) t =
    { proofs: 'single list
    ; metrics: (Time.Span.t * [`Transition | `Merge]) list
    ; spec: 'spec
    ; prover: Signature_lib.Public_key.Compressed.t }
  [@@deriving bin_io, fields]
end

let proofs_per_work = 2
