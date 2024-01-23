open Utils

module Amount = struct
  type t = Unsigned.UInt64.t
end

module Make = struct
  module Amount
      (Signature : Signature)
      (F : functor
        (A : sig
           type t = Unsigned.UInt64.t
         end)
        -> Signature(A).S) =
    F (Amount)
end
