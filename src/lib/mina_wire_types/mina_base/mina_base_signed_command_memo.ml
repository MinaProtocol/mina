open Utils

module Types = struct
  module type S = V1S0
end

module type Concrete = Types.S with type V1.t = string

module M = struct
  module V1 = struct
    type t = string
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
