open Utils

module Types = struct
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

module M = struct
  module Poly = struct
    module V1 = struct
      type ('slot_number, 'slots_per_epoch) t =
        { slot_number : 'slot_number; slots_per_epoch : 'slots_per_epoch }
    end
  end

  module V1 = struct
    type t = (Mina_numbers.Global_slot.V1.t, Mina_numbers.Length.V1.t) Poly.V1.t
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
