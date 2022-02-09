[%%import "/src/config.mlh"]

open Snark_params.Tick

module Auth_required : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = None | Either | Proof | Signature | Both | Impossible
      [@@deriving sexp, equal, compare, hash, yojson, enum]
    end
  end]

  val to_input : t -> Field.t Random_oracle_input.Chunked.t

  val check : t -> Control.Tag.t -> bool

  [%%ifdef consensus_mechanism]

  module Checked : sig
    type t

    val if_ : Boolean.var -> then_:t -> else_:t -> t

    val to_input : t -> Field.Var.t Random_oracle_input.Chunked.t

    val eval_no_proof : t -> signature_verifies:Boolean.var -> Boolean.var

    val spec_eval :
         t
      -> signature_verifies:Boolean.var
      -> Boolean.var * [ `proof_must_verify of Boolean.var ]
  end

  val typ : (Checked.t, t) Typ.t

  [%%endif]
end

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type ('bool, 'controller) t =
        { stake : 'bool
        ; edit_state : 'controller
        ; send : 'controller
        ; receive : 'controller (* TODO: Consider having fee *)
        ; set_delegate : 'controller
        ; set_permissions : 'controller
        ; set_verification_key : 'controller
        ; set_snapp_uri : 'controller
        ; edit_sequence_state : 'controller
        ; set_token_symbol : 'controller
        ; increment_nonce : 'controller
        ; set_voting_for : 'controller
        }
      [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    end
  end]
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type t = (bool, Auth_required.Stable.V1.t) Poly.Stable.V2.t
    [@@deriving sexp, equal, compare, hash, yojson]
  end
end]

(** if [auth_tag] is provided, the generated permissions will be compatible with
    the corresponding authorization
*)
val gen : auth_tag:Control.Tag.t -> t Core_kernel.Quickcheck.Generator.t

val to_input : t -> Field.t Random_oracle_input.Chunked.t

[%%ifdef consensus_mechanism]

module Checked : sig
  type t = (Boolean.var, Auth_required.Checked.t) Poly.Stable.Latest.t

  val to_input : t -> Field.Var.t Random_oracle_input.Chunked.t

  val constant : Stable.Latest.t -> t

  val if_ : Boolean.var -> then_:t -> else_:t -> t
end

val typ : (Checked.t, t) Typ.t

[%%endif]

val user_default : t

val empty : t
