[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick

module Auth_required : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t = Mina_wire_types.Mina_base.Permissions.Auth_required.V2.t =
        | None
        | Either
        | Proof
        | Signature
        | Impossible
      [@@deriving sexp, equal, compare, hash, yojson, enum]
    end
  end]

  val from : auth_tag:Control.Tag.t -> t

  val to_input : t -> Field.t Random_oracle_input.Chunked.t

  val check : t -> Control.Tag.t -> bool

  val to_string : t -> string

  val of_string : string -> t

  val verification_key_perm_fallback_to_signature_with_older_version : t -> t

  [%%ifdef consensus_mechanism]

  module Checked : sig
    type t

    val if_ : Boolean.var -> then_:t -> else_:t -> t

    val to_input : t -> Field.Var.t Random_oracle_input.Chunked.t

    val eval_no_proof : t -> signature_verifies:Boolean.var -> Boolean.var

    val eval_proof : t -> Boolean.var

    val spec_eval :
         t
      -> signature_verifies:Boolean.var
      -> Boolean.var * [ `proof_must_verify of Boolean.var ]

    val verification_key_perm_fallback_to_signature_with_older_version : t -> t
  end

  val typ : (Checked.t, t) Typ.t

  [%%endif]
end

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type ('controller, 'txn_version) t =
            ( 'controller
            , 'txn_version )
            Mina_wire_types.Mina_base.Permissions.Poly.V2.t =
        { edit_state : 'controller
        ; access : 'controller
        ; send : 'controller
        ; receive : 'controller (* TODO: Consider having fee *)
        ; set_delegate : 'controller
        ; set_permissions : 'controller
        ; set_verification_key : 'controller * 'txn_version
        ; set_zkapp_uri : 'controller
        ; edit_action_state : 'controller
        ; set_token_symbol : 'controller
        ; increment_nonce : 'controller
        ; set_voting_for : 'controller
        ; set_timing : 'controller
        }
      [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    end
  end]
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type t =
      ( Auth_required.Stable.V2.t
      , Mina_numbers.Txn_version.Stable.V1.t )
      Poly.Stable.V2.t
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
  type t =
    ( Auth_required.Checked.t
    , Mina_numbers.Txn_version.Checked.t )
    Poly.Stable.Latest.t

  val to_input : t -> Field.Var.t Random_oracle_input.Chunked.t

  val constant : Stable.Latest.t -> t

  val if_ : Boolean.var -> then_:t -> else_:t -> t Checked.t
end

val typ : (Checked.t, t) Typ.t

[%%endif]

val user_default : t

val empty : t

val deriver :
     (< contramap : (t -> t) ref
      ; graphql_arg : (unit -> t Fields_derivers_graphql.Schema.Arg.arg_typ) ref
      ; graphql_arg_accumulator :
          t Fields_derivers_zkapps.Graphql.Args.Acc.T.t ref
      ; graphql_creator : ('a -> t) ref
      ; graphql_fields : t Fields_derivers_zkapps.Graphql.Fields.Input.T.t ref
      ; graphql_fields_accumulator :
          t Fields_derivers_zkapps.Graphql.Fields.Accumulator.T.t list ref
      ; graphql_query : string option ref
      ; graphql_query_accumulator : (string * string option) option list ref
      ; js_layout : Yojson.Safe.t ref
      ; js_layout_accumulator :
          Fields_derivers_zkapps.Js_layout.Accumulator.field option list ref
      ; map : (t -> t) ref
      ; nullable_graphql_arg :
          (unit -> 'b Fields_derivers_graphql.Schema.Arg.arg_typ) ref
      ; nullable_graphql_fields :
          t option Fields_derivers_zkapps.Graphql.Fields.Input.T.t ref
      ; of_json : (Yojson.Safe.t -> t) ref
      ; of_json_creator : Yojson.Safe.t Core_kernel.String.Map.t ref
      ; skip : bool ref
      ; to_json : (t -> Yojson.Safe.t) ref
      ; to_json_accumulator : (string * (t -> Yojson.Safe.t)) option list ref
      ; .. >
      as
      'a )
  -> 'a
