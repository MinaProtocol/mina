open Kimchi_backend_common
open Kimchi_pasta_basic

include
  Plonk_constraint_system.Make (Fq) (Kimchi_bindings.Protocol.Gates.Vector.Fq)
    (struct
      let params =
        Sponge.Params.(
          map pasta_q_kimchi ~f:(fun x ->
              Fq.of_bigint (Bigint256.of_decimal_string x) ))
    end)
