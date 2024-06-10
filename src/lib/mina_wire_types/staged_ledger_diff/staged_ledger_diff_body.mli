open Utils

module Types : sig
  module type S = sig
    module V1 : S0
  end
end

module type Concrete = sig
  module V1 : sig
    type t = { staged_ledger_diff : Staged_ledger_diff_diff.V2.t }
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module V1 = M.V1
