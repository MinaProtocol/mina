open Core_kernel
open Kimchi_backend_common

(** ? *)
module Rounds : sig
  (* TODO: remove open *)
  open Pickles_types

  module Wrap : Nat.Add.Intf_transparent

  module Wrap_vector : Vector.With_version(Wrap).S

  module Step : Nat.Add.Intf_transparent

  module Step_vector : Vector.With_version(Step).S
end = struct
  open Pickles_types
  module Wrap = Nat.N17
  module Step = Nat.N18

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
        type 'a t = 'a Vector.Vector_17.Stable.V1.t
        [@@deriving compare, yojson, sexp, hash, equal]
      end
    end]

    type 'a t = 'a Vector.Vector_17.t
    [@@deriving compare, yojson, sexp, hash, equal]

    let map = Vector.map

    let of_list_exn = Vector.Vector_17.of_list_exn

    let to_list = Vector.to_list
  end

  module Step_vector = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type 'a t = 'a Vector.Vector_18.Stable.V1.t
        [@@deriving compare, yojson, sexp, hash, equal]
      end
    end]

    type 'a t = 'a Vector.Vector_18.t
    [@@deriving compare, yojson, sexp, hash, equal]

    let map = Vector.map

    let of_list_exn = Vector.Vector_18.of_list_exn

    let to_list = Vector.to_list
  end
end

(* why use a functor here? *)
module Bigint256 =
  Kimchi_backend_common.Bigint.Make
    (Kimchi.Foundations.BigInt256)
    (struct
      let length_in_bytes = 32
    end)

module Fp = Field.Make (struct
  module Bigint = Bigint256
  include Kimchi.Foundations.Fp
  module Vector = Kimchi.FieldVectors.Fp
end)

module Fq = Field.Make (struct
  module Bigint = Bigint256
  include Kimchi.Foundations.Fq
  module Vector = Kimchi.FieldVectors.Fq
end)

module Vesta = struct
  module Params = struct
    open Fq

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fq) (Fp) (Params) (Kimchi.Vesta)
end

module Pallas = struct
  module Params = struct
    open Fp

    let a = zero

    let b = of_int 5
  end

  include Curve.Make (Fp) (Fq) (Params) (Kimchi.Pallas)
end

module Fq_poly_comm = Kimchi_backend_common.Poly_comm.Make (struct
  module Curve = Pallas
  module Base_field = Fp

  module Backend = struct
    include Kimchi.Protocol.Srs.Fq.Poly_comm

    let shifted ({ shifted; _ } : t) = shifted

    let unshifted ({ unshifted; _ } : t) = unshifted

    let make unshifted shifted : t = { shifted; unshifted }
  end
end)

module Fp_poly_comm = Kimchi_backend_common.Poly_comm.Make (struct
  module Curve = Vesta
  module Base_field = Fq

  module Backend = struct
    include Kimchi.Protocol.Srs.Fp.Poly_comm

    let shifted ({ shifted; _ } : t) = shifted

    let unshifted ({ unshifted; _ } : t) = unshifted

    let make unshifted shifted : t = { shifted; unshifted }
  end
end)
