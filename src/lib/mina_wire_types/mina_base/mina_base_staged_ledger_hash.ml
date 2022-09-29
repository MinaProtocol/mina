open Utils

module Types = struct
  module type S = sig
    module Aux_hash : sig
      type t

      module V1 : sig
        type nonrec t = t
      end
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
end

module M = struct
  module Aux_hash = struct
    type t = string

    module V1 = struct
      type nonrec t = string
    end
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
