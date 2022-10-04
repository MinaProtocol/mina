open Utils

module Types : sig
  module type S = sig
    module Aux_hash : sig
      type t

      module V1 : sig
        type nonrec t = t
      end
    end

    module Pending_coinbase_aux : V1S0
  end
end

module type Concrete = sig
  module Aux_hash : sig
    type t = string

    module V1 : sig
      type nonrec t = t
    end
  end

  module Pending_coinbase_aux : sig
    module V1 : sig
      type t = string
    end
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include
  Types.S
    with module Aux_hash = M.Aux_hash
     and module Pending_coinbase_aux = M.Pending_coinbase_aux
