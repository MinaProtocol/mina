open Utils

module Types = struct
  module type S = sig
    module Fee : V1S0

    module Amount : V1S0

    module Balance : V1S0
  end
end

module type Concrete =
  Types.S
    with type Fee.V1.t = Unsigned.UInt64.t
     and type Amount.V1.t = Unsigned.UInt64.t
     and type Balance.V1.t = Unsigned.UInt64.t

module M = struct
  module Fee = struct
    module V1 = struct
      type t = Unsigned.UInt64.t
    end
  end

  module Amount = struct
    module V1 = struct
      type t = Unsigned.UInt64.t
    end
  end

  module Balance = struct
    module V1 = struct
      type t = Amount.V1.t
    end
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
