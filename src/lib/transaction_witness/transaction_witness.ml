open Core_kernel

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      { ledger : Mina_base.Sparse_ledger.Stable.V2.t
      ; protocol_state_body : Mina_state.Protocol_state.Body.Value.Stable.V1.t
      ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
      ; status : Mina_base.Transaction_status.Stable.V1.t
      }
    [@@deriving sexp, to_yojson]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t =
      { ledger : Mina_base.Sparse_ledger.Stable.V1.t
      ; protocol_state_body : Mina_state.Protocol_state.Body.Value.Stable.V1.t
      ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
      ; status : Mina_base.Transaction_status.Stable.V1.t
      }
    [@@deriving sexp, to_yojson]

    let to_latest ({ ledger; protocol_state_body; init_stack; status } : t) :
        Latest.t =
      { ledger = Mina_base.Sparse_ledger.Stable.V1.to_latest ledger
      ; protocol_state_body
      ; init_stack
      ; status
      }
  end
end]
