open Core_kernel

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      { ledger: Coda_base.Sparse_ledger.Stable.V1.t
      ; protocol_state_body: Coda_state.Protocol_state.Body.Value.Stable.V1.t
      ; init_stack: Coda_base.Pending_coinbase.Stack_versioned.Stable.V1.t }
    [@@deriving sexp, to_yojson]
  end
end]

type t = Stable.Latest.t =
  { ledger: Coda_base.Sparse_ledger.t
  ; protocol_state_body: Coda_state.Protocol_state.Body.Value.t
  ; init_stack: Coda_base.Pending_coinbase.Stack_versioned.t }
[@@deriving sexp, to_yojson]
