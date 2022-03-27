module Tag = Transaction_union_tag
module Payload = Transaction_union_payload

type ('payload, 'pk, 'signature) t_ =
  { payload : 'payload; signer : 'pk; signature : 'signature }

val equal_t_ :
     ('payload -> 'payload -> bool)
  -> ('pk -> 'pk -> bool)
  -> ('signature -> 'signature -> bool)
  -> ('payload, 'pk, 'signature) t_
  -> ('payload, 'pk, 'signature) t_
  -> bool

val t__of_sexp :
     (Ppx_sexp_conv_lib.Sexp.t -> 'payload)
  -> (Ppx_sexp_conv_lib.Sexp.t -> 'pk)
  -> (Ppx_sexp_conv_lib.Sexp.t -> 'signature)
  -> Ppx_sexp_conv_lib.Sexp.t
  -> ('payload, 'pk, 'signature) t_

val sexp_of_t_ :
     ('payload -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('pk -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('signature -> Ppx_sexp_conv_lib.Sexp.t)
  -> ('payload, 'pk, 'signature) t_
  -> Ppx_sexp_conv_lib.Sexp.t

val hash_fold_t_ :
     (Ppx_hash_lib.Std.Hash.state -> 'payload -> Ppx_hash_lib.Std.Hash.state)
  -> (Ppx_hash_lib.Std.Hash.state -> 'pk -> Ppx_hash_lib.Std.Hash.state)
  -> (Ppx_hash_lib.Std.Hash.state -> 'signature -> Ppx_hash_lib.Std.Hash.state)
  -> Ppx_hash_lib.Std.Hash.state
  -> ('payload, 'pk, 'signature) t_
  -> Ppx_hash_lib.Std.Hash.state

val t__to_hlist :
     ('payload, 'pk, 'signature) t_
  -> (unit, 'payload -> 'pk -> 'signature -> unit) H_list.t

val t__of_hlist :
     (unit, 'payload -> 'pk -> 'signature -> unit) H_list.t
  -> ('payload, 'pk, 'signature) t_

type t =
  (Transaction_union_payload.t, Signature_lib.Public_key.t, Signature.t) t_

type var =
  ( Transaction_union_payload.var
  , Signature_lib.Public_key.var
  , Signature.var )
  t_

val typ : (var, t) Snark_params.Tick.Typ.t

val of_transaction : Signed_command.t Transaction.Poly.t -> t

val fee_excess : t -> (Token_id.t, Currency.Fee.Signed.t) Fee_excess.poly

val supply_increase : t -> Currency.Amount.t

val next_available_token : t -> Token_id.t -> Token_id.t
