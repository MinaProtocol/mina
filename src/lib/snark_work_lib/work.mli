open Core_kernel

module Single : sig
  module Spec : sig
    type ('statement, 'transition, 'witness, 'ledger_proof) t =
      | Transition of 'statement * 'transition * 'witness
      | Merge of 'statement * 'ledger_proof * 'ledger_proof
    [@@deriving bin_io, sexp]

    val statement :
      ('statement, 'transition, 'witness, 'ledger_proof) t -> 'statement
  end
end

val proofs_per_work : int

module Spec : sig
  type 'single t = {instances: 'single list; fee: Currency.Fee.Stable.V1.t}
  [@@deriving bin_io, fields, sexp]
end

module Result : sig
  type ('spec, 'single) t =
    { proofs: 'single list
    ; metrics: (Time.Span.t * [`Transition | `Merge]) list
    ; spec: 'spec
    ; prover: Signature_lib.Public_key.Compressed.t }
  [@@deriving bin_io, fields]
end
