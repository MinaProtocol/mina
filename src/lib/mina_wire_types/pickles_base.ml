module Proofs_verified = struct
  module V1 = struct
    type t = N0 | N1 | N2
  end
end

module Side_loaded_verification_key = struct
  module Poly = struct
    module V2 = struct
      type ('g, 'proofs_verified, 'vk) t =
        { max_proofs_verified : 'proofs_verified
        ; actual_wrap_domain_size : 'proofs_verified
        ; wrap_index : 'g Pickles_types.Plonk_verification_key_evals.Stable.V2.t
        ; wrap_vk : 'vk option
        }
    end
  end
end
