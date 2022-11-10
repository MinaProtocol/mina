open Kimchi_backend_common
open Kimchi_pasta_basic

include
  Plonk_constraint_system.Make (Fp) (Kimchi_bindings.Protocol.Gates.Vector.Fp)
    (struct
      let params =
        Sponge.Params.(
          map pasta_p_kimchi ~f:(fun x ->
              Fp.of_bigint (Bigint256.of_decimal_string x) ))
    end)
