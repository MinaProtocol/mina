open Utils

module Types = struct
  module type S = S0
end

module type Concrete = Types.S with type t = string

module M = struct
  type t = string
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
