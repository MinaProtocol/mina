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

  type var = Coda_state.Protocol_state.Body.var

  let typ = Coda_state.Protocol_state.Body.typ
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = {transaction: 'a; block_data: Block_data.Stable.V1.t}
      [@@deriving sexp]

      let to_latest a_latest {transaction; block_data} =
        {transaction= a_latest transaction; block_data}

      let of_latest a_latest {transaction; block_data} =
        let open Result.Let_syntax in
        let%map transaction = a_latest transaction in
        {transaction; block_data}
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = 'a Poly.Stable.V1.t [@@deriving sexp]

    let to_latest = Poly.Stable.V1.to_latest

    let of_latest = Poly.Stable.V1.of_latest
  end
end]

let transaction t = t.Poly.transaction

let block_data t = t.Poly.block_data
