module Kimchi_backend_common = struct
  module Field = Kimchi_backend_common.Field
  module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
end

module Field = Kimchi_backend_common.Field

module Pasta = struct
  module Basic = Kimchi_pasta.Basic
  module Pallas_based_plonk = Kimchi_pasta.Pallas_based_plonk
  module Pasta = Kimchi_pasta.Pasta
  module Precomputed = Kimchi_pasta.Precomputed
  module Vesta_based_plonk = Kimchi_pasta.Vesta_based_plonk
end
