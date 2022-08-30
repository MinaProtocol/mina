open Utils

module Branch_data : sig
  module Types : sig
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

  module M : Types.S

  module type Local_sig = Signature(Types).S

  module Make
      (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
    Signature(M).S

  include Types.S with module Domain_log2 = M.Domain_log2 and module V1 = M.V1
end
