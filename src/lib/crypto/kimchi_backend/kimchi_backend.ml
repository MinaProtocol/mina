module Kimchi_backend_common = struct
  module Field = Kimchi_backend_common.Field
  module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
end

module Field = Kimchi_backend_common.Field

module Pasta = struct
  module Basic = Kimchi_pasta.Basic
  module Pallas_based_plonk = Kimchi_pasta.Pallas_based_plonk
  module Pasta = Kimchi_pasta.Pasta
  module Vesta_based_plonk = Kimchi_pasta.Vesta_based_plonk
end

module Bn254 = struct
  module Bn254 = Kimchi_bn254.Bn254
  module Bn254_based_plonk = Kimchi_bn254.Bn254_based_plonk
  module Impl = Kimchi_bn254.Impl
end
