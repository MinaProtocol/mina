open Utils

module Types = struct
  module type S = sig
    module V1 : sig
      type t = private
        { receiver : Public_key.Compressed.V1.t
        ; amount : Currency.Amount.V1.t
        ; fee_transfer : Mina_base_coinbase_fee_transfer.V1.t option
        }
    end
  end
end

module M = struct
  module V1 = struct
    type t =
      { receiver : Public_key.Compressed.V1.t
      ; amount : Currency.Amount.V1.t
      ; fee_transfer : Mina_base_coinbase_fee_transfer.V1.t option
      }
  end
end

module type Concrete = sig
  module V1 : sig
    type t =
      { receiver : Public_key.Compressed.V1.t
      ; amount : Currency.Amount.V1.t
      ; fee_transfer : Mina_base_coinbase_fee_transfer.V1.t option
      }
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
