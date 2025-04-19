module Poly = Snark_work_lib.Work

module Compact = struct
  module Single = struct
    module Spec = struct
      type t = (Transaction_witness.t, Ledger_proof.Cached.t) Poly.Single.Spec.t
    end
  end

  module Spec = struct
    type t = Single.Spec.t Poly.Spec.t
  end

  module Result = struct
    type t = (Spec.t, Ledger_proof.Cached.t) Poly.Result.t
  end
end
