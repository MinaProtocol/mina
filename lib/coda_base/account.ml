open Core
open Coda_numbers
open Snark_params
open Tick
open Let_syntax
open Currency
open Snark_bits
open Fold_lib

module Compressed_public_key = Signature_lib.Public_key.Compressed
module Receipt_chain_hash = Receipt_chain_hash

module Index = struct
  type t = int [@@deriving bin_io]

  module Vector = struct
    include Int

    let length = Snark_params.ledger_depth

    let empty = zero

    let get t i = (t lsr i) land 1 = 1

    let set v i b = if b then v lor (one lsl i) else v land lnot (one lsl i)
  end

  let to_int = Fn.id
  let of_int = Fn.id

  include (Bits.Vector.Make (Vector) : Bits_intf.S with type t := t)

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)
end

module Nonce = Account_nonce

module Stable = struct
  module V1 = struct
    type ('pk, 'amount, 'nonce, 'receipt_chain_hash) t_ =
      { public_key: 'pk
      ; balance: 'amount
      ; nonce: 'nonce
      ; receipt_chain_hash: 'receipt_chain_hash }
    [@@deriving fields, sexp, bin_io, eq]

    type t =
      ( Compressed_public_key.Stable.V1.t
      , Balance.Stable.V1.t
      , Nonce.Stable.V1.t
      , Receipt_chain_hash.Stable.V1.t )
      t_
    [@@deriving sexp, bin_io, eq]
  end
end

include Stable.V1

let create ~public_key ~balance ~nonce ~receipt_chain_hash =
  {public_key; balance; nonce; receipt_chain_hash}

type var =
  ( Compressed_public_key.var
  , Balance.var
  , Nonce.Unpacked.var
  , Receipt_chain_hash.var )
  t_

let create_var = create

let var_public_key = public_key
let var_balance = balance
let var_nonce = nonce
let var_receipt_chain_hash = receipt_chain_hash

type value =
  (Compressed_public_key.t, Balance.t, Nonce.t, Receipt_chain_hash.t) t_
[@@deriving sexp]

let initialize public_key : t =
  { public_key
  ; balance= Balance.zero
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt_chain_hash.empty }

let empty_hash =
  Pedersen.digest_fold
    (Pedersen.State.create Pedersen.params)
    (Fold_lib.Fold.string_triples "nothing up my sleeve")

let typ : (var, value) Typ.t =
  let spec =
    let open Data_spec in
    [ Compressed_public_key.typ
    ; Balance.typ
    ; Nonce.Unpacked.typ
    ; Receipt_chain_hash.typ ]
  in
  let of_hlist
        : 'a 'b 'c 'd.    (unit, 'a -> 'b -> 'c -> 'd -> unit) H_list.t
          -> ('a, 'b, 'c, 'd) t_ =
    let open H_list in
    fun [public_key; balance; nonce; receipt_chain_hash] ->
      {public_key; balance; nonce; receipt_chain_hash}
  in
  let to_hlist {public_key; balance; nonce; receipt_chain_hash} =
    H_list.[public_key; balance; nonce; receipt_chain_hash]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_of_t ({public_key; balance; nonce; receipt_chain_hash}: value) =
  { public_key= Compressed_public_key.var_of_t public_key
  ; balance= Balance.var_of_t balance
  ; nonce= Nonce.Unpacked.var_of_value nonce
  ; receipt_chain_hash= Receipt_chain_hash.var_of_t receipt_chain_hash }

let var_to_triples {public_key; balance; nonce; receipt_chain_hash} =
  let%map public_key = Compressed_public_key.var_to_triples public_key
  and receipt_chain_hash =
    Receipt_chain_hash.var_to_triples receipt_chain_hash
  in
  let balance = Balance.var_to_triples balance in
  let nonce = Nonce.Unpacked.var_to_triples nonce in
  public_key @ balance @ nonce @ receipt_chain_hash

let fold_bits ({public_key; balance; nonce; receipt_chain_hash}: t) =
  let open Fold in
  Compressed_public_key.fold public_key
  +> Balance.fold balance +> Nonce.fold nonce
  +> Receipt_chain_hash.fold receipt_chain_hash

let hash_prefix = Hash_prefix.account

let hash t = Pedersen.hash_fold hash_prefix (fold_bits t)

let empty =
  { public_key= Compressed_public_key.empty
  ; balance= Balance.zero
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt_chain_hash.empty }

let digest t = Pedersen.State.digest (hash t)

let empty_hash = digest empty

module Checked = struct
  let hash t =
    var_to_triples t >>= Pedersen.Checked.hash_triples ~init:hash_prefix

  let digest t =
    var_to_triples t >>= Pedersen.Checked.digest_triples ~init:hash_prefix
end
