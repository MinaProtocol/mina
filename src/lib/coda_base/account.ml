open Core
open Import
open Coda_numbers
open Snark_params
open Tick
open Let_syntax
open Currency
open Snark_bits
open Fold_lib

module Index = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int [@@deriving to_yojson, sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving to_yojson, sexp]

  let to_int = Int.to_int

  let gen = Int.gen_incl 0 ((1 lsl Snark_params.ledger_depth) - 1)

  module Table = Int.Table

  module Vector = struct
    include Int

    let length = Snark_params.ledger_depth

    let empty = zero

    let get t i = (t lsr i) land 1 = 1

    let set v i b = if b then v lor (one lsl i) else v land lnot (one lsl i)
  end

  include (
    Bits.Vector.Make (Vector) : Bits_intf.Convertable_bits with type t := t)

  let fold_bits = fold

  let fold t = Fold.group3 ~default:false (fold_bits t)

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)
end

module Nonce = Account_nonce

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('pk, 'amount, 'nonce, 'receipt_chain_hash, 'state_hash) t =
        { public_key: 'pk
        ; balance: 'amount
        ; nonce: 'nonce
        ; receipt_chain_hash: 'receipt_chain_hash
        ; delegate: 'pk
        ; voting_for: 'state_hash }
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type ('pk, 'amount, 'nonce, 'receipt_chain_hash, 'state_hash) t =
        ( 'pk
        , 'amount
        , 'nonce
        , 'receipt_chain_hash
        , 'state_hash )
        Stable.Latest.t =
    { public_key: 'pk
    ; balance: 'amount
    ; nonce: 'nonce
    ; receipt_chain_hash: 'receipt_chain_hash
    ; delegate: 'pk
    ; voting_for: 'state_hash }
  [@@deriving sexp, eq, compare, hash, yojson]
end

module Key = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Public_key.Compressed.Stable.V1.t
      [@@deriving sexp, eq, hash, compare, yojson]

      let to_latest = Fn.id
    end
  end]
end

type key = Key.Stable.Latest.t [@@deriving sexp, eq, hash, compare, yojson]

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Balance.Stable.V1.t
      , Nonce.Stable.V1.t
      , Receipt.Chain_hash.Stable.V1.t
      , State_hash.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving sexp, eq, hash, compare, yojson]

    let to_latest = Fn.id

    let public_key (t : t) : key = t.public_key
  end
end]

(* bin_io, version omitted *)
type t = Stable.Latest.t [@@deriving sexp, eq, hash, compare]

[%%define_locally
Stable.Latest.(public_key)]

type var =
  ( Public_key.Compressed.var
  , Balance.var
  , Nonce.Checked.t
  , Receipt.Chain_hash.var
  , State_hash.var )
  Poly.t

type value =
  ( Public_key.Compressed.t
  , Balance.t
  , Nonce.t
  , Receipt.Chain_hash.t
  , State_hash.t )
  Poly.t
[@@deriving sexp]

let key_gen = Public_key.Compressed.gen

let initialize public_key : t =
  { public_key
  ; balance= Balance.zero
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate= public_key
  ; voting_for= State_hash.dummy }

let typ : (var, value) Typ.t =
  let spec =
    let open Data_spec in
    [ Public_key.Compressed.typ
    ; Balance.typ
    ; Nonce.typ
    ; Receipt.Chain_hash.typ
    ; Public_key.Compressed.typ
    ; State_hash.typ ]
  in
  let of_hlist
        : 'a 'b 'c 'd 'e.    ( unit
                             , 'a -> 'b -> 'c -> 'd -> 'a -> 'e -> unit )
                             H_list.t -> ('a, 'b, 'c, 'd, 'e) Poly.t =
    let open H_list in
    fun [public_key; balance; nonce; receipt_chain_hash; delegate; voting_for] ->
      {public_key; balance; nonce; receipt_chain_hash; delegate; voting_for}
  in
  let to_hlist
      Poly.
        {public_key; balance; nonce; receipt_chain_hash; delegate; voting_for}
      =
    H_list.
      [public_key; balance; nonce; receipt_chain_hash; delegate; voting_for]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_of_t
    ({public_key; balance; nonce; receipt_chain_hash; delegate; voting_for} :
      value) =
  { Poly.public_key= Public_key.Compressed.var_of_t public_key
  ; balance= Balance.var_of_t balance
  ; nonce= Nonce.Checked.constant nonce
  ; receipt_chain_hash= Receipt.Chain_hash.var_of_t receipt_chain_hash
  ; delegate= Public_key.Compressed.var_of_t delegate
  ; voting_for= State_hash.var_of_t voting_for }

let var_to_triples
    Poly.{public_key; balance; nonce; receipt_chain_hash; delegate; voting_for}
    =
  let%map public_key = Public_key.Compressed.var_to_triples public_key
  and voting_for = State_hash.var_to_triples voting_for
  and receipt_chain_hash = Receipt.Chain_hash.var_to_triples receipt_chain_hash
  and delegate = Public_key.Compressed.var_to_triples delegate
  and nonce = Nonce.Checked.to_triples nonce in
  let balance = Balance.var_to_triples balance in
  public_key @ balance @ nonce @ receipt_chain_hash @ delegate @ voting_for

let fold
    ({public_key; balance; nonce; receipt_chain_hash; delegate; voting_for} :
      t) =
  let open Fold in
  Public_key.Compressed.fold public_key
  +> Balance.fold balance +> Nonce.fold nonce
  +> Receipt.Chain_hash.fold receipt_chain_hash
  +> Public_key.Compressed.fold delegate
  +> State_hash.fold voting_for

let crypto_hash_prefix = Hash_prefix.account

let crypto_hash t = Pedersen.hash_fold crypto_hash_prefix (fold t)

let empty =
  Poly.
    { public_key= Public_key.Compressed.empty
    ; balance= Balance.zero
    ; nonce= Nonce.zero
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; delegate= Public_key.Compressed.empty
    ; voting_for= State_hash.dummy }

let digest t = Pedersen.State.digest (crypto_hash t)

let create public_key balance =
  Poly.
    { public_key
    ; balance
    ; nonce= Nonce.zero
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; delegate= public_key
    ; voting_for= State_hash.dummy }

let gen =
  let open Quickcheck.Let_syntax in
  let%bind public_key = Public_key.Compressed.gen in
  let%bind balance = Currency.Balance.gen in
  return (create public_key balance)

module Checked = struct
  let hash t =
    var_to_triples t >>= Pedersen.Checked.hash_triples ~init:crypto_hash_prefix

  let digest t =
    var_to_triples t
    >>= Pedersen.Checked.digest_triples ~init:crypto_hash_prefix
end
