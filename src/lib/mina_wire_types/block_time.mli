open Utils

module Types : sig
  module type S = sig
    include V1S0

    module Span : V1S0
  end
end

module type Concrete =
  Types.S
    with type V1.t = Unsigned.UInt64.t
     and type Span.V1.t = Unsigned.UInt64.t

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module V1 = M.V1 and module Span = M.Span
