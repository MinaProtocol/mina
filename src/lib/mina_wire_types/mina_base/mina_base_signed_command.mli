open Utils

module Poly : sig
  module V1 : sig
    type ('payload, 'pk, 'signature) t =
      { payload : 'payload; signer : 'pk; signature : 'signature }
  end
end

module V1 : sig
  type t =
    ( Mina_base_signed_command_payload.V1.t
    , Public_key.V1.t
    , Mina_base_signature.V1.t )
    Poly.V1.t
end

module V2 : sig
  type t =
    ( Mina_base_signed_command_payload.V2.t
    , Public_key.V1.t
    , Mina_base_signature.V1.t )
    Poly.V1.t
end

module Types : sig
  module type S = sig
    module With_valid_signature : V2S0 with type V2.t = private V2.t
  end
end

module type Concrete = Types.S with type With_valid_signature.V2.t = V2.t

module M : sig
  module With_valid_signature : sig
    module V2 : sig
      type t = private V2.t
    end
  end
end

module type Local_sig = Utils.Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module With_valid_signature = M.With_valid_signature
