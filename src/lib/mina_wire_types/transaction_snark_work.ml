module Statement = struct
  module V2 = struct
    type t = Transaction_snark.Statement.V2.t One_or_two.V1.t
  end
end

module V2 = struct
  type t =
    { fee : Currency.Fee.V1.t
    ; proofs : Ledger_proof.V2.t One_or_two.V1.t
    ; prover : Public_key.Compressed.V1.t
    }
end
