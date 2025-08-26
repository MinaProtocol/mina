module Kimchi_backend_common = struct
  module Field = Kimchi_pasta_snarky_backend__.Field
  module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
  module Plonk_types = Kimchi_backend_common.Plonk_types
  module Plonk_verification_key_evals =
    Kimchi_backend_common.Plonk_verification_key_evals
end

module Field = Kimchi_backend_common.Field
module Plonk_types = Kimchi_backend_common.Plonk_types
module Plonk_verification_key_evals =
  Kimchi_backend_common.Plonk_verification_key_evals

module Pasta = struct
  module Basic = Kimchi_pasta.Basic
  module Pallas_based_plonk = Kimchi_pasta.Pallas_based_plonk
  module Pasta = Kimchi_pasta.Pasta
  module Vesta_based_plonk = Kimchi_pasta.Vesta_based_plonk
end
