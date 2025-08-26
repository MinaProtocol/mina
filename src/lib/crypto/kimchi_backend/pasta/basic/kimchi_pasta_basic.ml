open Core_kernel
open Kimchi_backend_common

module Rounds : sig
  open Plonkish_prelude
  module Wrap = Nat.N15

  module Wrap_vector : Vector.With_version(Wrap).S

  module Step = Nat.N16

  module Step_vector : Vector.With_version(Step).S
end = struct
  open Plonkish_prelude
  module Wrap = Nat.N15
  module Step = Nat.N16

  (* Think about versioning here! These vector types *will* change
     serialization if the numbers above change, and so will require a new
     version number. Thus, it's important that these are modules with new
     versioned types, and not just module aliases to the corresponding vector
     implementation.
  *)

  module Wrap_vector = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type 'a t = 'a Vector.Vector_15.Stable.V1.t
        [@@deriving compare, yojson, sexp, hash, equal]
      end
    end]

    type 'a t = 'a Vector.Vector_15.t
    [@@deriving compare, yojson, sexp, hash, equal]

    let map = Vector.map

    let of_list_exn = Vector.Vector_15.of_list_exn

    let to_list = Vector.to_list
  end

  module Step_vector = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type 'a t = 'a Vector.Vector_16.Stable.V1.t
        [@@deriving compare, yojson, sexp, hash, equal]
      end
    end]

    type 'a t = 'a Vector.Vector_16.t
    [@@deriving compare, yojson, sexp, hash, equal]

    let map = Vector.map

    let of_list_exn = Vector.Vector_16.of_list_exn

    let to_list = Vector.to_list
  end
end

(* why use a functor here? *)
module Bigint256 = Kimchi_pasta_snarky_backend.Bigint256

(* the two pasta fields and curves *)

module Fp = Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field
module Fq = Kimchi_pasta_snarky_backend.Pallas_based_plonk.Field

module Vesta = struct
  module Params = struct
    open Fq

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fq) (Fp) (Params) (Pasta_bindings.Vesta)
end

module Pallas = struct
  module Params = struct
    open Fp

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fp) (Fq) (Params) (Pasta_bindings.Pallas)
end

(* the polynomial commitment types *)

module Fq_poly_comm = Kimchi_backend_common.Poly_comm.Make (struct
  module Curve = Pallas
  module Base_field = Fp

  module Backend = struct
    type t = Curve.Affine.Backend.t Kimchi_types.poly_comm

    let shifted ({ shifted; _ } : t) = shifted

    let unshifted ({ unshifted; _ } : t) = unshifted

    let make :
        Curve.Affine.Backend.t array -> Curve.Affine.Backend.t option -> t =
     fun unshifted shifted : t -> { shifted; unshifted }
  end
end)

module Fp_poly_comm = Kimchi_backend_common.Poly_comm.Make (struct
  module Curve = Vesta
  module Base_field = Fq

  module Backend = struct
    type t = Curve.Affine.Backend.t Kimchi_types.poly_comm

    let shifted ({ shifted; _ } : t) = shifted

    let unshifted ({ unshifted; _ } : t) = unshifted

    let make :
        Curve.Affine.Backend.t array -> Curve.Affine.Backend.t option -> t =
     fun unshifted shifted : t -> { shifted; unshifted }
  end
end)

(* poseidon params *)

let poseidon_params_fp =
  Kimchi_pasta_snarky_backend.Vesta_based_plonk.poseidon_params

let poseidon_params_fq =
  Kimchi_pasta_snarky_backend.Pallas_based_plonk.poseidon_params
