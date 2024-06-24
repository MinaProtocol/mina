open Utils

module Types : sig
  module type S = sig
    module V2 : S0
  end
end

module type Concrete = sig
  module V2 : sig
    type t = { staged_ledger_diff : Staged_ledger_diff_diff.V3.t }
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module V2 = M.V2
