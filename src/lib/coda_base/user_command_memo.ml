open Core
open Crypto_params

module Stable = struct
  module V1 = struct
    module T = struct
      open Base58_check

      type t = string
      [@@deriving bin_io, sexp, eq, compare, hash, version {unnumbered}]

      let version_byte = Version_bytes.user_command_memo

      let to_string (memo : t) : string = encode ~version_byte ~payload:memo

      let of_string (s : string) : t = decode_exn ~version_byte s
    end

    include T
    include Codable.Make_of_string (T)
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash]

[%%define_locally
Stable.Latest.(to_yojson, of_yojson, to_string, of_string)]

exception Invalid_user_memo_length

exception Too_long_digestible_string

let max_digestible_string_length = 1000

[%%define_locally
Random_oracle.Digest.(length_in_bytes, length_in_triples)]

let create_by_digesting_string_exn s =
  if Int.(String.length s > max_digestible_string_length) then
    raise Too_long_digestible_string ;
  (Random_oracle.digest_string s :> t)

let create_from_bytes32_exn bytes : t =
  if not (Int.equal (Bytes.length bytes) length_in_bytes) then
    raise Invalid_user_memo_length ;
  Bytes.to_string bytes

let create_from_string32_exn s : t =
  if not (Int.equal (String.length s) length_in_bytes) then
    raise Invalid_user_memo_length ;
  s

let dummy = (create_by_digesting_string_exn "" :> t)

module Boolean = Tick0.Boolean
module Typ = Tick0.Typ

(* the code below is much the same as in Random_oracle.Digest
   we can't just use the values there, because Random_oracle.Digest.t is private;
   we could reverse the dependency by having Random_oracle.Digest use this
   code, but that seems fragile
 *)

module Checked = struct
  type unchecked = t

  type t = Boolean.var array

  let to_triples t =
    Fold_lib.Fold.(to_list (group3 ~default:Boolean.false_ (of_array t)))

  let constant unchecked =
    assert (Int.(String.length (unchecked :> string) = length_in_bytes)) ;
    Array.map
      (Blake2.string_to_bits (unchecked :> string))
      ~f:Boolean.var_of_value
end

let fold_bits t =
  { Fold_lib.Fold.fold=
      (fun ~init ~f ->
        let n = 8 * String.length t in
        let rec go acc i =
          if i = n then acc
          else
            let b = (Char.to_int t.[i / 8] lsr (i mod 8)) land 1 = 1 in
            go (f acc b) (i + 1)
        in
        go init 0 ) }

let fold t = Fold_lib.Fold.group3 ~default:false (fold_bits t)

let typ : (Checked.t, t) Typ.t =
  Typ.transport
    (Typ.array ~length:Blake2.digest_size_in_bits Boolean.typ)
    ~there:(fun (t : t) -> Blake2.string_to_bits (t :> string))
    ~back:(fun bs -> of_string (Blake2.bits_to_string bs))
