open Pickles_types

module type S = sig
  open Core_kernel
  module Proofs_verified = Pickles_base.Proofs_verified

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
    module Step : sig
      open Kimchi_pasta_snarky_backend.Step_impl

      type field_var = Field.t

      type 'num_additional_proofs t =
        { proofs_verified_mask :
            'num_additional_proofs Proofs_verified.Prefix_mask.Step.Checked.t
        ; domain_log2 : Field.t
        }

      val pack : 'num_additional_proofs t -> Field.t
    end

    module Wrap : sig
      open Kimchi_pasta_snarky_backend.Wrap_impl

      type field_var = Field.t

      type 'num_additional_proofs t =
        { proofs_verified_mask :
            'num_additional_proofs Proofs_verified.Prefix_mask.Wrap.Checked.t
        ; domain_log2 : Field.t
        }

      val pack : 'num_additional_proofs t -> Field.t
    end
  end

  module Impls := Kimchi_pasta_snarky_backend

  val typ :
       num_allowable_proofs:'num_additional_proofs Nat.N2.plus_n Nat.t
    -> assert_16_bits:(Impls.Step_impl.Field.t -> unit)
    -> ('num_additional_proofs Checked.Step.t, t) Impls.Step_impl.Typ.t

  val wrap_typ :
       num_allowable_proofs:'num_additional_proofs Nat.N2.plus_n Nat.t
    -> assert_16_bits:(Impls.Wrap_impl.Field.t -> unit)
    -> ('num_additional_proofs Checked.Wrap.t, t) Impls.Wrap_impl.Typ.t

  val packed_typ :
       num_allowable_proofs:'num_additional_proofs Nat.N2.plus_n Nat.t
    -> (Impls.Step_impl.Field.t, t) Impls.Step_impl.Typ.t

  val wrap_packed_typ :
       num_allowable_proofs:'num_additional_proofs Nat.N2.plus_n Nat.t
    -> (Impls.Wrap_impl.Field.t, t) Impls.Wrap_impl.Typ.t

  val length_in_bits : int

  val domain : t -> Pickles_base.Domain.t
end
