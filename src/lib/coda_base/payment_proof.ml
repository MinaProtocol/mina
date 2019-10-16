open Core_kernel
open Receipt_chain_database_lib

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Receipt.Chain_hash.Stable.V1.t
      , User_command.Stable.V1.t )
      Payment_proof.Stable.V1.t
    [@@deriving eq, sexp, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving eq, sexp, yojson]

let initial_receipt = Payment_proof.initial_receipt

let payments = Payment_proof.payments

let gen ~keys ~max_amount ~max_fee =
  let open Quickcheck.Generator.Let_syntax in
  let%bind list_size = Int.gen_incl 0 20 in
  let%bind initial_receipt = Receipt.Chain_hash.gen in
  let%map payments =
    Quickcheck.Generator.list_with_length list_size
      (User_command.Gen.payment_with_random_participants ~keys ~max_amount
         ~max_fee ())
  in
  {Payment_proof.initial_receipt; payments}

let gen_test =
  let keys = Array.init 2 ~f:(fun _ -> Signature_lib.Keypair.create ()) in
  gen ~keys ~max_amount:10000 ~max_fee:1000

let%test_unit "json" =
  Quickcheck.test ~seed:(`Deterministic "seed") ~trials:20 gen_test
    ~sexp_of:sexp_of_t ~f:(fun t ->
      assert (Codable.For_tests.check_encoding (module Stable.Latest) ~equal t)
  )
