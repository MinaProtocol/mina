open Impl

module Hash = Knapsack_hash

module Boolean = struct
  include Boolean
  let assert_equal (x : var) (y : var) =
    assert_equal (x :> Cvar.t) (y :> Cvar.t)
  let typ = spec
end

module Field = struct
  include Field
  type var = Cvar.t
  let typ = Var_spec.field
  let to_bits = Field.unpack
  let var_to_bits = Checked.choose_preimage ~length:Field.size_in_bits
end

let request spec x = request_witness spec (As_prover.return x)

let generate_proof = prove
let generate_keypair ~exposing k = generate_keypair exposing k

