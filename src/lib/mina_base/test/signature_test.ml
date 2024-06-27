(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^signatures$'
    Subject:    Test signaturtes.
 *)

open Core_kernel
open Mina_base
open Signature

let signature_decode_after_encode_is_identity () =
  Quickcheck.test ~trials:300 gen ~f:(fun signature ->
      [%test_eq: t option] (Some signature) (Raw.encode signature |> Raw.decode) )

let base58Check_stable () =
  let expected =
    "7mWxjLYgbJUkZNcGouvhVj5tJ8yu9hoexb9ntvPK8t5LHqzmrL6QJjjKtf5SgmxB4QWkDw7qoMMbbNGtHVpsbJHPyTy2EzRQ"
  in
  let got = to_base58_check dummy in
  [%test_eq: string] got expected
