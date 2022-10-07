open Utils

module Types : sig
  module type S = sig
    module At_most_two : sig
      module V1 : sig
        type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
      end
    end
  end
end

module type Concrete = sig
  module Ft : sig
    module Stable : sig
      module V1 : sig
        type t = Mina_base_coinbase_fee_transfer.V1.t
      end
    end
  end

  module At_most_two : sig
    module V1 : sig
      type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
    end
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module At_most_two = M.At_most_two
