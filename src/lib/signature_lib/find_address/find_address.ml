(** This tool is designed to find public keys with some fixed prefix.

    The prefix to search for can be found as the first positional argument to
    this command. If none is given, the default value used is
    zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz

    Usage: dune exec src/lib/find_address/find_address.exe [PREFIX_STRING].

    The output of the tool is a list of all public keys whose base58-check
    representation contains the given prefix (after the initial, fixed 'version
    byte').

    ## Finding a private key for a public key generated with this tool

    A Mina private key is an element of the Pallas scalar field.

    A private key `a` can be transformed into a public key using `g` the
    'generator' point of the Pallas curve. To do this, `g` is 'scaled' by `a`
    (equivalently, `g` is added to itself `a` times in the Pallas curve).
    This is fairly cheap to do in practice via the double-and-add algorithm.
    See https://en.wikipedia.org/wiki/Elliptic_curve_point_multiplication for
    more information.

    The reverse direction -- transforming a public key into a private key -- is
    considered to be computationally intractable. This problem is generally
    known as the 'discrete logarithm problem', and is the basis for the
    security of Mina's signature scheme. The best known algorithms for finding
    a private key from a public key are only slightly better than
    'guess-and-check', where you repeatedly choose a random number and test it
    to check whether it is right.

    The probability of finding the private key for a given public key is
    approximately `1 / 2^128` with the more-efficient Pollard's rho algorithm;
    in other words, about 1 in 100000000000000000000000000000000000000.

    By using this tool to generate a public key with a sufficiently-large
    'vanity prefix', one can effectively choose an elliptic curve point's `x`
    value without any knowledge of its `y` value or any other properties of the
    resulting curve point. Thus, it is effectively impossible to find the
    private key for any such key output by this tool.

    ### Invalid keys

    Invalid keys give the strongest possible assurance that no private key
    exists for the public key, since they do not represent points on the Pallas
    curve at all. Thus, it is mathematically impossible to find a private key
    that will generate an invalid key, since every private key maps to exactly
    1 point on the Pallas curve: its public key.

    While these may be preferable to in some cases, currently the Mina protocol
    rejects any transactions using invalid public keys.

    This tool still provides the ability to create 'vanity' invalid keys, in
    case this situation changes in future. In the meantime, the statistical
    guarantees provided by a valid 'vanity' key should suffice for all
    practical uses.

    ## Valid and invalid keys

    The output public keys are annotated with `(valid)` or `(invalid)`,
    depending on whether they correspond to 'valid' or 'invalid' public keys.

    A Mina public key is a point on the Pallas elliptic curve, which we can
    represent as a pair of Pallas base field elements `(x, y)`. These values
    must satisfy the elliptic curve equation `y^2 = x^3 + 5` over the base
    field.

    In order to reduce the amount of data that is sent over the Mina network,
    and to reduce the length of base58-check encoded public keys, the Mina key
    format uses a 'compressed' representation.
    This compressed representation is the coordinate `x` of the public key and
    an `is_odd` boolean, where `is_odd` determines which value of `y` it
    matches, either `y = sqrt(x^3 + 5)` or `y = -sqrt(x^3 + 5)`.

    For some values of `x`, there is no square-root of `x^3 + 5` in the finite
    field, and so there is no Mina public key with that `x` coordinate.
    However, since we can choose any value of `x` in the 'compressed'
    representation, it is possible to encode one of these values.
    We call a compressed public key with no `y` coordinate 'invalid', and a
    compressed public key where we can calculate the `y` coordinate 'valid'.
*)

open Core_kernel
open Signature_lib

(** Set to `true` for debugging output. *)
let debug = false

(** The prefix to use if no prefix was given as a positional argument. *)
let default_prefix = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"

(** The prefix to find, taken from the first positional argument, or
    `default_prefix` if no positional argument was given.
*)
let desired_prefix =
  try Sys.argv.(1)
  with _ ->
    Format.eprintf "No prefix provided as first argument, using %s@."
      default_prefix ;
    default_prefix

(** The 'smallest' value of `Public_key.Compressed.t` when encoded as bytes.
    This value corresponds to a byte-string of all zeros.
*)
let min_value : Public_key.Compressed.t =
  { x = Snark_params.Tick.Field.zero; is_odd = false }

(** The base58-check representation of `min_value`. *)
let min_value_compressed = Public_key.Compressed.to_base58_check min_value

(** A nearly-maximal value of `Public_key.Compressed.t`, when encoded as bytes.

    The component `x` of the compressed public key is encoded in little-endian
    -- the least significant byte appears first in the byte representation --
    so this value is chosen to maximise those bytes. For example,
    `0x00112233445566778899` would convert in little-endian to the list of
    bytes `[0x99, 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00]`, where
    `0x...` represents a hexadecimal (base-16) number using digits `0..9A..F`.

    The finite field used for the Pasta curve's coordinates (the base field)
    uses slightly fewer than 256 bytes, so we will not get a valid result if we
    use the string of 64 `F`s. For transparency of implementation, we chose to
    set the high nybble (4 bits) to 0.

    This choice may exclude a small number of addresses at the end of the
    search space, if the prefix is nearly-maximal. In practice, this does not
    affect the results of the calculations below, but individuals concerned by
    this decision are recommended to select public keys from the start of the
    search space (ie. the first values output) to entirely rule out any
    possible influence.
*)
let max_value : Public_key.Compressed.t =
  { x =
      Kimchi_backend.Pasta.Basic.Bigint256.of_hex_string
        "0x0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
      |> Kimchi_backend.Pasta.Basic.Fp.of_bigint
  ; is_odd = true
  }

(** The base58-check representation of `max_value`. *)
let max_value_compressed = Public_key.Compressed.to_base58_check max_value

(** The first position at which the base58 strings `min_value_compressed` and
    `max_value_compressed` differ.
    Any characters before this position will be the same in every public key
    encoded with base58-check, and correspond to the fixed 'version byte'.
*)
let first_different_position =
  let rec go i =
    if Char.equal min_value_compressed.[i] max_value_compressed.[i] then
      go (i + 1)
    else i
  in
  go 0

(** The common prefix to all base58-check-encoded public keys, computed from
    `first_different_position`.
*)
let fixed_prefix =
  String.sub ~pos:0 ~len:first_different_position min_value_compressed

(** Returns the list of characters that are valid as the next character after
    the `fixed_prefix`.

    This is a list of each character between (inclusive) the characters in
    `min_value_compressed` and `max_value_compressed` at position
    `first_different_position`.

    Note: this code uses the knowledge that the Mina base58-check alphabet has
    its characters in the same order as the the standard ASCII encoding,
    iterating over the characters using their ASCII ordering rather than
    looking them up in the alphabet directly.

    The interested reader can confirm that this is the case with the following code:
```ocaml
let mina_alphabet =
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
in
let mina_alphabet_characters = String.to_array mina_alphabet in
let mina_alphabet_ascii_indexes =
  Array.map ~f:Char.to_int mina_alphabet_characters
in
let mina_alphabet_ascii_indexes_sorted =
  Array.sorted_copy ~compare:Int.compare mina_alphabet_ascii_indexes
in
Array.equal Int.equal
  mina_alphabet_ascii_indexes
  mina_alphabet_ascii_indexes_sorted;;
```
*)
let changed_prefixes =
  let rec go c c_final acc =
    if c >= c_final then List.rev acc else go (Int.succ c) c_final (c :: acc)
  in
  let get_char_int str = Char.to_int str.[first_different_position] in
  go (get_char_int min_value_compressed) (get_char_int max_value_compressed) []

(** The prefixes to search for.

    For each character `c` in `changed_prefixes`, this calculates the string
    that concatenates `fixed_prefix`, `c`, and `desired_prefix`.
*)
let true_prefixes =
  List.map changed_prefixes ~f:(fun c ->
      fixed_prefix ^ String.of_char (Char.of_int_exn c) ^ desired_prefix )

(** Compute the list of powers of 2 that fit inside the Pallas base field.

    This is an optimisation to allow us to quickly compute a field element that
    encodes to a desired bit-string when we convert it to bytes.
*)
let field_elements =
  let open Snark_params.Tick.Field in
  let two = of_int 2 in
  let rec go current_pow_2 pow acc =
    if Int.( < ) pow size_in_bits then
      go (mul current_pow_2 two) (Int.succ pow) (current_pow_2 :: acc)
    else List.rev acc
  in
  go one 0 []

(** The powers of 2 in the Pallas base field, in order of their 'significance'
    when coverted to bytes.

    This sorting is important to counteract a quirk of the little-endian bytes
    encoding: the bytes themselves are stored in 'reverse' order compared to
    the hexadecimal representation, but the bits within the bytes are stored in
    'forward' order.
    For example, the string of bits representing `0x40BF` is
    `[0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1]`, which is encoded as
    `[1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0]`.

    This code is written to be agnostic about the details of the ordering;
    instead, it sorts the powers of 2 based on how 'small' their base58-check
    string encoding is in ASCII string ordering, using the fact that the order
    of strings in the Mina base58-check alphabet is equivalent to the ordering
    under ASCII strings (as discussed above in `changed_prefixes`).
*)
let field_elements =
  List.sort field_elements ~compare:(fun field1 field2 ->
      let pk1 =
        { min_value with x = Snark_params.Tick.Field.add min_value.x field1 }
      in
      let pk2 =
        { min_value with x = Snark_params.Tick.Field.add min_value.x field2 }
      in
      -String.compare
         (Public_key.Compressed.to_base58_check pk1)
         (Public_key.Compressed.to_base58_check pk2) )

(** Find a 'base' public key to start searching from.

    This starts at the minimum value and tests each value from `field_elements`
    to see if adding it to the `x` coordinate of the public key gives a
    matching base58-check string.
    This operates as a quasi- binary search:
    * if the output string after including the field element is still too low
      to match the prefix, update the best pk to increase that coordinate by
      that field element;
    * if the output string after including the field element is too high to
      match the prefix, including that field element will cause us to
      overshoot, so we leave the best public key unchanged and move on to the
      next one;
    * if the output string has a prefix matching the desired prefix, we stop
      searching and return the *current best* (before we considered this field
      element).

    Since we have ordered our field elements by their contribution to the
    base58-check output, we know that the contributions of all smaller (by byte
    encoding) field elements will be too small to reach the desired prefix.
    Similarly, including any more of the already-considered field elements will
    increase the base58-check output past the desired prefix, by the additive
    nature of their contributions.

    We return a public key that encodes to the largest base58-check value less
    than our target prefix, and a count of the number of field elements that we
    added or skipped to construct it.
*)
let find_base_pk prefix =
  let len = String.length prefix in
  List.fold_until
    ~init:(0, min_value, min_value_compressed)
    ~finish:(fun _ -> None)
    field_elements
    ~f:(fun (i, pk, pk_compressed) field ->
      let pk' = { pk with x = Snark_params.Tick.Field.add pk.x field } in
      let pk_string = Public_key.Compressed.to_base58_check pk' in
      let actual_prefix = String.prefix pk_string len in
      let compared = String.compare actual_prefix prefix in
      if debug then Format.eprintf "%s@." pk_string ;
      if compared < 0 && String.( < ) pk_compressed pk_string then
        (* The public key has a prefix closer to the desired prefix than the
           previous best, update the best candidate.
        *)
        Continue (i + 1, pk', pk_string)
      else if compared > 0 then
        (* The public key has a prefix greater than the desired prefix.
           Including this field element will cause us to overshoot, so keep
           the previous best candidate and try the next field element.
        *)
        Continue (i + 1, pk, pk_compressed)
      else
        (* Increasing by this field element brings us into the desired range.
           Stop searching, and return the previous best, along with the count
           of field elements that we have already considered.
        *)
        Stop (Some (pk, i)) )

(** Compute the next bitstring, reverse-lexicographically. Equivalent to adding
    1 bitwise.
    If there is no space to handle the 'overflow', returns `None`.

    For example:
    * `[false, false, false]` is mapped to `Some([true, false, false])`;
    * `[true, false, true]` is mapped to `Some([false, true, true])`;
    * `[true, true, false]` is mapped to `Some([false, false, true])`;
    * `[true, true, true]` is mapped to `None`.
*)
let next_bitstring x =
  let exception Stop in
  let rec go = function
    | [] ->
        (* All of the bits in the input bitstring were already true. We don't
           want to extend the bitstring, so stop here.
        *)
        raise Stop
    | false :: rest ->
        true :: rest
    | true :: rest ->
        false :: go rest
  in
  try Some (go x) with Stop -> None

(** Print the given public key if its base58-check representation matches the
    given prefix.

    The printed base58-check string is annotated with `(valid)` or `(invalid)`,
    depending on whether it corresponds to a 'valid' public key or not.
*)
let print_pk_if_matches prefix pk =
  let len = String.length prefix in
  let pk_string = Public_key.Compressed.to_base58_check pk in
  let actual_prefix = String.prefix pk_string len in
  if String.equal actual_prefix prefix then
    match Public_key.decompress pk with
    | Some _ ->
        (* The compressed public key corresponds to a Pallas curve point. *)
        Format.printf "%s (valid)@." pk_string
    | None ->
        (* There is no point on the Pallas curve that matches this compressed
           public key.
        *)
        Format.printf "%s (invalid)@." pk_string

let print_values prefix =
  if debug then Format.eprintf "Finding base for %s@." prefix ;
  Option.iter (find_base_pk prefix) ~f:(fun (base_pk, add_index) ->
      let field_elements = List.drop field_elements add_index in
      (* Start with no additional field elements added to the base public key.
      *)
      let field_selectors = List.map ~f:(fun _ -> false) field_elements in
      let rec go field_selectors =
        let field =
          (* Convert `field_selectors` into a field element by adding the
             corresponding member of `field_elements` every time it is `true`,
             and skipping it when it's `false`.
          *)
          List.fold2_exn ~init:base_pk.x field_elements field_selectors
            ~f:(fun field selected_field selected ->
              if selected then Snark_params.Tick.Field.add field selected_field
              else field )
        in
        (* Test both odd and even versions of the public key. *)
        let pk_odd = { base_pk with x = field } in
        let pk_even = { pk_odd with is_odd = true } in
        print_pk_if_matches prefix pk_odd ;
        print_pk_if_matches prefix pk_even ;
        (* We could backtrack when the pk is invalid rather than blindly
           calling [next_bitstring], but this is efficient enough with a
           sufficiently large prefix.
        *)
        match next_bitstring field_selectors with
        | Some field_selectors ->
            go field_selectors
        | None ->
            ()
      in
      if debug then Format.eprintf "Keys for %s:@." prefix ;
      go field_selectors )

let () = List.iter ~f:print_values true_prefixes
