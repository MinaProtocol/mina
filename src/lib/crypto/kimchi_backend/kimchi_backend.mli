module Kimchi_backend_common : sig
  module Field : sig
    (* module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint *)

    (* module type Input_intf = Kimchi_backend_common.Field.Input_intf *)

    module type S = Kimchi_backend_common.Field.S

    (* module type S_with_version = Kimchi_backend_common.Field.S_with_version *)

    (* module Make = Kimchi_backend_common.Field.Make *)
  end

  module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
end

module Field = Kimchi_backend_common.Field

module Pasta : sig
  module Basic = Kimchi_pasta.Basic
  module Pallas_based_plonk = Kimchi_pasta.Pallas_based_plonk
  module Pasta = Kimchi_pasta.Pasta
  module Precomputed = Kimchi_pasta.Precomputed
  module Vesta_based_plonk = Kimchi_pasta.Vesta_based_plonk
end
