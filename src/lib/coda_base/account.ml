open Core
open Import
open Coda_numbers
open Snark_params
open Tick
open Let_syntax
open Currency
open Snark_bits
open Fold_lib
open Module_version

module Index = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving bin_io, sexp, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp]

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

  include (Bits.Vector.Make (Vector) : Bits_intf.S with type t := t)

  let fold_bits = fold

  let fold t = Fold.group3 ~default:false (fold_bits t)

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)
end

module Nonce = Account_nonce

module Poly = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('pk, 'amount, 'nonce, 'receipt_chain_hash, 'bool, 'state_hash) t =
          { public_key: 'pk
          ; balance: 'amount
          ; nonce: 'nonce
          ; receipt_chain_hash: 'receipt_chain_hash
          ; delegate: 'pk
          ; participated: 'bool
          ; voting_for: 'state_hash }
        [@@deriving sexp, bin_io, eq, compare, hash, yojson, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('pk, 'amount, 'nonce, 'receipt_chain_hash, 'bool, 'state_hash) t =
        ( 'pk
        , 'amount
        , 'nonce
        , 'receipt_chain_hash
        , 'bool
        , 'state_hash )
        Stable.Latest.t =
    { public_key: 'pk
    ; balance: 'amount
    ; nonce: 'nonce
    ; receipt_chain_hash: 'receipt_chain_hash
    ; delegate: 'pk
    ; participated: 'bool
    ; voting_for: 'state_hash }
  [@@deriving sexp, eq, compare, hash, yojson]
end

module Stable = struct
  module V1 = struct
    module T = struct
      type key = Public_key.Compressed.Stable.V1.t
      [@@deriving sexp, bin_io, eq, hash, compare, yojson]

      type t =
        ( Public_key.Compressed.Stable.V1.t
        , Balance.Stable.V1.t
        , Nonce.Stable.V1.t
        , Receipt.Chain_hash.Stable.V1.t
        , bool
        , State_hash.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, bin_io, eq, hash, compare, yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)

    let public_key (t : t) : key = t.public_key
  end

  (* module version registration *)

  module Latest = V1

  module Module_decl = struct
    let name = "coda_base_account"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io, version omitted *)
type t = Stable.Latest.t [@@deriving sexp, eq, hash, compare]

[%%define_locally
Stable.Latest.(public_key)]

type key = Stable.Latest.key

type var =
  ( Public_key.Compressed.var
  , Balance.var
  , Nonce.Unpacked.var
  , Receipt.Chain_hash.var
  , Boolean.var
  , State_hash.var )
  Poly.t

type value =
  ( Public_key.Compressed.t
  , Balance.t
  , Nonce.t
  , Receipt.Chain_hash.t
  , bool
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
  ; participated= false
  ; voting_for=
      State_hash.(of_hash zero)
      (* TODO: fix this once the out of scope field element is implemented *)
  }

let typ : (var, value) Typ.t =
  let spec =
    let open Data_spec in
    [ Public_key.Compressed.typ
    ; Balance.typ
    ; Nonce.Unpacked.typ
    ; Receipt.Chain_hash.typ
    ; Public_key.Compressed.typ
    ; Boolean.typ
    ; State_hash.typ ]
  in
  let of_hlist
        : 'a 'b 'c 'd 'e 'f.    ( unit
                                ,    'a
                                  -> 'b
                                  -> 'c
                                  -> 'd
                                  -> 'a
                                  -> 'e
                                  -> 'f
                                  -> unit )
                                H_list.t -> ('a, 'b, 'c, 'd, 'e, 'f) Poly.t =
    let open H_list in
    fun [ public_key
        ; balance
        ; nonce
        ; receipt_chain_hash
        ; delegate
        ; participated
        ; voting_for ] ->
      { public_key
      ; balance
      ; nonce
      ; receipt_chain_hash
      ; delegate
      ; participated
      ; voting_for }
  in
  let to_hlist
      Poly.
        { public_key
        ; balance
        ; nonce
        ; receipt_chain_hash
        ; delegate
        ; participated
        ; voting_for } =
    H_list.
      [ public_key
      ; balance
      ; nonce
      ; receipt_chain_hash
      ; delegate
      ; participated
      ; voting_for ]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_of_t
    ({ public_key
     ; balance
     ; nonce
     ; receipt_chain_hash
     ; delegate
     ; participated
     ; voting_for } :
      value) =
  { Poly.public_key= Public_key.Compressed.var_of_t public_key
  ; balance= Balance.var_of_t balance
  ; nonce= Nonce.Unpacked.var_of_value nonce
  ; receipt_chain_hash= Receipt.Chain_hash.var_of_t receipt_chain_hash
  ; delegate= Public_key.Compressed.var_of_t delegate
  ; participated= Boolean.var_of_value participated
  ; voting_for= State_hash.var_of_t voting_for }

let var_to_triples
    Poly.
      { public_key
      ; balance
      ; nonce
      ; receipt_chain_hash
      ; delegate
      ; participated
      ; voting_for } =
  let%bind public_key = Public_key.Compressed.var_to_triples public_key
  and receipt_chain_hash = Receipt.Chain_hash.var_to_triples receipt_chain_hash
  and delegate = Public_key.Compressed.var_to_triples delegate in
  let balance = Balance.var_to_triples balance in
  let nonce = Nonce.Unpacked.var_to_triples nonce in
  let%map voting_for = State_hash.var_to_triples voting_for in
  public_key @ balance @ nonce @ receipt_chain_hash @ delegate
  @ [(participated, Boolean.false_, Boolean.false_)]
  @ voting_for

let fold
    ({ public_key
     ; balance
     ; nonce
     ; receipt_chain_hash
     ; delegate
     ; participated
     ; voting_for } :
      t) =
  let open Fold in
  Public_key.Compressed.fold public_key
  +> Balance.fold balance +> Nonce.fold nonce
  +> Receipt.Chain_hash.fold receipt_chain_hash
  +> Public_key.Compressed.fold delegate
  +> Fold.return (participated, false, false)
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
    ; participated= false
    ; voting_for=
        State_hash.(of_hash zero)
        (* TODO: Fix this once out of scope field element is implemented *) }

let digest t = Pedersen.State.digest (crypto_hash t)

let create public_key balance =
  Poly.
    { public_key
    ; balance
    ; nonce= Nonce.zero
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; delegate= public_key
    ; participated= false
    ; voting_for=
        State_hash.(of_hash zero)
        (* TODO: Fix this once out of scope field element is implemented *) }

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
