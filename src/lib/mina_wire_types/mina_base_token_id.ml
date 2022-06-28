open Utils

module Types = struct
  module type S = S0
end

module type Concrete = Types.S with type t = Unsigned.UInt64.t

module M = struct
  type t = Unsigned.UInt64.t
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
