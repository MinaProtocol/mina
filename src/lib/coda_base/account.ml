open Core
open Import
open Coda_numbers
open Snark_params
open Tick
open Currency
open Snark_bits
open Fold_lib
open Module_version

module Index = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving bin_io, to_yojson, sexp, version]
      end

      include T
    end

    module Latest = V1
  end

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
        type ('pk, 'amount, 'nonce, 'receipt_chain_hash, 'state_hash) t =
          { public_key: 'pk
          ; balance: 'amount
          ; nonce: 'nonce
          ; receipt_chain_hash: 'receipt_chain_hash
          ; delegate: 'pk
          ; voting_for: 'state_hash }
        [@@deriving sexp, bin_io, eq, compare, hash, yojson, version, fields]
      end

      include T
    end

    module Latest = V1
  end

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
  [@@deriving sexp, eq, compare, hash, yojson, fields]
end

module Stable = struct
  module V1 = struct
    module T = struct
      type key = Public_key.Compressed.Stable.V1.t
      [@@deriving sexp, bin_io, eq, hash, compare, yojson]

      (* TODO: With the new hash function, it would actually might better to represent the public key
         uncompressed inside the SNARK *)
      type t =
        ( Public_key.Compressed.Stable.V1.t
        , Balance.Stable.V1.t
        , Nonce.Stable.V1.t
        , Receipt.Chain_hash.Stable.V1.t
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

type key = Stable.Latest.key [@@deriving sexp, eq, hash, compare, yojson]

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
  ; voting_for= State_hash.of_hash Outside_pedersen_image.t }

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

let to_input (t : t) =
  let open Random_oracle.Input in
  let f mk acc field = mk (Core.Field.get field t) :: acc in
  let bits conv = f (Fn.compose bitstring conv) in
  Poly.Fields.fold ~init:[]
    ~public_key:(f Public_key.Compressed.to_input)
    ~balance:(bits Balance.to_bits) ~nonce:(bits Nonce.Bits.to_bits)
    ~receipt_chain_hash:(f Receipt.Chain_hash.to_input)
    ~delegate:(f Public_key.Compressed.to_input)
    ~voting_for:(f State_hash.to_input)
  |> List.reduce_exn ~f:append

let crypto_hash_prefix = Hash_prefix.Random_oracle.account

let digest t =
  Random_oracle.(hash ~init:crypto_hash_prefix (pack_input (to_input t)))

let empty =
  Poly.
    { public_key= Public_key.Compressed.empty
    ; balance= Balance.zero
    ; nonce= Nonce.zero
    ; receipt_chain_hash= Receipt.Chain_hash.empty
    ; delegate= Public_key.Compressed.empty
    ; voting_for= State_hash.of_hash Outside_pedersen_image.t }

let create public_key balance =
  { Poly.public_key
  ; balance
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate= public_key
  ; voting_for= State_hash.of_hash Outside_pedersen_image.t }

let gen =
  let open Quickcheck.Let_syntax in
  let%bind public_key = Public_key.Compressed.gen in
  let%bind balance = Currency.Balance.gen in
  return (create public_key balance)

module Checked = struct
  let to_input (t : var) =
    let ( ! ) f x = Run.run_checked (f x) in
    let f mk acc field = mk (Core.Field.get field t) :: acc in
    let open Random_oracle.Input in
    let bits conv =
      f (fun x ->
          bitstring (Bitstring_lib.Bitstring.Lsb_first.to_list (conv x)) )
    in
    List.reduce_exn ~f:append
      (Poly.Fields.fold ~init:[]
         ~public_key:(f Public_key.Compressed.Checked.to_input)
         ~balance:(bits Balance.var_to_bits)
         ~nonce:(bits !Nonce.Checked.to_bits)
         ~receipt_chain_hash:(f Receipt.Chain_hash.var_to_input)
         ~delegate:(f Public_key.Compressed.Checked.to_input)
         ~voting_for:(f State_hash.var_to_input))

  let digest t =
    make_checked (fun () ->
        Random_oracle.Checked.(
          hash ~init:crypto_hash_prefix (pack_input (to_input t))) )

  let to_input t = make_checked (fun () -> to_input t)
end
