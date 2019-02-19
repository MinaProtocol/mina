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
  include Int

  let gen = Int.gen_incl 0 ((1 lsl Snark_params.ledger_depth) - 1)

  module Vector = struct
    include Int

    let length = Snark_params.ledger_depth

    let empty = zero

    let get t i = (t lsr i) land 1 = 1

    let set v i b = if b then v lor (one lsl i) else v land lnot (one lsl i)
  end

  include (Bits.Vector.Make (Vector) : Bits_intf.S with type t := t)

  let fold_bits = fold

  let fold t = Fold.group3 ~default:false (fold_bits t)

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)
end

module Nonce = Account_nonce

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      type ('pk, 'amount, 'nonce, 'receipt_chain_hash) t_ =
        { public_key: 'pk
        ; balance: 'amount
        ; nonce: 'nonce
        ; receipt_chain_hash: 'receipt_chain_hash
        ; delegate: 'pk }
      [@@deriving fields, sexp, bin_io, eq, compare, hash]

      type key = Public_key.Compressed.Stable.V1.t
      [@@deriving sexp, bin_io, eq, hash, compare]

      type t =
        ( key
        , Balance.Stable.V1.t
        , Nonce.Stable.V1.t
        , Receipt.Chain_hash.Stable.V1.t )
        t_
      [@@deriving sexp, bin_io, eq, hash, compare]
    end

    include T
    include Module_version.Registration.Make_latest_version (T)

    (* monomorphize field selector *)
    let public_key (t : t) : key = t.public_key
  end

  (* module version registration *)

  module Latest = V1

  module Module_decl = struct
    let name = "coda_base_account"

    type latest = Latest.t
  end

  module Registrar = Module_version.Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

include Stable.Latest

type var =
  ( Public_key.Compressed.var
  , Balance.var
  , Nonce.Unpacked.var
  , Receipt.Chain_hash.var )
  t_

type value =
  (Public_key.Compressed.t, Balance.t, Nonce.t, Receipt.Chain_hash.t) t_
[@@deriving sexp]

let key_gen = Public_key.Compressed.gen

let initialize public_key : t =
  { public_key
  ; balance= Balance.zero
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate= public_key }

let typ : (var, value) Typ.t =
  let spec =
    let open Data_spec in
    [ Public_key.Compressed.typ
    ; Balance.typ
    ; Nonce.Unpacked.typ
    ; Receipt.Chain_hash.typ
    ; Public_key.Compressed.typ ]
  in
  let of_hlist
        : 'a 'b 'c 'd.    (unit, 'a -> 'b -> 'c -> 'd -> 'a -> unit) H_list.t
          -> ('a, 'b, 'c, 'd) t_ =
    let open H_list in
    fun [public_key; balance; nonce; receipt_chain_hash; delegate] ->
      {public_key; balance; nonce; receipt_chain_hash; delegate}
  in
  let to_hlist {public_key; balance; nonce; receipt_chain_hash; delegate} =
    H_list.[public_key; balance; nonce; receipt_chain_hash; delegate]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_of_t
    ({public_key; balance; nonce; receipt_chain_hash; delegate} : value) =
  { public_key= Public_key.Compressed.var_of_t public_key
  ; balance= Balance.var_of_t balance
  ; nonce= Nonce.Unpacked.var_of_value nonce
  ; receipt_chain_hash= Receipt.Chain_hash.var_of_t receipt_chain_hash
  ; delegate= Public_key.Compressed.var_of_t delegate }

let var_to_triples {public_key; balance; nonce; receipt_chain_hash; delegate} =
  let%map public_key = Public_key.Compressed.var_to_triples public_key
  and receipt_chain_hash = Receipt.Chain_hash.var_to_triples receipt_chain_hash
  and delegate = Public_key.Compressed.var_to_triples delegate in
  let balance = Balance.var_to_triples balance in
  let nonce = Nonce.Unpacked.var_to_triples nonce in
  public_key @ balance @ nonce @ receipt_chain_hash @ delegate

let fold_bits ({public_key; balance; nonce; receipt_chain_hash; delegate} : t)
    =
  let open Fold in
  Public_key.Compressed.fold public_key
  +> Balance.fold balance +> Nonce.fold nonce
  +> Receipt.Chain_hash.fold receipt_chain_hash
  +> Public_key.Compressed.fold delegate

let crypto_hash_prefix = Hash_prefix.account

let crypto_hash t = Pedersen.hash_fold crypto_hash_prefix (fold_bits t)

let empty =
  { public_key= Public_key.Compressed.empty
  ; balance= Balance.zero
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate= Public_key.Compressed.empty }

let digest t = Pedersen.State.digest (crypto_hash t)

let create public_key balance =
  { public_key
  ; balance
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate= public_key }

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
