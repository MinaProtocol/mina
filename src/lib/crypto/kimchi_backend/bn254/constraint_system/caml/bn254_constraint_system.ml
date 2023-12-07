open Kimchi_backend_common
open Kimchi_bn254_basic

include
  Plonk_constraint_system.Make (Bn254_fp) (Kimchi_bindings.Protocol.Gates.Vector.Bn254Fp)
    (struct
      let params = poseidon_params_fp
    end)
