open Core_kernel
open Backend
open Pickles_types
open Import

let bits_random_oracle =
  let h = Digestif.blake2s 32 in
  fun ~length s ->
    Digestif.digest_string h s |> Digestif.to_raw_string h |> String.to_list
    |> List.concat_map ~f:(fun c ->
           let c = Char.to_int c in
           List.init 8 ~f:(fun i -> (c lsr i) land 1 = 1) )
    |> fun a -> List.take a length

let ro lab length f =
  let r = ref 0 in
  fun () ->
    incr r ;
    f (bits_random_oracle ~length (sprintf "%s_%d" lab !r))

let wrap = ro "fq" Wrap.Field.size_in_bits Wrap.Field.of_bits

let step = ro "fp" Step.Field.size_in_bits Step.Field.of_bits

let chal = ro "chal" Challenge.Constant.length Challenge.Constant.of_bits

let scalar_chal () = Scalar_challenge.create (chal ())
