open Utils

module Types = struct
  module type S = sig
    module Digest : V1S0
  end
end

module type Concrete = Types.S with type Digest.V1.t = string

module M = struct
  module Digest = struct
    module V1 = struct
      type t = string
    end
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
