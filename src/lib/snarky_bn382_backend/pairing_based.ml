module Bigint = struct
  module R = struct
    include Bigint.R

    let to_field x =
      let r = Snarky_bn382.Fp.of_bigint x in
      Gc.finalise Snarky_bn382.Fp.delete r ;
      r

    let of_field x =
      let r = Snarky_bn382.Fp.to_bigint x in
      Gc.finalise Snarky_bn382.Bigint.delete r ;
      r
  end
end

let field_size : Bigint.R.t = Snarky_bn382.Fp.size ()

module Field = Fp
module Proving_key = Proving_key
module R1CS_constraint_system = R1cs_constraint_system
module Var = Var
module Verification_key = Verification_key
module Keypair = Keypair
module Proof = Proof
