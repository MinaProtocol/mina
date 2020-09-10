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
      (let g : G.t list = [Snarkette.Tweedle.Dee.(to_affine_exn one)] in
       let t : _ Abc.t = {a= g; b= g; c= g} in
       {row= t; col= t; value= t; rc= t})
  ; wrap_vk= None }

[%%endif]
