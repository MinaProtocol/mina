open Utils

module Amount : sig
  type t
end

module Make : sig
  module Amount
      (Signature : Signature)
      (_ : functor
        (A : sig
           type t = Unsigned.UInt64.t
         end)
        -> Signature(A).S) : Signature(Amount).S
end
