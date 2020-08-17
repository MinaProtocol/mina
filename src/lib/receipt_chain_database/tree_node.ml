open Core
open Coda_base

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { key: Receipt.Chain_hash.Stable.V1.t
      ; value: Command_transaction.Stable.V1.t
      ; parent: Receipt.Chain_hash.Stable.V1.t }
    [@@deriving sexp]

    let to_latest = Fn.id
  end
end]
