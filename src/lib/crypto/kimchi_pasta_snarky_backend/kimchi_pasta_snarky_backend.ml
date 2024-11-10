module Vesta_based_plonk = struct
  module Field = Kimchi_pasta.Vesta_based_plonk.Field
  module Bigint = Kimchi_pasta.Vesta_based_plonk.Bigint

  let field_size = Kimchi_pasta.Vesta_based_plonk.field_size

  module R1CS_constraint_system =
    Kimchi_pasta.Vesta_based_plonk.R1CS_constraint_system
end

module Pallas_based_plonk = struct
  module Field = Kimchi_pasta.Pallas_based_plonk.Field
  module Bigint = Kimchi_pasta.Pallas_based_plonk.Bigint

  let field_size = Kimchi_pasta.Pallas_based_plonk.field_size

  module R1CS_constraint_system =
    Kimchi_pasta.Pallas_based_plonk.R1CS_constraint_system
end

module Step_impl = Snarky_backendless.Snark.Run.Make (Vesta_based_plonk)
module Wrap_impl = Snarky_backendless.Snark.Run.Make (Pallas_based_plonk)
