open Core_kernel
open Snark_params.Tick
open Fold_lib
open Module_version
module Account_nonce = Coda_numbers.Account_nonce
module Memo = User_command_memo

module Common = struct
  module Poly = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type ('fee, 'nonce, 'memo) t = {fee: 'fee; nonce: 'nonce; memo: 'memo}
          [@@deriving bin_io, compare, eq, sexp, hash, yojson, version]
        end

        include T
      end

      module Latest = V1
    end

    type ('fee, 'nonce, 'memo) t = ('fee, 'nonce, 'memo) Stable.Latest.t =
      {fee: 'fee; nonce: 'nonce; memo: 'memo}
    [@@deriving eq, sexp, hash, yojson]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          ( Currency.Fee.Stable.V1.t
          , Account_nonce.Stable.V1.t
          , Memo.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving bin_io, compare, eq, sexp, hash, yojson, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "user_command_payload_common"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t [@@deriving eq, sexp, hash, yojson]

  let to_input ({fee; nonce; memo} : t) : _ Random_oracle.Input.t =
    { field_elements= [||]
    ; bitstrings=
        [| Currency.Fee.to_bits fee
         ; Account_nonce.Bits.to_bits nonce
         ; Memo.to_bits memo |] }

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
      let%bind is_digest = Bool.quickcheck_generator in
      if is_digest then
        String.gen_with_length Memo.max_digestible_string_length
          Char.quickcheck_generator
        >>| Memo.create_by_digesting_string_exn
      else
        String.gen_with_length Memo.max_input_length Char.quickcheck_generator
        >>| Memo.create_from_string_exn
    in
    Poly.{fee; nonce; memo}

  type var = (Currency.Fee.var, Account_nonce.Checked.t, Memo.Checked.t) Poly.t

  let to_hlist Poly.{fee; nonce; memo} = H_list.[fee; nonce; memo]

  let of_hlist : type fee nonce memo.
         (unit, fee -> nonce -> memo -> unit) H_list.t
      -> (fee, nonce, memo) Poly.t =
   fun H_list.[fee; nonce; memo] -> {fee; nonce; memo}

  let typ =
    Typ.of_hlistable
      [Currency.Fee.typ; Account_nonce.typ; Memo.typ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  module Checked = struct
    let constant ({fee; nonce; memo} : t) : var =
      { fee= Currency.Fee.var_of_t fee
      ; nonce= Account_nonce.Checked.constant nonce
      ; memo= Memo.Checked.constant memo }

    let to_input ({fee; nonce; memo} : var) =
      let s = Bitstring_lib.Bitstring.Lsb_first.to_list in
      let%map nonce = Account_nonce.Checked.to_bits nonce in
      { Random_oracle.Input.field_elements= [||]
      ; bitstrings=
          [| s (Currency.Fee.var_to_bits fee)
           ; s nonce
           ; Array.to_list (memo :> Boolean.var array) |] }

    let to_triples ({fee; nonce; memo} : var) =
      let%map nonce = Account_nonce.Checked.to_triples nonce in
      Currency.Fee.var_to_triples fee @ nonce @ Memo.Checked.to_triples memo
  end
end

module Body = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          | Payment of Payment_payload.Stable.V1.t
          | Stake_delegation of Stake_delegation.Stable.V1.t
        [@@deriving bin_io, compare, eq, sexp, hash, yojson, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "user_command_payload_body"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t =
    | Payment of Payment_payload.Stable.V1.t
    | Stake_delegation of Stake_delegation.Stable.V1.t
  [@@deriving eq, sexp, hash, yojson]

  let max_variant_size =
    List.reduce_exn ~f:Int.max
      [Payment_payload.length_in_triples; Stake_delegation.length_in_triples]

  module Tag = Transaction_union_tag

  let fold = function
    | Payment p ->
        Fold.(Tag.fold Payment +> Payment_payload.fold p)
    | Stake_delegation d ->
        Fold.(
          Tag.fold Stake_delegation +> Stake_delegation.fold d
          +> Fold.init (max_variant_size - Stake_delegation.length_in_triples)
               ~f:(fun _ -> (false, false, false)))

  let length_in_triples = Tag.length_in_triples + max_variant_size

  let gen ~max_amount =
    let open Quickcheck.Generator in
    map
      (variant2 (Payment_payload.gen ~max_amount) Stake_delegation.gen)
      ~f:(function `A p -> Payment p | `B d -> Stake_delegation d)
end

module Poly = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('common, 'body) t = {common: 'common; body: 'body}
        [@@deriving bin_io, eq, sexp, hash, yojson, compare, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('common, 'body) t = ('common, 'body) Stable.Latest.t =
    {common: 'common; body: 'body}
  [@@deriving eq, sexp, hash, yojson, compare]
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t = (Common.Stable.V1.t, Body.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving bin_io, compare, eq, sexp, hash, yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "user_command_payload"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io omitted *)
type t = Stable.Latest.t [@@deriving eq, sexp, hash, yojson]

let create ~fee ~nonce ~memo ~body : t = {common= {fee; nonce; memo}; body}

let fold ({common; body} : t) = Fold.(Common.fold common +> Body.fold body)

let length_in_triples = Common.length_in_triples + Body.length_in_triples

let fee (t : t) = t.common.fee

let nonce (t : t) = t.common.nonce

let memo (t : t) = t.common.memo

let body (t : t) = t.body

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
      {fee= Currency.Fee.zero; nonce= Account_nonce.zero; memo= Memo.dummy}
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
