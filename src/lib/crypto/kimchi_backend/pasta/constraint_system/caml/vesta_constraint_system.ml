open Kimchi_backend_common
open Kimchi_pasta_basic

include
  Plonk_constraint_system.Make (Fp) (Kimchi_bindings.Protocol.Gates.Vector.Fp)
    (struct
      let params = poseidon_params_fp
    end)
