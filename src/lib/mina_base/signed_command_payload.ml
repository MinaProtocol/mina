(* user_command_payload.ml *)

[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick
open Signature_lib
module Memo = Signed_command_memo
module Account_nonce = Mina_numbers.Account_nonce
module Global_slot = Mina_numbers.Global_slot

(* This represents the random oracle input corresponding to the old form of the token
   ID, which was a 64-bit integer. The default token id was the number 1.

   The corresponding random oracle input is still needed for signing non-snapp
   transactions to maintain compatibility with the old transaction format.
*)
module Legacy_token_id = struct
  let default : (Field.t, bool) Random_oracle_input.Legacy.t =
    let one = true :: List.init 63 ~f:(fun _ -> false) in
    Random_oracle_input.Legacy.bitstring one

  [%%ifdef consensus_mechanism]

  let default_checked : (Field.Var.t, Boolean.var) Random_oracle_input.Legacy.t
      =
    { field_elements = Array.map default.field_elements ~f:Field.Var.constant
    ; bitstrings =
        Array.map default.bitstrings ~f:(List.map ~f:Boolean.var_of_value)
    }

  [%%endif]
end

module Common = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type ('fee, 'public_key, 'nonce, 'global_slot, 'memo) t =
          { fee : 'fee
          ; fee_payer_pk : 'public_key
          ; nonce : 'nonce
          ; valid_until : 'global_slot
          ; memo : 'memo
          }
        [@@deriving compare, equal, sexp, hash, yojson, hlist]
      end

      module V1 = struct
        type ('fee, 'public_key, 'token_id, 'nonce, 'global_slot, 'memo) t =
              ( 'fee
              , 'public_key
              , 'token_id
              , 'nonce
              , 'global_slot
              , 'memo )
              Mina_wire_types.Mina_base.Signed_command_payload.Common.Poly.V1.t =
          { fee : 'fee
          ; fee_token : 'token_id
          ; fee_payer_pk : 'public_key
          ; nonce : 'nonce
          ; valid_until : 'global_slot
          ; memo : 'memo
          }
        [@@deriving compare, equal, sexp, hash, yojson, hlist]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Currency.Fee.Stable.V1.t
        , Public_key.Compressed.Stable.V1.t
        , Account_nonce.Stable.V1.t
        , Global_slot.Stable.V1.t
        , Memo.Stable.V1.t )
        Poly.Stable.V2.t
      [@@deriving compare, equal, sexp, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let to_input_legacy ({ fee; fee_payer_pk; nonce; valid_until; memo } : t) =
    let bitstring = Random_oracle.Input.Legacy.bitstring in
    Array.reduce_exn ~f:Random_oracle.Input.Legacy.append
      [| Currency.Fee.to_input_legacy fee
       ; Legacy_token_id.default
       ; Public_key.Compressed.to_input_legacy fee_payer_pk
       ; Account_nonce.to_input_legacy nonce
       ; Global_slot.to_input_legacy valid_until
       ; bitstring (Memo.to_bits memo)
      |]

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map fee = Currency.Fee.gen
    and fee_payer_pk = Public_key.Compressed.gen
    and nonce = Account_nonce.gen
    and valid_until = Global_slot.gen
    and memo =
      let%bind is_digest = Bool.quickcheck_generator in
      if is_digest then
        String.gen_with_length Memo.max_digestible_string_length
          Char.quickcheck_generator
        >>| Memo.create_by_digesting_string_exn
      else
        String.gen_with_length Memo.max_input_length Char.quickcheck_generator
        >>| Memo.create_from_string_exn
    in
    Poly.{ fee; fee_payer_pk; nonce; valid_until; memo }

  [%%ifdef consensus_mechanism]

  type var =
    ( Currency.Fee.var
    , Public_key.Compressed.var
    , Account_nonce.Checked.t
    , Global_slot.Checked.t
    , Memo.Checked.t )
    Poly.t

  let typ =
    Typ.of_hlistable
      [ Currency.Fee.typ
      ; Public_key.Compressed.typ
      ; Account_nonce.typ
      ; Global_slot.typ
      ; Memo.typ
      ]
      ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
      ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

  module Checked = struct
    let constant ({ fee; fee_payer_pk; nonce; valid_until; memo } : t) : var =
      { fee = Currency.Fee.var_of_t fee
      ; fee_payer_pk = Public_key.Compressed.var_of_t fee_payer_pk
      ; nonce = Account_nonce.Checked.constant nonce
      ; memo = Memo.Checked.constant memo
      ; valid_until = Global_slot.Checked.constant valid_until
      }

    let to_input_legacy ({ fee; fee_payer_pk; nonce; valid_until; memo } : var)
        =
      let%map nonce = Account_nonce.Checked.to_input_legacy nonce
      and valid_until = Global_slot.Checked.to_input_legacy valid_until
      and fee = Currency.Fee.var_to_input_legacy fee in
      let fee_token = Legacy_token_id.default_checked in
      Array.reduce_exn ~f:Random_oracle.Input.Legacy.append
        [| fee
         ; fee_token
         ; Public_key.Compressed.Checked.to_input_legacy fee_payer_pk
         ; nonce
         ; valid_until
         ; Random_oracle.Input.Legacy.bitstring
             (Array.to_list (memo :> Boolean.var array))
        |]
  end

  [%%endif]
end

module Body = struct
  module Binable_arg = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Payment of Payment_payload.Stable.V2.t
          | Stake_delegation of Stake_delegation.Stable.V1.t
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Binable_arg.Stable.V2.t =
        | Payment of Payment_payload.Stable.V2.t
        | Stake_delegation of Stake_delegation.Stable.V1.t
      [@@deriving compare, equal, sexp, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  module Tag = Transaction_union_tag

  let gen ?source_pk ~max_amount =
    let open Quickcheck.Generator in
    let stake_delegation_gen =
      match source_pk with
      | Some source_pk ->
          Stake_delegation.gen_with_delegator source_pk
      | None ->
          Stake_delegation.gen
    in
    map
      (variant2
         (Payment_payload.gen ?source_pk ~max_amount)
         stake_delegation_gen )
      ~f:(function `A p -> Payment p | `B d -> Stake_delegation d)

  let source_pk (t : t) =
    match t with
    | Payment payload ->
        payload.source_pk
    | Stake_delegation payload ->
        Stake_delegation.source_pk payload

  let receiver_pk (t : t) =
    match t with
    | Payment payload ->
        payload.receiver_pk
    | Stake_delegation payload ->
        Stake_delegation.receiver_pk payload

  let token (_ : t) = Token_id.default

  let source t =
    match t with
    | Payment payload ->
        Account_id.create payload.source_pk (token t)
    | Stake_delegation payload ->
        Stake_delegation.source payload

  let receiver t =
    match t with
    | Payment payload ->
        Account_id.create payload.receiver_pk Token_id.default
    | Stake_delegation payload ->
        Stake_delegation.receiver payload

  let tag = function
    | Payment _ ->
        Transaction_union_tag.Payment
    | Stake_delegation _ ->
        Transaction_union_tag.Stake_delegation
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('common, 'body) t =
            ( 'common
            , 'body )
            Mina_wire_types.Mina_base.Signed_command_payload.Poly.V1.t =
        { common : 'common; body : 'body }
      [@@deriving equal, sexp, hash, yojson, compare, hlist]

      let of_latest common_latest body_latest { common; body } =
        let open Result.Let_syntax in
        let%map common = common_latest common and body = body_latest body in
        { common; body }
    end
  end]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t = (Common.Stable.V2.t, Body.Stable.V2.t) Poly.Stable.V1.t
    [@@deriving compare, equal, sexp, hash, yojson]

    let to_latest = Fn.id
  end
end]

let create ~fee ~fee_payer_pk ~nonce ~valid_until ~memo ~body : t =
  { common =
      { fee
      ; fee_payer_pk
      ; nonce
      ; valid_until = Option.value valid_until ~default:Global_slot.max_value
      ; memo
      }
  ; body
  }

let fee (t : t) = t.common.fee

let fee_token (_ : t) = Token_id.default

let fee_payer_pk (t : t) = t.common.fee_payer_pk

let fee_payer (t : t) = Account_id.create t.common.fee_payer_pk Token_id.default

let nonce (t : t) = t.common.nonce

let valid_until (t : t) = t.common.valid_until

let memo (t : t) = t.common.memo

let body (t : t) = t.body

let source_pk (t : t) = Body.source_pk t.body

let source (t : t) = Body.source t.body

let receiver_pk (t : t) = Body.receiver_pk t.body

let receiver (t : t) = Body.receiver t.body

let token (t : t) = Body.token t.body

let tag (t : t) = Body.tag t.body

let amount (t : t) =
  match t.body with
  | Payment payload ->
      Some payload.Payment_payload.Poly.amount
  | Stake_delegation _ ->
      None

let fee_excess (t : t) =
  Fee_excess.of_single (fee_token t, Currency.Fee.Signed.of_unsigned (fee t))

let accounts_accessed (t : t) = [ fee_payer t; source t; receiver t ]

let dummy : t =
  { common =
      { fee = Currency.Fee.zero
      ; fee_payer_pk = Public_key.Compressed.empty
      ; nonce = Account_nonce.zero
      ; valid_until = Global_slot.max_value
      ; memo = Memo.dummy
      }
  ; body = Payment Payment_payload.dummy
  }

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%bind common = Common.gen in
  let max_amount =
    Currency.Amount.(sub max_int (of_fee common.fee))
    |> Option.value_exn ?here:None ?error:None ?message:None
  in
  let%map body = Body.gen ~source_pk:common.fee_payer_pk ~max_amount in
  Poly.{ common; body }

(** This module defines a weight for each payload component *)
module Weight = struct
  let payment (_payment_payload : Payment_payload.t) : int = 1

  let stake_delegation (_stake_delegation : Stake_delegation.t) : int = 1

  let of_body : Body.t -> int = function
    | Payment payment_payload ->
        payment payment_payload
    | Stake_delegation stake_delegation_payload ->
        stake_delegation stake_delegation_payload
end

let weight (signed_command_payload : t) : int =
  body signed_command_payload |> Weight.of_body
