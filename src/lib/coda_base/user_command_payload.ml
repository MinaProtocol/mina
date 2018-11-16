open Core_kernel
open Snark_params.Tick
open Fold_lib
module Account_nonce = Coda_numbers.Account_nonce
module Memo = User_command_memo

module Common = struct
  module Stable = struct
    module V1 = struct
      type ('fee, 'nonce, 'memo) t_ = {fee: 'fee; nonce: 'nonce; memo: 'memo}
      [@@deriving bin_io, eq, sexp, hash, yojson]

      type t = (Currency.Fee.Stable.V1.t, Account_nonce.t, Memo.t) t_
      [@@deriving bin_io, eq, sexp, hash, yojson]
    end
  end

  include Stable.V1

  let fold ({fee; nonce; memo} : t) =
    Fold.(Currency.Fee.fold fee +> Account_nonce.fold nonce +> Memo.fold memo)

  let length_in_triples =
    Currency.Fee.length_in_triples + Account_nonce.length_in_triples
    + Memo.length_in_triples

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map fee = Currency.Fee.gen
    and nonce = Account_nonce.gen
    and memo =
      String.gen_with_length Memo.max_size_in_bytes Char.gen
      >>| Memo.create_exn
    in
    {fee; nonce; memo}

  type var = (Currency.Fee.var, Account_nonce.Unpacked.var, Memo.var) t_

  let to_hlist {fee; nonce; memo} = H_list.[fee; nonce; memo]

  let of_hlist : type fee nonce memo.
      (unit, fee -> nonce -> memo -> unit) H_list.t -> (fee, nonce, memo) t_ =
   fun H_list.([fee; nonce; memo]) -> {fee; nonce; memo}

  let typ =
    Typ.of_hlistable
      [Currency.Fee.typ; Account_nonce.Unpacked.typ; Memo.typ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  module Checked = struct
    let constant ({fee; nonce; memo} : t) : var =
      { fee= Currency.Fee.var_of_t fee
      ; nonce= Account_nonce.Unpacked.var_of_value nonce
      ; memo= Memo.var_of_t memo }

    let to_triples ({fee; nonce; memo} : var) =
      Currency.Fee.var_to_triples fee
      @ Account_nonce.Unpacked.var_to_triples nonce
      @ Memo.var_to_triples memo
  end
end

module Body = struct
  module Stable = struct
    module V1 = struct
      type t = Payment of Payment_payload.Stable.V1.t
      [@@deriving bin_io, eq, sexp, hash, yojson]
    end
  end

  include Stable.V1

  let fold = function Payment p -> Payment_payload.fold p

  let sender_cost = function Payment {amount; _} -> amount

  let length_in_triples = Payment_payload.length_in_triples

  type var = Payment_payload.var

  let gen = Quickcheck.Generator.map Payment_payload.gen ~f:(fun p -> Payment p)

  let typ : (var, t) Typ.t =
    Typ.transport Payment_payload.typ
      ~there:(function Payment p -> p)
      ~back:(fun p -> Payment p)

  module Checked = struct
    let constant (t : t) : var =
      match t with Payment p -> Payment_payload.var_of_t p

    let to_triples (p : var) = Payment_payload.var_to_triples p
  end
end

module Stable = struct
  module V1 = struct
    type ('common, 'body) t_ = {common: 'common; body: 'body}
    [@@deriving bin_io, eq, sexp, hash, yojson]

    type t = (Common.Stable.V1.t, Body.Stable.V1.t) t_
    [@@deriving bin_io, eq, sexp, hash, yojson]
  end
end

include Stable.V1

let create ~fee ~nonce ~memo ~body : t = {common= {fee; nonce; memo}; body}

let fold ({common; body} : t) = Fold.(Common.fold common +> Body.fold body)

let length_in_triples = Common.length_in_triples + Body.length_in_triples

type var = (Common.var, Body.var) t_

let to_hlist {common; body} = H_list.[common; body]

let of_hlist : type c v. (unit, c -> v -> unit) H_list.t -> (c, v) t_ =
 fun H_list.([common; body]) -> {common; body}

let typ : (var, t) Typ.t =
  Typ.of_hlistable [Common.typ; Body.typ] ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let fee (t : t) = t.common.fee

let nonce (t : t) = t.common.nonce

let memo (t : t) = t.common.memo

let body (t : t) = t.body

let sender_cost ({common; body} : t) =
  match Currency.Amount.add_fee (Body.sender_cost body) common.fee with
  | None -> Or_error.errorf "%s: overflow" __LOC__
  | Some t -> Ok t

let accounts_accessed (t : t) =
  match t.body with Payment payload -> [payload.receiver]

module Checked = struct
  let to_triples ({common; body} : var) =
    let open Let_syntax in
    let%map body = Body.Checked.to_triples body in
    Common.Checked.to_triples common @ body

  let constant {common; body} =
    {common= Common.Checked.constant common; body= Body.Checked.constant body}

  let fee ({common; _} : var) = common.fee

  let nonce ({common; _} : var) = common.nonce

  let payment_payload (t : var) : Payment_payload.var = t.body
end

let dummy : t =
  { common=
      {fee= Currency.Fee.zero; nonce= Account_nonce.zero; memo= Memo.dummy}
  ; body= Payment Payment_payload.dummy }

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%map common = Common.gen and body = Body.gen in
  {common; body}
