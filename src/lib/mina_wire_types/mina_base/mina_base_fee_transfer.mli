open Utils

module Types : sig
  module type S = sig
    module Single : sig
      module V2 : sig
        type t = private
          { receiver_pk : Public_key.Compressed.V1.t
          ; fee : Currency.Fee.V1.t
          ; fee_token : Mina_base_token_id.V1.t
          }
      end
    end
  end
end

module M : sig
  module Single : sig
    module V2 : sig
      type t = private
        { receiver_pk : Public_key.Compressed.V1.t
        ; fee : Currency.Fee.V1.t
        ; fee_token : Mina_base_token_id.V1.t
        }
    end
  end
end

module type Concrete = sig
  module Single : sig
    module V2 : sig
      type t =
        { receiver_pk : Public_key.Compressed.V1.t
        ; fee : Currency.Fee.V1.t
        ; fee_token : Mina_base_token_id.V1.t
        }
    end
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module Single = M.Single
