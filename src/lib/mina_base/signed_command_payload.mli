[%%import "/src/config.mlh"]

open Core_kernel
open Mina_base_import
open Snark_params.Tick

(* This represents the random oracle input corresponding to the old form of the token
   ID, which was a 64-bit integer. The default token id was the number 1.

   The corresponding random oracle input is still needed for signing non-snapp
   transactions to maintain compatibility with the old transaction format.
*)
module Legacy_token_id : sig
  val default : (Field.t, bool) Random_oracle_input.Legacy.t

  [%%ifdef consensus_mechanism]

  val default_checked : (Field.Var.t, Boolean.var) Random_oracle_input.Legacy.t

  [%%endif]
end

module Body : sig
  type t = Mina_wire_types.Mina_base.Signed_command_payload.Body.V2.t =
    | Payment of Payment_payload.t
    | Stake_delegation of Stake_delegation.t
  [@@deriving equal, sexp, hash, yojson]

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type nonrec t = t [@@deriving compare, equal, sexp, hash, yojson]
    end
  end]

  val tag : t -> Transaction_union_tag.t

  val receiver_pk : t -> Signature_lib.Public_key.Compressed.t

  val receiver : t -> Account_id.t

  val source_pk : t -> Signature_lib.Public_key.Compressed.t

  val source : t -> Account_id.t
end

module Common : sig
  module Poly : sig
    [%%versioned:
    module Stable : sig
      module V2 : sig
        type ('fee, 'public_key, 'nonce, 'global_slot, 'memo) t =
              ( 'fee
              , 'public_key
              , 'nonce
              , 'global_slot
              , 'memo )
              Mina_wire_types.Mina_base.Signed_command_payload.Common.Poly.V2.t =
          { fee : 'fee
          ; fee_payer_pk : 'public_key
          ; nonce : 'nonce
          ; valid_until : 'global_slot
          ; memo : 'memo
          }
        [@@deriving equal, sexp, hash, yojson]
      end
    end]
  end

  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t =
        ( Currency.Fee.Stable.V1.t
        , Public_key.Compressed.Stable.V1.t
        , Mina_numbers.Account_nonce.Stable.V1.t
        , Mina_numbers.Global_slot.Stable.V1.t
        , Signed_command_memo.t )
        Poly.Stable.V2.t
      [@@deriving compare, equal, sexp, hash]
    end
  end]

  val to_input_legacy : t -> (Field.t, bool) Random_oracle.Input.Legacy.t

  val gen : t Quickcheck.Generator.t

  [%%ifdef consensus_mechanism]

  type var =
    ( Currency.Fee.var
    , Public_key.Compressed.var
    , Mina_numbers.Account_nonce.Checked.t
    , Mina_numbers.Global_slot.Checked.t
    , Signed_command_memo.Checked.t )
    Poly.t

  val typ : (var, t) Typ.t

  module Checked : sig
    val to_input_legacy :
         var
      -> (Field.Var.t, Boolean.var) Random_oracle.Input.Legacy.t
         Snark_params.Tick.Checked.t

    val constant : t -> var
  end

  [%%endif]
end

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('common, 'body) t =
            ( 'common
            , 'body )
            Mina_wire_types.Mina_base.Signed_command_payload.Poly.V1.t =
        { common : 'common; body : 'body }
      [@@deriving equal, sexp, hash, yojson, compare, hlist]

      val of_latest :
           ('common1 -> ('common2, 'err) Result.t)
        -> ('body1 -> ('body2, 'err) Result.t)
        -> ('common1, 'body1) t
        -> (('common2, 'body2) t, 'err) Result.t
    end
  end]
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type t = (Common.Stable.V2.t, Body.Stable.V2.t) Poly.Stable.V1.t
    [@@deriving compare, equal, sexp, hash, yojson]
  end
end]

val create :
     fee:Currency.Fee.t
  -> fee_payer_pk:Public_key.Compressed.t
  -> nonce:Mina_numbers.Account_nonce.t
  -> valid_until:Mina_numbers.Global_slot.t option
  -> memo:Signed_command_memo.t
  -> body:Body.t
  -> t

val dummy : t

val fee : t -> Currency.Fee.t

val fee_payer_pk : t -> Public_key.Compressed.t

val fee_payer : t -> Account_id.t

val fee_excess : t -> Fee_excess.t

val nonce : t -> Mina_numbers.Account_nonce.t

val valid_until : t -> Mina_numbers.Global_slot.t

val memo : t -> Signed_command_memo.t

val body : t -> Body.t

val receiver_pk : t -> Public_key.Compressed.t

val receiver : t -> Account_id.t

val source_pk : t -> Public_key.Compressed.t

val source : t -> Account_id.t

val token : t -> Token_id.t

val amount : t -> Currency.Amount.t option

val accounts_accessed : t -> Account_id.t list

val tag : t -> Transaction_union_tag.t

val gen : t Quickcheck.Generator.t

(** This module defines a weight for each payload component *)
module Weight : sig
  val of_body : Body.t -> int
end

val weight : t -> int
