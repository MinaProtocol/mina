module V = Pickles_base.Side_loaded_verification_key

include
  module type of V with module Width := V.Width and module Domains := V.Domains

module Width : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = V.Width.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]

  module Checked : sig
    type t

    val to_field : t -> Impls.Step.Field.t

    val to_bits : t -> Impls.Step.Boolean.var list
  end

  val typ : (Checked.t, t) Impls.Step.Typ.t

  module Max = Pickles_types.Nat.N2

  module Max_vector : Pickles_types.Vector.With_version(Max).S

  module Max_at_most : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type 'a t = ('a, Max.n) Pickles_types.At_most.t
        [@@deriving compare, sexp, yojson, hash, equal]
      end
    end]
  end
end

module Checked : sig
  type t =
    { max_proofs_verified :
        Step_main_inputs.Impl.field
        Pickles_base.Proofs_verified.One_hot.Checked.t
          (** The maximum of all of the [step_widths]. *)
    ; actual_wrap_domain_size :
        Step_main_inputs.Impl.field
        Pickles_base.Proofs_verified.One_hot.Checked.t
          (** The actual domain size used by the wrap circuit. *)
    ; wrap_index :
        Step_main_inputs.Inner_curve.t
        Pickles_types.Plonk_verification_key_evals.t
          (** The plonk verification key for the 'wrapping' proof that this key
              is used to verify.
          *)
    }
  [@@deriving hlist, fields]

  val to_input :
       t
    -> Backend.Tick.Field.t Snarky_backendless.Cvar.t
       Random_oracle_input.Chunked.t
end

module Vk : sig
  type t = (Impls.Wrap.Verification_key.t[@sexp.opaque]) [@@deriving sexp]
end

[@@@warning "-32"]

[%%versioned:
module Stable : sig
  module V2 : sig
    type t =
      ( Backend.Tock.Curve.Affine.t
      , Pickles_base.Proofs_verified.Stable.V1.t
      , Vk.t )
      Poly.Stable.V2.t
    [@@deriving hash, sexp, compare, equal, yojson]

    include Codable.Base58_check_intf with type t := t

    include Codable.Base64_intf with type t := t
  end
end]

type t = Stable.Latest.t [@@deriving hash, sexp, compare, equal]

val dummy : t

include Codable.Base58_check_intf with type t := t

include Codable.Base64_intf with type t := t

val typ : (Checked.t, t) Impls.Step.Typ.t

val to_yojson : t -> [> `String of string ]

val of_yojson : Yojson.Safe.t -> (t, string) Core_kernel.Result.t

module Domain : sig
  type 'a t = Pow_2_roots_of_unity of 'a [@@deriving sexp]

  val log2_size : 'a t -> 'a
end

module Domains : sig
  include module type of V.Domains

  type 'a t = { h : 'a }
end

val max_domains : int Domain.t Domains.t
