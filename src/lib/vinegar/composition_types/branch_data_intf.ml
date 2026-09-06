module type S = sig
  open Core_kernel
  module Proofs_verified = Vinegar_base.Proofs_verified

  module Domain_log2 : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type t [@@deriving compare, sexp, yojson, hash, equal]
      end
    end]

    val of_int_exn : int -> t
  end

  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        { proofs_verified : Proofs_verified.Stable.V1.t
        ; domain_log2 : Domain_log2.Stable.V1.t
        }
      [@@deriving hlist, compare, sexp, yojson, hash, equal]
    end
  end]

  module Checked : sig
    type 'f t =
      { proofs_verified_mask : 'f Proofs_verified.Prefix_mask.Checked.t
      ; domain_log2 : 'f Snarky_backendless.Cvar.t
      }

    val pack :
         (module Snarky_backendless.Snark_intf.Run with type field = 'f)
      -> 'f t
      -> 'f Snarky_backendless.Cvar.t
  end

  module Impls := Kimchi_pasta_snarky_backend

  val typ :
       assert_16_bits:(Impls.Step_impl.Field.t -> unit)
    -> (Impls.Step_impl.Field.Constant.t Checked.t, t) Impls.Step_impl.Typ.t

  val wrap_typ :
       assert_16_bits:(Impls.Wrap_impl.Field.t -> unit)
    -> (Impls.Wrap_impl.Field.Constant.t Checked.t, t) Impls.Wrap_impl.Typ.t

  val packed_typ : (Impls.Step_impl.Field.t, t) Impls.Step_impl.Typ.t

  val wrap_packed_typ : (Impls.Wrap_impl.Field.t, t) Impls.Wrap_impl.Typ.t

  val length_in_bits : int

  val domain : t -> Vinegar_base.Domain.t
end
