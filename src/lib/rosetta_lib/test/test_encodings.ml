(* test_encodings.ml -- print out Rosetta encodings *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Signature_lib
open Rosetta_coding

[%%else]

open Signature_lib_nonconsensus
open Rosetta_coding_nonconsensus

[%%endif]

let pk1 =
  Public_key.Compressed.of_base58_check_exn
    "B62qkef7po74VEvJYcLYsdZ83FuKidgNZ8Xiaitzo8gKJXaxLwxgG7T"

let pk2 =
  Public_key.Compressed.of_base58_check_exn
    "B62qnekV6LVbEttV7j3cxJmjSbxDWuXa5h3KeVEXHPGKTzthQaBufrY"

let main () =
  printf "%s\n%!" (Coding.of_public_key_compressed pk1) ;
  printf "%s\n%!" (Coding.of_public_key_compressed pk2)

let _ = main ()
