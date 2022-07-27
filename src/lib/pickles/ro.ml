open Core_kernel
open Backend
open Pickles_types
open Import

(** hash [s] with blake2s and return [length] bits of the digest *)
let bits_random_oracle ~length s =
  (* blake2s with output of 32 bytes *)
  let h = Digestif.blake2s 32 in
  (* unpacks a [char] into a list of 8 bits (encoded as [bool]s) *)
  let char_to_bits c =
    let c = Char.to_int c in
    List.init 8 ~f:(fun i -> (c lsr i) land 1 = 1)
  in
  (* hash and convert to bits *)
  let digest = Digestif.(digest_string h s |> to_raw_string h) in
  let digest_bits =
    digest |> String.to_list |> List.concat_map ~f:char_to_bits
  in
  (* truncate to `length` bits *)
  List.take digest_bits length

(** generates `length` random bits deterministically and runs `f` on the result.
    Internally, random bits are produced using `blake2s(counter, label)`,
    where counter is incremented every time the function is called *)
let ro label length f =
  let r = ref 0 in
  fun () ->
    incr r ;
    let to_hash = sprintf "%s_%d" label !r in
    let bits = bits_random_oracle ~length to_hash in
    f bits

(** generates a deterministically-random [Tock.Field.t] *)
let tock = ro "fq" Tock.Field.size_in_bits Tock.Field.of_bits

(** generates a deterministically-random [Tick.Field.t] *)
let tick = ro "fp" Tick.Field.size_in_bits Tick.Field.of_bits

(** generates a deterministically-random [Challenge.Constant.t] *)
let chal = ro "chal" Challenge.Constant.length Challenge.Constant.of_bits

(** generates a deterministically-random [Challenge.Constant.t],
    and wraps it inside a [Scalar_challenge.t] *)
let scalar_chal () = Scalar_challenge.create (chal ())
