open Utils

module Types = struct
  module type S = sig
    module Aux_hash : sig
      type t

      module V1 : sig
        type nonrec t = t
      end
    end

    module Pending_coinbase_aux : V1S0

    module V1 : S0
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

module M = struct
  module Aux_hash = struct
    type t = string

    module V1 = struct
      type nonrec t = string
    end
  end

  module Pending_coinbase_aux = struct
    module V1 = struct
      type t = string
    end
  end

  module Non_snark = struct
    module V1 = struct
      type t =
        { ledger_hash : Mina_base_ledger_hash.V1.t
        ; aux_hash : Aux_hash.V1.t
        ; pending_coinbase_aux : Pending_coinbase_aux.V1.t
        }
    end
  end

  module Poly = struct
    module V1 = struct
      type ('non_snark, 'pending_coinbase_hash) t =
        { non_snark : 'non_snark
        ; pending_coinbase_hash : 'pending_coinbase_hash
        }
    end
  end

  module V1 = struct
    type t =
      (Non_snark.V1.t, Mina_base_pending_coinbase.Hash_versioned.V1.t) Poly.V1.t
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
