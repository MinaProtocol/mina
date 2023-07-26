open Utils

module Types = struct
  module type S = sig
    module V1 : sig
      type t = private
        { receiver_pk : Public_key.Compressed.V1.t; fee : Currency.Fee.V1.t }
    end
  end
end

module type Concrete = sig
  module V1 : sig
    type t =
      { receiver_pk : Public_key.Compressed.V1.t; fee : Currency.Fee.V1.t }
  end
end

module M = struct
  module V1 = struct
    type t =
      { receiver_pk : Public_key.Compressed.V1.t; fee : Currency.Fee.V1.t }
  end
end

module type Local_sig = Utils.Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
