open Core

module Block_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Coda_state.Protocol_state.Body.Value.Stable.V1.t
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp]

  type var = Coda_state.Protocol_state.Body.var

  let typ = Coda_state.Protocol_state.Body.typ
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = {transaction: 'a; block_data: Block_data.Stable.V1.t}
      [@@deriving sexp]
    end
  end]

  type 'a t = 'a Stable.Latest.t = {transaction: 'a; block_data: Block_data.t}
  [@@deriving sexp]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = 'a Poly.Stable.V1.t [@@deriving sexp]
  end
end]

type 'a t = 'a Stable.Latest.t [@@deriving sexp]

let transaction t = t.Poly.transaction

let block_data t = t.Poly.block_data
