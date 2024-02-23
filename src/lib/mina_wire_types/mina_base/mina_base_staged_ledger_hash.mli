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

    module V1 : sig
      type t
    end
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

  module Non_snark : sig
    module V1 : sig
      type t =
        { ledger_hash : Mina_base_ledger_hash.V1.t
        ; aux_hash : Aux_hash.V1.t
        ; pending_coinbase_aux : Pending_coinbase_aux.V1.t
        }
    end
  end

  module Poly : sig
    module V1 : sig
      type ('non_snark, 'pending_coinbase_hash) t =
        { non_snark : 'non_snark
        ; pending_coinbase_hash : 'pending_coinbase_hash
        }
    end
  end

  module V1 : sig
    type t =
      (Non_snark.V1.t, Mina_base_pending_coinbase.Hash_versioned.V1.t) Poly.V1.t
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
     and module V1 = M.V1
