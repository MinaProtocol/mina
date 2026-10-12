module Block_data = struct
  [%%versioned
  module Stable = struct
    module V4 = struct
      type t = Mina_state.Protocol_state.Body.Value.Stable.V4.t
      [@@deriving sexp]

      let to_latest = Core_kernel.Fn.id
    end

    module V3 = struct
      type t = Mina_state.Protocol_state.Body.Value.Stable.V3.t
      [@@deriving sexp]

      let to_latest = Mina_state.Protocol_state.Body.Value.Stable.V3.to_latest
    end
  end]

  type var = Mina_state.Protocol_state.Body.var

  let typ = Mina_state.Protocol_state.Body.typ
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V4 = struct
      type 'a t =
        { transaction : 'a
        ; block_data : Block_data.Stable.V4.t
        ; global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        }
      [@@deriving sexp]
    end

    module V3 = struct
      type 'a t =
        { transaction : 'a
        ; block_data : Block_data.Stable.V3.t
        ; global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        }
      [@@deriving sexp]

      let to_latest a_latest ({ transaction; block_data; global_slot } : _ t) :
          _ Latest.t =
        { transaction = a_latest transaction
        ; block_data = Block_data.Stable.V3.to_latest block_data
        ; global_slot
        }
    end
  end]
end

[%%versioned
module Stable = struct
  module V4 = struct
    type 'a t = 'a Poly.Stable.V4.t [@@deriving sexp]
  end

  module V3 = struct
    type 'a t = 'a Poly.Stable.V3.t [@@deriving sexp]

    let to_latest = Poly.Stable.V3.to_latest
  end
end]

let transaction t = t.Poly.transaction

let block_data t = t.Poly.block_data

let global_slot t = t.Poly.global_slot
