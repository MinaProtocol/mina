open Utils

module Types = struct
  module type S = sig
    module Fee : S0

    module Amount : S0

    module Balance : S0
  end
end

module type Concrete =
  Types.S
    with type Fee.t = Unsigned.UInt64.t
     and type Amount.t = Unsigned.UInt64.t
     and type Balance.t = Unsigned.UInt64.t

module M = struct
  module Fee = struct
    type t = Unsigned.UInt64.t
  end

  module Amount = struct
    type t = Unsigned.UInt64.t
  end

  module Balance = struct
    type t = Amount.t
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
