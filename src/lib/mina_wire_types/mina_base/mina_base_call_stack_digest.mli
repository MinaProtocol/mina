open Utils

module Types : sig
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

module M : sig
  module V1 : sig
    type t = private Mina_base_zkapp_basic.F.V1.t
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module V1 = M.V1
