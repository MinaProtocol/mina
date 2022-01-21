[%%import "/src/config.mlh"]

[%%ifdef consensus_mechanism]

include Pickles.Side_loaded.Verification_key

[%%else]

open Core_kernel

module G = struct
  open Snark_params_nonconsensus

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Field.Stable.V1.t * Field.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

module R = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        G.Stable.V1.t Pickles_base.Side_loaded_verification_key.Repr.Stable.V2.t

      let to_latest = Fn.id
    end
  end]
end

[%%versioned_binable
module Stable = struct
  module V2 = struct
    type t =
      ( G.Stable.V1.t
      , unit )
      Pickles_base.Side_loaded_verification_key.Poly.Stable.V2.t
    [@@deriving sexp, compare, equal, hash, yojson]

    open Pickles_base.Side_loaded_verification_key

    let to_latest = Fn.id

    include Binable.Of_binable
              (R.Stable.V2)
              (struct
                type nonrec t = t

                let to_binable
                    { Poly.step_data; max_width; wrap_index; wrap_vk = _ } =
                  { Repr.Stable.V2.step_data; max_width; wrap_index }

                let of_binable
                    { Repr.Stable.V2.step_data; max_width; wrap_index = c } =
                  { Poly.step_data
                  ; max_width
                  ; wrap_index = c
                  ; wrap_vk = Some ()
                  }
              end)
  end
end]

let to_input = Pickles_base.Side_loaded_verification_key.to_input

let dummy : t =
  let open Pickles_types in
  { step_data = At_most.[]
  ; max_width = Pickles_base.Side_loaded_verification_key.Width.zero
  ; wrap_index =
      (let g = Snarkette.Pasta.Pallas.(to_affine_exn one) in
       { sigma_comm = Vector.init Dlog_plonk_types.Permuts.n ~f:(fun _ -> g)
       ; coefficients_comm =
           Vector.init Dlog_plonk_types.Columns.n ~f:(fun _ -> g)
       ; generic_comm = g
       ; psm_comm = g
       ; complete_add_comm = g
       ; mul_comm = g
       ; emul_comm = g
       ; endomul_scalar_comm = g
       })
  ; wrap_vk = None
  }

[%%endif]
