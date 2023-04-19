open Core_kernel
open Mina_base
open Signed_command

let completeness () =
  Quickcheck.test ~trials:20 gen_test ~f:([%test_pred: t] check_signature)

let json () =
  Quickcheck.test ~trials:20 ~sexp_of:sexp_of_t gen_test
    ~f:
      ([%test_pred: t]
         (Codable.For_tests.check_encoding (module Stable.Latest) ~equal) )
