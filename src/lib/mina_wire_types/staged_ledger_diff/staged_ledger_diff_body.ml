open Utils

module Types = struct
  module type S = sig
    module V1 : S0
  end
end

module type Concrete = sig
  module V1 : sig
    type t = { staged_ledger_diff : Staged_ledger_diff_diff.V2.t }
  end
end

module M = struct
  module V1 = struct
    type t = { staged_ledger_diff : Staged_ledger_diff_diff.V2.t }
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
