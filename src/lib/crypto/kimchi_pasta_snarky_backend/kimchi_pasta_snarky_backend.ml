module Endoscale_round = Endoscale_round
module Endoscale_scalar_round = Endoscale_scalar_round
module Constants = Constants
module Intf = Intf
module Plonk_constraint_system = Plonk_constraint_system
module Scale_round = Scale_round

module type Snark_intf = Plonk_constraint_system.Snark_intf

module Bigint256 =
  Bigint.Make
    (Pasta_bindings.BigInt256)
    (struct
      let length_in_bytes = 32
    end)

module Vesta_based_plonk = struct
  module Field = Field.Make (struct
    module Bigint = Bigint256
    include Pasta_bindings.Fp
    module Vector = Kimchi_bindings.FieldVectors.Fp
  end)

  let poseidon_params = Sponge.Params.(map pasta_p_kimchi ~f:Field.of_string)

  module Bigint = struct
    include Bigint256

    let of_data _ = failwith __LOC__

    let to_field = Field.of_bigint

    let of_field = Field.to_bigint
  end

  let field_size = Field.size

  module Cvar = Snarky_backendless.Cvar.Make (Field)

  module R1CS_constraint_system =
    Plonk_constraint_system.Make
      (Field)
      (Kimchi_bindings.Protocol.Gates.Vector.Fp)
      (struct
        let params = poseidon_params
      end)

  module Constraint = R1CS_constraint_system.Constraint

  module Run_state = Snarky_backendless.Run_state.Make (struct
    type field = Field.t

    type constraint_ = Constraint.t
  end)
end

module Pallas_based_plonk = struct
  module Field = Field.Make (struct
    module Bigint = Bigint256
    include Pasta_bindings.Fq
    module Vector = Kimchi_bindings.FieldVectors.Fq
  end)

  let poseidon_params = Sponge.Params.(map pasta_q_kimchi ~f:Field.of_string)

  module Bigint = struct
    include Bigint256

    let of_data _ = failwith __LOC__

    let to_field = Field.of_bigint

    let of_field = Field.to_bigint
  end

  let field_size = Field.size

  module Cvar = Snarky_backendless.Cvar.Make (Field)

  module R1CS_constraint_system =
    Plonk_constraint_system.Make
      (Field)
      (Kimchi_bindings.Protocol.Gates.Vector.Fq)
      (struct
        let params = poseidon_params
      end)

  module Constraint = R1CS_constraint_system.Constraint

  module Run_state = Snarky_backendless.Run_state.Make (struct
    type field = Field.t

    type constraint_ = Constraint.t
  end)
end

module Step_impl = Snarky_backendless.Snark.Run.Make (Vesta_based_plonk)
module Wrap_impl = Snarky_backendless.Snark.Run.Make (Pallas_based_plonk)
