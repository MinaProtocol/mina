module Poly = Snark_work_lib.Work
module Partitioned_work = Snark_work_lib.Partitioned

module Compact = struct
  module Spec = struct
    type t = Partitioned_work.Selector_work.t Poly.Spec.t
  end

  module Result = struct
    type t = (Spec.t, Ledger_proof.Cached.t) Poly.Result.t
  end
end
