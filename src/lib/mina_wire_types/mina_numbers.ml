open Utils

module Account_nonce = struct
  module Types = struct
    module type S = V1S0
  end

  module type Concrete = Types.S with type V1.t = Unsigned.UInt32.t

  module M = struct
    module V1 = struct
      type t = Unsigned.UInt32.t
    end
  end

  module type Local_sig = Signature(Types).S

  module Make
      (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
    F (M)
  include M
end

module Global_slot = struct
  module Types = struct
    module type S = V1S0
  end

  module type Concrete = Types.S with type V1.t = Unsigned.UInt32.t

  module M = struct
    module V1 = struct
      type t = Unsigned.UInt32.t
    end
  end

  module type Local_sig = Signature(Types).S

  module Make
      (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
    F (M)
  include M
end
