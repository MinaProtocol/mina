open Kimchi_backend_common
open Kimchi_pasta_basic

include
  Plonk_constraint_system.Make (Fq) (Kimchi_bindings.Protocol.Gates.Vector.Fq)
    (struct
      let params = poseidon_params_fq
    end)
