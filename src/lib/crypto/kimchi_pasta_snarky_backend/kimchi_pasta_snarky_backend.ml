module Vesta_based_plonk = struct
  module Bigint256 =
    Kimchi_backend_common.Bigint.Make
      (Pasta_bindings.BigInt256)
      (struct
        let length_in_bytes = 32
      end)

  module Field = Kimchi_backend_common.Field.Make (struct
    module Bigint = Bigint256
    include Pasta_bindings.Fp
    module Vector = Kimchi_bindings.FieldVectors.Fp
  end)

  module Bigint = struct
    include Bigint256

    let of_data _ = failwith __LOC__

    let to_field = Field.of_bigint

    let of_field = Field.to_bigint
  end

  let field_size = Field.size

  module R1CS_constraint_system =
    Kimchi_backend_common.Plonk_constraint_system.Make
      (Field)
      (Kimchi_bindings.Protocol.Gates.Vector.Fp)
      (struct
        let params = Kimchi_pasta_basic.poseidon_params_fp
      end)
end

module Pallas_based_plonk = struct
  module Bigint256 =
    Kimchi_backend_common.Bigint.Make
      (Pasta_bindings.BigInt256)
      (struct
        let length_in_bytes = 32
      end)

  module Field = Kimchi_backend_common.Field.Make (struct
    module Bigint = Bigint256
    include Pasta_bindings.Fq
    module Vector = Kimchi_bindings.FieldVectors.Fq
  end)

  module Bigint = struct
    include Bigint256

    let of_data _ = failwith __LOC__

    let to_field = Field.of_bigint

    let of_field = Field.to_bigint
  end

  let field_size = Field.size

  module R1CS_constraint_system =
    Kimchi_backend_common.Plonk_constraint_system.Make
      (Field)
      (Kimchi_bindings.Protocol.Gates.Vector.Fq)
      (struct
        let params = Kimchi_pasta_basic.poseidon_params_fq
      end)
end

module Step_impl = Snarky_backendless.Snark.Run.Make (Vesta_based_plonk)
module Wrap_impl = Snarky_backendless.Snark.Run.Make (Pallas_based_plonk)
