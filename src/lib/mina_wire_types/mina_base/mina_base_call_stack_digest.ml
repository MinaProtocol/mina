open Utils

module Types = struct
  module type S = sig
    module V1 : sig
      type t = private Mina_base_zkapp_basic.F.V1.t
    end
  end
end

module type Concrete = sig
  module V1 : sig
    type t = Pasta_bindings.Fp.t
  end
end

module M = struct
  module V1 = struct
    type t = Pasta_bindings.Fp.t
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
