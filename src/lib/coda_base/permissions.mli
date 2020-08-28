open Pickles.Impls.Step

module Auth_required : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = None | Either | Proof | Signature | Both | Impossible
      [@@deriving sexp, eq, compare, hash, yojson, enum]
    end
  end]

  val to_input : t -> (_, bool) Random_oracle_input.t

  val check : t -> Control.Tag.t -> bool

  module Checked : sig
    type t

    val if_ : Boolean.var -> then_:t -> else_:t -> t

    val to_input : t -> (_, Boolean.var) Random_oracle_input.t

    val spec_eval
      : t -> signature_verifies:Boolean.var
      -> (Boolean.var * [`proof_must_verify of Boolean.var])
  end

  val typ : (Checked.t, t) Typ.t
end

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('bool, 'controller) t =
        { stake: 'bool
        ; edit_state: 'controller
        ; send: 'controller
        ; receive: 'controller (* TODO: Consider having fee *)
        ; set_delegate: 'controller
        ; set_permissions: 'controller
        ; set_verification_key: 'controller }
      [@@deriving sexp, eq, compare, hash, yojson, hlist, fields]
    end
  end]
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = (bool, Auth_required.Stable.V1.t) Poly.Stable.V1.t
    [@@deriving sexp, eq, compare, hash, yojson]
  end
end]

val to_input : t -> (_, bool) Random_oracle_input.t

module Checked : sig
  type t = (Boolean.var, Auth_required.Checked.t) Poly.Stable.Latest.t

  val to_input : t -> (_, Boolean.var) Random_oracle_input.t

  val constant : Stable.Latest.t -> t

  val if_ : Boolean.var -> then_:t -> else_:t -> t
end

val typ : (Checked.t, t) Typ.t

val user_default : t

val empty : t
