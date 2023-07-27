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

module Global_slot_legacy = struct
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

module Global_slot_since_genesis = struct
  module Types = struct
    module type S = V1S0
  end

  type global_slot = Since_genesis of Unsigned.UInt32.t [@@unboxed]

  module type Concrete = Types.S with type V1.t = global_slot

  module M = struct
    module V1 = struct
      type t = global_slot
    end
  end

  module type Local_sig = Signature(Types).S

  module Make
      (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
    F (M)
  include M
end

module Global_slot_since_hard_fork = struct
  module Types = struct
    module type S = V1S0
  end

  type global_slot = Since_hard_fork of Unsigned.UInt32.t [@@unboxed]

  module type Concrete = Types.S with type V1.t = global_slot

  module M = struct
    module V1 = struct
      type t = global_slot
    end
  end

  module type Local_sig = Signature(Types).S

  module Make
      (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
    F (M)
  include M
end

module Global_slot_span = struct
  module Types = struct
    module type S = V1S0
  end

  type global_slot_span = Global_slot_span of Unsigned.UInt32.t [@@unboxed]

  module type Concrete = Types.S with type V1.t = global_slot_span

  module M = struct
    module V1 = struct
      type t = global_slot_span
    end
  end

  module type Local_sig = Signature(Types).S

  module Make
      (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
    F (M)
  include M
end

module Length = struct
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

module Index = struct
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
