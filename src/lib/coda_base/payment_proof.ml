open Core_kernel
open Receipt_chain_database_lib

module T = struct
  type t = (Receipt.Chain_hash.t, User_command.t) Payment_proof.t
  [@@deriving eq, sexp, bin_io, yojson]
end

include T

let initial_receipt = Payment_proof.initial_receipt

let payments = Payment_proof.payments

let gen ~keys ~max_amount ~max_fee =
  let open Quickcheck.Generator.Let_syntax in
  let%bind list_size = Int.gen_incl 0 20 in
  let%bind initial_receipt = Receipt.Chain_hash.gen in
  let%map payments =
    Quickcheck.Generator.list_with_length list_size
      (User_command.gen ~keys ~max_amount ~max_fee)
  in
  {Payment_proof.initial_receipt; payments}

let gen_test =
  let keys = Array.init 2 ~f:(fun _ -> Signature_lib.Keypair.create ()) in
  gen ~keys ~max_amount:10000 ~max_fee:1000

let%test_unit "json" =
  Quickcheck.test ~trials:20 gen_test ~sexp_of:sexp_of_t ~f:(fun t ->
      assert (Codable.For_tests.check_encoding (module T) ~equal t) )
