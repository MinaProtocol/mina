(*
  The MIT License (MIT)
  
  Copyright (c) 2016 Maxime Ransan <maxime.ransan@gmail.com>
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

  Copied from https://github.com/mransan/base58. It isn't in opam, despite what
  the readme says.

  The base58 in opam operates on integers, not byte strings.
*)

module Util = struct
  let implace_map f bytes =
    let rec aux = function
      | -1 ->
          ()
      | i ->
          Bytes.unsafe_set bytes i (f (Bytes.unsafe_get bytes i)) ;
          aux (i - 1)
    in
    aux (Bytes.length bytes - 1)
end

(* Util *)

module Alphabet = struct
  exception Invalid

  exception Invalid_base58_character

  type t = string * int array

  let make s =
    if String.length s <> 58 then raise Invalid
    else
      let a = Array.make 256 (-1) in
      String.iteri (fun i c -> Array.unsafe_set a (Char.code c) i) s ;
      (s, a)

  let value c (_, alphabet_values) =
    match Array.unsafe_get alphabet_values (Char.code c) with
    | -1 ->
        raise Invalid_base58_character
    | i ->
        i

  let chr i (s, _) = String.unsafe_get s i
end

(* Alphabet *)

let zero = Char.unsafe_chr 0

let convert inp from_base to_base =
  let inp_len = Bytes.length inp in
  let inp_beg =
    let rec aux = function
      | i when i = inp_len || Bytes.get inp i <> zero ->
          i
      | i ->
          aux (i + 1)
    in
    aux 0
  in
  let buf_len =
    let inp_len = float_of_int inp_len in
    let from_base = float_of_int from_base in
    let to_base = float_of_int to_base in
    int_of_float @@ (1. +. (inp_len *. log from_base /. log to_base))
  in
  let buf = Bytes.make buf_len zero in
  let buf_last_index = buf_len - 1 in
  let carry = ref 0 in
  let buf_end = ref buf_last_index in
  for inp_i = inp_beg to inp_len - 1 do
    carry := Char.code (Bytes.unsafe_get inp inp_i) ;
    let rec iter = function
      | buf_i when buf_i > !buf_end || !carry <> 0 ->
          carry :=
            !carry + (from_base * (Bytes.unsafe_get buf buf_i |> Char.code)) ;
          Bytes.unsafe_set buf buf_i (Char.unsafe_chr (!carry mod to_base)) ;
          carry := !carry / to_base ;
          iter (buf_i - 1)
      | buf_end ->
          buf_end
    in
    buf_end := iter buf_last_index
  done
  (* [inp] iteration *) ;
  let buf_written_len = buf_len - !buf_end - 1 in
  let out_len = inp_beg + buf_written_len in
  let out = Bytes.create out_len in
  Bytes.fill out 0 inp_beg zero ;
  Bytes.blit buf (!buf_end + 1) out inp_beg buf_written_len ;
  out

let encode alphabet bin =
  let b58 = convert bin 256 58 in
  Bytes.map (fun c -> Alphabet.chr (Char.code c) alphabet) b58

let decode alphabet bin =
  let bin =
    Bytes.map (fun c -> Char.unsafe_chr (Alphabet.value c alphabet)) bin
  in
  convert bin 58 256

(* export public Alphabet functionality *)

type alphabet = Alphabet.t

exception Invalid_alphabet = Alphabet.Invalid

exception Invalid_base58_character = Alphabet.Invalid_base58_character

let make_alphabet = Alphabet.make
