module Block_data = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Mina_state.Protocol_state.Body.Value.Stable.V2.t
      [@@deriving sexp]

      let to_latest = Core_kernel.Fn.id
    end
  end]

  type var = Mina_state.Protocol_state.Body.var

  let typ = Mina_state.Protocol_state.Body.typ
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'a t =
        { transaction : 'a
        ; block_data : Block_data.Stable.V2.t
        ; global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        }
      [@@deriving sexp]
    end
  end]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type 'a t = 'a Poly.Stable.V2.t [@@deriving sexp]
  end
end]

let transaction t = t.Poly.transaction

let block_data t = t.Poly.block_data

let global_slot t = t.Poly.global_slot
