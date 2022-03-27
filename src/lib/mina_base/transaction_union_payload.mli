module Tag = Transaction_union_tag

module Body : sig
  type ('tag, 'public_key, 'token_id, 'amount, 'bool) t_ =
    { tag : 'tag
    ; source_pk : 'public_key
    ; receiver_pk : 'public_key
    ; token_id : 'token_id
    ; amount : 'amount
    ; token_locked : 'bool
    }

  val t__of_sexp :
       (Ppx_sexp_conv_lib.Sexp.t -> 'tag)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'public_key)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'token_id)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'amount)
    -> (Ppx_sexp_conv_lib.Sexp.t -> 'bool)
    -> Ppx_sexp_conv_lib.Sexp.t
    -> ('tag, 'public_key, 'token_id, 'amount, 'bool) t_

  val sexp_of_t_ :
       ('tag -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('public_key -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('token_id -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('amount -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('bool -> Ppx_sexp_conv_lib.Sexp.t)
    -> ('tag, 'public_key, 'token_id, 'amount, 'bool) t_
    -> Ppx_sexp_conv_lib.Sexp.t

  val t__to_hlist :
       ('tag, 'public_key, 'token_id, 'amount, 'bool) t_
    -> ( unit
       ,    'tag
         -> 'public_key
         -> 'public_key
         -> 'token_id
         -> 'amount
         -> 'bool
         -> unit )
       H_list.t

  val t__of_hlist :
       ( unit
       ,    'tag
         -> 'public_key
         -> 'public_key
         -> 'token_id
         -> 'amount
         -> 'bool
         -> unit )
       H_list.t
    -> ('tag, 'public_key, 'token_id, 'amount, 'bool) t_

  type t =
    ( Transaction_union_tag.t
    , Signature_lib.Public_key.Compressed.t
    , Token_id.t
    , Currency.Amount.t
    , bool )
    t_

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

  val of_user_command_payload_body :
       Signed_command_payload.Body.t
    -> ( Transaction_union_tag.t
       , Import.Public_key.Compressed.Stable.V1.t
       , Token_id.Stable.V1.t
       , Currency.Amount.Stable.Latest.t
       , bool )
       t_

  val gen :
       fee:Currency.Fee.t
    -> ( Transaction_union_tag.t
       , Signature_lib.Public_key.Compressed.t
       , Token_id.t
       , Currency.Amount.Stable.Latest.t
       , Core_kernel__.Import.bool )
       t_
       Core_kernel__Quickcheck.Generator.t

  type var =
    ( Transaction_union_tag.Unpacked.var
    , Signature_lib.Public_key.Compressed.var
    , Token_id.var
    , Currency.Amount.var
    , Snark_params.Tick.Boolean.var )
    t_

  val spec :
    ( 'a
    , 'b
    ,    Transaction_union_tag.Unpacked.var
      -> Signature_lib.Public_key.Compressed.var
      -> Signature_lib.Public_key.Compressed.var
      -> Token_id.var
      -> Currency.Amount.var
      -> Snark_params.Tick.Boolean.var
      -> 'a
    ,    Transaction_union_tag.t
      -> Signature_lib.Public_key.Compressed.t
      -> Signature_lib.Public_key.Compressed.t
      -> Token_id.t
      -> Currency.Amount.Stable.Latest.t
      -> Snark_params.Tick.Boolean.value
      -> 'b
    , Pickles__Impls.Step.Impl.Internal_Basic.Field.t
    , (unit, unit) Pickles__Impls.Step.Impl.Internal_Basic.Checked.t )
    Snark_params.Tick.Data_spec.data_spec

  val typ :
    ( ( Transaction_union_tag.Unpacked.var
      , Signature_lib.Public_key.Compressed.var
      , Token_id.var
      , Currency.Amount.var
      , Snark_params.Tick.Boolean.var )
      t_
    , ( Transaction_union_tag.t
      , Signature_lib.Public_key.Compressed.t
      , Token_id.t
      , Currency.Amount.Stable.Latest.t
      , Snark_params.Tick.Boolean.value )
      t_ )
    Snark_params.Tick.Typ.t

  module Checked : sig
    val constant : t -> var

    val to_input :
         ( Transaction_union_tag.Unpacked.var
         , Signature_lib__Public_key.Compressed.var
         , Mina_base__Token_id.var
         , Currency.Amount.var
         , Snark_params.Tick.Boolean.var )
         t_
      -> ( ( Snark_params.Tick.Field.Var.t
           , Snark_params.Tick.Boolean.var )
           Random_oracle.Input.t
         , 'a )
         Pickles__Impls.Step.Impl.Internal_Basic.Checked.t
  end

  val to_input :
       ( Transaction_union_tag.t
       , Signature_lib.Public_key.Compressed.t
       , Token_id.t
       , Currency.Amount.Stable.Latest.t
       , bool )
       t_
    -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t
end

type t = (Signed_command_payload.Common.t, Body.t) Signed_command_payload.Poly.t

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

type payload = t

val payload_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_payload : t -> Ppx_sexp_conv_lib.Sexp.t

val of_user_command_payload : Signed_command_payload.t -> t

val gen :
  ( Signed_command_payload.Common.t
  , ( Transaction_union_tag.t
    , Signature_lib.Public_key.Compressed.t
    , Token_id.t
    , Currency.Amount.Stable.Latest.t
    , Core_kernel__.Import.bool )
    Body.t_ )
  Signed_command_payload.Poly.t
  Core_kernel__Quickcheck.Generator.t

type var =
  (Signed_command_payload.Common.var, Body.var) Signed_command_payload.Poly.t

type payload_var = var

val typ : (var, t) Snark_params.Tick.Typ.t

val payload_typ : (var, t) Snark_params.Tick.Typ.t

module Checked : sig
  val to_input :
       var
    -> ( ( Snark_params.Tick.Field.Var.t
         , Snark_params.Tick.Boolean.var )
         Random_oracle.Input.t
       , 'a )
       Pickles__Impls.Step.Impl.Internal_Basic.Checked.t

  val constant : t -> var
end

val to_input : t -> (Snark_params.Tick.Field.t, bool) Random_oracle.Input.t

val excess : t -> Currency.Amount.Signed.t

val fee_excess : t -> (Token_id.t, Currency.Fee.Signed.t) Fee_excess.poly

val supply_increase : t -> Currency.Amount.t

val next_available_token : t -> Token_id.t -> Token_id.t
