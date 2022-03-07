(* test_encodings.ml -- print out Rosetta encodings *)

open Core_kernel
open Signature_lib
open Rosetta_coding

let pk1 =
  Public_key.Compressed.of_base58_check_exn
    "B62qrcFstkpqXww1EkSGrqMCwCNho86kuqBd4FrAAUsPxNKdiPzAUsy"

let pk2 =
  Public_key.Compressed.of_base58_check_exn
    "B62qkfHpLpELqpMK6ZvUTJ5wRqKDRF3UHyJ4Kv3FU79Sgs4qpBnx5RR"

let main () =
  printf "%s\n%!" (Coding.of_public_key_compressed pk1) ;
  printf "%s\n%!" (Coding.of_public_key_compressed pk2)

let _ = main ()
