open Utils

module Types = struct
  module type S = sig
    module Digest : V1S0
  end
end

module type Concrete = Types.S with type Digest.V1.t = Snark_params.Tick.Field.t

module M = struct
  module Digest = struct
    module V1 = struct
      type t = Snark_params.Tick.Field.t
    end
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
