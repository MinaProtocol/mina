[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

include Pickles.Side_loaded.Verification_key

[%%else]

open Core_kernel

module G = struct
  open Snark_params_nonconsensus

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Field.Stable.V1.t * Field.Stable.V1.t
      [@@deriving sexp, eq, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

include Pickles_base.Side_loaded_verification_key.Make
          (G.Stable.V1)
          (struct
            type t = unit [@@deriving yojson]

            include (Unit : module type of Unit with type t := t)

            let of_repr = ignore
          end)

let to_input = Pickles_base.Side_loaded_verification_key.to_input

let dummy : t =
  let open Pickles_types in
  { step_data= At_most.[]
  ; max_width= Pickles_base.Side_loaded_verification_key.Width.zero
  ; wrap_index=
      (let g = [Snarkette.Tweedle.Dee.(to_affine_exn one)] in
       { sigma_comm_0= g
       ; sigma_comm_1= g
       ; sigma_comm_2= g
       ; ql_comm= g
       ; qr_comm= g
       ; qo_comm= g
       ; qm_comm= g
       ; qc_comm= g
       ; rcm_comm_0= g
       ; rcm_comm_1= g
       ; rcm_comm_2= g
       ; psm_comm= g
       ; add_comm= g
       ; mul1_comm= g
       ; mul2_comm= g
       ; emul1_comm= g
       ; emul2_comm= g
       ; emul3_comm= g })
  ; wrap_vk= None }

[%%endif]
