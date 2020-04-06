(* user_command_payload.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
module Coda_numbers = Coda_numbers

[%%else]

module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers
module Currency = Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module Memo = User_command_memo
module Account_nonce = Coda_numbers.Account_nonce
module Global_slot = Coda_numbers.Global_slot

module Common = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('fee, 'nonce, 'global_slot, 'memo) t =
          {fee: 'fee; nonce: 'nonce; valid_until: 'global_slot; memo: 'memo}
        [@@deriving compare, eq, sexp, hash, yojson]
      end
    end]

    type ('fee, 'nonce, 'global_slot, 'memo) t =
          ('fee, 'nonce, 'global_slot, 'memo) Stable.Latest.t =
      {fee: 'fee; nonce: 'nonce; valid_until: 'global_slot; memo: 'memo}
    [@@deriving eq, sexp, hash, yojson]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Currency.Fee.Stable.V1.t
        , Account_nonce.Stable.V1.t
        , Global_slot.Stable.V1.t
        , Memo.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving compare, eq, sexp, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving compare, eq, sexp, hash, yojson]

  let to_input ({fee; nonce; valid_until; memo} : t) =
    Random_oracle.Input.bitstrings
      [| Currency.Fee.to_bits fee
       ; Account_nonce.Bits.to_bits nonce
       ; Global_slot.to_bits valid_until
       ; Memo.to_bits memo |]

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map fee = Currency.Fee.gen
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
    Poly.{fee; nonce; valid_until; memo}

  [%%ifdef
  consensus_mechanism]

  type var =
    ( Currency.Fee.var
    , Account_nonce.Checked.t
    , Global_slot.Checked.t
    , Memo.Checked.t )
    Poly.t

  let to_hlist Poly.{fee; nonce; valid_until; memo} =
    H_list.[fee; nonce; valid_until; memo]

  let of_hlist : type fee nonce memo global_slot.
         (unit, fee -> nonce -> global_slot -> memo -> unit) H_list.t
      -> (fee, nonce, global_slot, memo) Poly.t =
   fun H_list.[fee; nonce; valid_until; memo] -> {fee; nonce; valid_until; memo}

  let typ =
    Typ.of_hlistable
      [Currency.Fee.typ; Account_nonce.typ; Global_slot.typ; Memo.typ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  module Checked = struct
    let constant ({fee; nonce; valid_until; memo} : t) : var =
      { fee= Currency.Fee.var_of_t fee
      ; nonce= Account_nonce.Checked.constant nonce
      ; memo= Memo.Checked.constant memo
      ; valid_until= Global_slot.Checked.constant valid_until }

    let to_input ({fee; nonce; valid_until; memo} : var) =
      let s = Bitstring_lib.Bitstring.Lsb_first.to_list in
      let%map nonce = Account_nonce.Checked.to_bits nonce
      and valid_until = Global_slot.Checked.to_bits valid_until in
      Random_oracle.Input.bitstrings
        [| s (Currency.Fee.var_to_bits fee)
         ; s nonce
         ; s valid_until
         ; Array.to_list (memo :> Boolean.var array) |]
  end

  [%%endif]
end

module Body = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Payment of Payment_payload.Stable.V1.t
        | Stake_delegation of Stake_delegation.Stable.V1.t
      [@@deriving compare, eq, sexp, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    | Payment of Payment_payload.t
    | Stake_delegation of Stake_delegation.t
  [@@deriving eq, sexp, hash, yojson]

  module Tag = Transaction_union_tag

  let gen ~max_amount =
    let open Quickcheck.Generator in
    map
      (variant2 (Payment_payload.gen ~max_amount) Stake_delegation.gen)
      ~f:(function `A p -> Payment p | `B d -> Stake_delegation d)
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('common, 'body) t = {common: 'common; body: 'body}
      [@@deriving eq, sexp, hash, yojson, compare]
    end
  end]

  type ('common, 'body) t = ('common, 'body) Stable.Latest.t =
    {common: 'common; body: 'body}
  [@@deriving eq, sexp, hash, yojson, compare]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = (Common.Stable.V1.t, Body.Stable.V1.t) Poly.Stable.V1.t
    [@@deriving compare, eq, sexp, hash, yojson]

    let to_latest = Fn.id
  end
end]

(* bin_io omitted *)
type t = Stable.Latest.t [@@deriving compare, eq, sexp, hash, yojson]

let create ~fee ~nonce ~valid_until ~memo ~body : t =
  {common= {fee; nonce; valid_until; memo}; body}

let fee (t : t) = t.common.fee

let nonce (t : t) = t.common.nonce

let valid_until (t : t) = t.common.valid_until

let memo (t : t) = t.common.memo

let body (t : t) = t.body

let receiver (t : t) =
  match t.body with
  | Payment payload ->
      payload.Payment_payload.Poly.receiver
  | Stake_delegation payload ->
      Stake_delegation.receiver payload

let amount (t : t) =
  match t.body with
  | Payment payload ->
      Some payload.Payment_payload.Poly.amount
  | Stake_delegation _ ->
      None

let is_payment (t : t) =
  match t.body with Payment _ -> true | Stake_delegation _ -> false

let accounts_accessed (t : t) =
  match t.body with
  | Payment payload ->
      [payload.receiver]
  | Stake_delegation _ ->
      []

let dummy : t =
  { common=
      { fee= Currency.Fee.zero
      ; nonce= Account_nonce.zero
      ; valid_until= Global_slot.max_value
      ; memo= Memo.dummy }
  ; body= Payment Payment_payload.dummy }

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%bind common = Common.gen in
  let max_amount =
    Currency.Amount.(sub max_int (of_fee common.fee))
    |> Option.value_exn ?here:None ?error:None ?message:None
  in
  let%map body = Body.gen ~max_amount in
  Poly.{common; body}
