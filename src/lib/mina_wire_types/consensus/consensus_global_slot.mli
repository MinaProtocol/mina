open Utils

module Types : sig
  module type S = sig
    module Poly : sig
      module V1 : sig
        type ('slot_number, 'slots_per_epoch) t
      end
    end

    module V1 : sig
      type t =
        (Mina_numbers.Global_slot.V1.t, Mina_numbers.Length.V1.t) Poly.V1.t
    end
  end
end

module type Concrete = sig
  module Poly : sig
    module V1 : sig
      type ('slot_number, 'slots_per_epoch) t =
        { slot_number : 'slot_number; slots_per_epoch : 'slots_per_epoch }
    end
  end

  module V1 : sig
    type t = (Mina_numbers.Global_slot.V1.t, Mina_numbers.Length.V1.t) Poly.V1.t
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module Poly = M.Poly and module V1 = M.V1
