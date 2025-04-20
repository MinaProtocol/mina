module Poly = Snark_work_lib.Work

module Compact = struct
  module Spec = struct
    type t = Snark_work_lib.Selector.Work.t Poly.Spec.t
  end

  module Result = struct
    type t = (Spec.t, Ledger_proof.Cached.t) Poly.Result.t
  end
end
