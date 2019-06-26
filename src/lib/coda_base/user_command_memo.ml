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

exception Too_long_user_memo_length

exception Too_long_digestible_string

let max_digestible_string_length = 1000

(* 0th byte is a tag to distinguish digests from other data
   1st byte is length, always 32 for digests
   bytes 2 to 33 are data, 0-right-padded if length is less than 32
 *)

let digest_tag = '\x00'

let bytes_tag = '\x01'

let tag_index = 0

let length_index = 1

let digest_length = Random_oracle.Digest.length_in_bytes

let digest_length_byte = Char.of_int_exn digest_length

let tag (memo : t) = memo.[tag_index]

let length memo = Char.to_int memo.[length_index]

let is_digest memo = Char.equal (tag memo) digest_tag

let is_valid memo =
  Int.equal (String.length memo) (digest_length + 2)
  &&
  let memo_len = length memo in
  if is_digest memo then Int.equal memo_len digest_length
  else
    Char.equal (tag memo) bytes_tag
    && Int.(memo_len <= digest_length)
    &&
    let padded =
      String.sub memo ~pos:(memo_len + 2) ~len:(digest_length - memo_len)
    in
    String.for_all padded ~f:(Char.equal '\x00')

let create_by_digesting_string_exn s =
  if Int.(String.length s > max_digestible_string_length) then
    raise Too_long_digestible_string ;
  let digest = (Random_oracle.digest_string s :> t) in
  String.init (digest_length + 2) ~f:(fun ndx ->
      if Int.equal ndx tag_index then digest_tag
      else if Int.equal ndx length_index then digest_length_byte
      else digest.[ndx - 2] )

let create_by_digesting_string (s : string) =
  try Ok (create_by_digesting_string_exn s)
  with Too_long_digestible_string ->
    Or_error.error_string "create_by_digesting_string: string too long"

module type Memoable = sig
  type t

  val length : t -> int

  val get : t -> int -> char
end

let create_from_value_exn (type t) (module M : Memoable with type t = t)
    (value : t) =
  let len = M.length value in
  if not Int.(len <= digest_length) then raise Too_long_user_memo_length ;
  String.init (digest_length + 2) ~f:(fun ndx ->
      if Int.equal ndx tag_index then bytes_tag
      else if Int.equal ndx length_index then Char.of_int_exn len
      else if Int.(ndx <= len + 2) then M.get value (ndx - 2)
      else '\x00' )

let create_from_bytes_exn bytes = create_from_value_exn (module Bytes) bytes

let create_from_bytes bytes =
  try Ok (create_from_bytes_exn bytes)
  with Too_long_user_memo_length ->
    Or_error.error_string
      (sprintf "create_from_bytes: length exceeds %d" digest_length)

let create_from_string_exn s = create_from_value_exn (module String) s

let create_from_string s =
  try Ok (create_from_string_exn s)
  with Too_long_user_memo_length ->
    Or_error.error_string
      (sprintf "create_from_string: length exceeds %d" digest_length)

let dummy = (create_by_digesting_string_exn "" :> t)

module Boolean = Tick0.Boolean
module Typ = Tick0.Typ

(* the code below is much the same as in Random_oracle.Digest; tag and length bytes 
   make it a little different
 *)

module Checked = struct
  type unchecked = t

  type t = Boolean.var array

  let to_triples t =
    Fold_lib.Fold.(to_list (group3 ~default:Boolean.false_ (of_array t)))

  let constant unchecked =
    assert (Int.(String.length (unchecked :> string) = digest_length + 2)) ;
    Array.map
      (Blake2.string_to_bits (unchecked :> string))
      ~f:Boolean.var_of_value
end

let length_in_bits = 8 * digest_length

let length_in_triples = (length_in_bits + 2) / 3

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
