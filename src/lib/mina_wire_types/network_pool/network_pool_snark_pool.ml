module Diff_versioned = struct
  module V2 = struct
    type t =
      | Add_solved_work of
          Transaction_snark_work.Statement.V2.t
          * Ledger_proof.V2.t One_or_two.V1.t Network_pool_priced_proof.V1.t
      | Empty
  end
end
