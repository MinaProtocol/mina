open Utils

module Branch_data = struct
  module Types = struct
    module type S = sig
      module Domain_log2 : V1S0

      module V1 : sig
        type t =
          { proofs_verified : Pickles_base.Proofs_verified.V1.t
          ; domain_log2 : Domain_log2.V1.t
          }
      end
    end
  end

  module type Concrete = Types.S with type Domain_log2.V1.t = char

  module M = struct
    module Domain_log2 = struct
      module V1 = struct
        type t = char
      end
    end

    module V1 = struct
      type t =
        { proofs_verified : Pickles_base.Proofs_verified.V1.t
        ; domain_log2 : Domain_log2.V1.t
        }
    end
  end

  module type Local_sig = Signature(Types).S

  module Make
      (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
    F (M)
  include M
end
