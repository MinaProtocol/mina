[%%import "/src/config.mlh"]

[%%ifdef consensus_mechanism]

include Pickles.Side_loaded.Verification_key

[%%else]

open Core_kernel

module G = struct
  open Snark_params.Tick

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
      [@@deriving sexp, compare, equal, yojson]

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
    [@@deriving hash]

    open Pickles_base.Side_loaded_verification_key

    let to_latest = Fn.id

    let to_repr { Poly.step_data; max_width; wrap_index; wrap_vk = _ } =
      { Repr.Stable.V2.step_data; max_width; wrap_index }

    let of_repr { Repr.Stable.V2.step_data; max_width; wrap_index = c } =
      { Poly.step_data; max_width; wrap_index = c; wrap_vk = Some () }

    include Binable.Of_binable
              (R.Stable.V2)
              (struct
                type nonrec t = t

                let to_binable = to_repr

                let of_binable = of_repr
              end)

    let sexp_of_t t = R.sexp_of_t (to_repr t)

    let t_of_sexp sexp = of_repr (R.t_of_sexp sexp)

    let to_yojson t = R.to_yojson (to_repr t)

    let of_yojson json = Result.map ~f:of_repr (R.of_yojson json)

    let equal x y = R.equal (to_repr x) (to_repr y)

    let compare x y = R.compare (to_repr x) (to_repr y)
  end
end]

let to_input x =
  Pickles_base.Side_loaded_verification_key.to_input
    ~field_of_int:Snark_params.Tick.Field.of_int x

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
