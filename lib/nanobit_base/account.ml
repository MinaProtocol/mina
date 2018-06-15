open Core
open Snark_params
open Tick
open Let_syntax
open Currency

module Index = struct
  type t = int [@@deriving bin_io]

  module Vector = struct
    include Int

    let length = Snark_params.ledger_depth

    let empty = zero

    let get t i = (t lsr i) land 1 = 1

    let set v i b = if b then v lor (one lsl i) else v land lnot (one lsl i)
  end

  include (Bits.Vector.Make (Vector) : Bits_intf.S with type t := t)

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)
end

module Nonce = Nonce.Make32 ()

module Stable = struct
  module V1 = struct
    type ('pk, 'amount, 'nonce) t_ =
      {public_key: 'pk; balance: 'amount; nonce: 'nonce}
    [@@deriving fields, sexp, bin_io, eq]

    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Balance.Stable.V1.t
      , Nonce.Stable.V1.t )
      t_
    [@@deriving sexp, bin_io, eq]
  end
end

include Stable.V1

type var = (Public_key.Compressed.var, Balance.var, Nonce.Unpacked.var) t_

type value = (Public_key.Compressed.t, Balance.t, Nonce.t) t_ [@@deriving sexp]

let empty_hash =
  Pedersen.hash_bigstring (Bigstring.of_string "nothing up my sleeve")

let typ : (var, value) Typ.t =
  let spec =
    Data_spec.[Public_key.Compressed.typ; Balance.typ; Nonce.Unpacked.typ]
  in
  let of_hlist
        : 'a 'b 'c. (unit, 'a -> 'b -> 'c -> unit) H_list.t -> ('a, 'b, 'c) t_ =
    H_list.(fun [public_key; balance; nonce] -> {public_key; balance; nonce})
  in
  let to_hlist {public_key; balance; nonce} =
    H_list.[public_key; balance; nonce]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_to_bits {public_key; balance; nonce} =
  let%map public_key = Public_key.Compressed.var_to_bits public_key in
  let balance = (Balance.var_to_bits balance :> Boolean.var list) in
  let nonce = Nonce.Unpacked.var_to_bits nonce in
  public_key @ balance @ nonce

let fold_bits ({public_key; balance; nonce}: t) ~init ~f =
  let init = Public_key.Compressed.fold public_key ~init ~f in
  let init = Balance.fold balance ~init ~f in
  Nonce.Bits.fold nonce ~init ~f

let hash_prefix = Hash_prefix.account

let hash t = Pedersen.hash_fold hash_prefix (fold_bits t)

let digest t = Pedersen.State.digest (hash t)

module Checked = struct
  let hash t = var_to_bits t >>= hash_bits ~init:hash_prefix

  let digest t = var_to_bits t >>= digest_bits ~init:hash_prefix
end
