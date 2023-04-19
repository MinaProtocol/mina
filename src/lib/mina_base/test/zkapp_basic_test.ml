(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^zkApp basic$'
    Subject:    Test zkApp basics.
 *)

open Core_kernel
open Mina_base
open Zkapp_basic
open Signature_lib

let int_to_bits_roundtrip () =
  Quickcheck.test ~trials:100 Int.(gen_incl min_value max_value)
    ~f:(fun i ->
      [%test_eq: int] i (int_of_bits @@ int_to_bits ~length:64 i))

let invalid_public_key_is_invalid () =
  [%test_eq: Public_key.t option] None
    (Public_key.decompress invalid_public_key)
