open Core_kernel

type t = (Receipt.Chain_hash.t * User_command.t) list
[@@deriving eq, sexp, bin_io]

include Codable.Make (struct
  type original = t

  type merkle_node =
    {receipt_chain_hash: Receipt.Chain_hash.t; payment: User_command.t}
  [@@deriving yojson]

  type standardized = merkle_node list [@@deriving yojson]

  let encode =
    List.map ~f:(fun (receipt_chain_hash, payment) ->
        {receipt_chain_hash; payment} )

  let decode =
    List.map ~f:(fun {receipt_chain_hash; payment} ->
        (receipt_chain_hash, payment) )
end)

let gen ~keys ~max_amount ~max_fee =
  let open Quickcheck.Generator.Let_syntax in
  let%bind list_size = Int.gen_incl 0 20 in
  let%bind initial_receipt_chain = Receipt.Chain_hash.gen in
  let%map payments =
    Quickcheck.Generator.list_with_length list_size
      (User_command.gen ~keys ~max_amount ~max_fee)
  in
  let hashes =
    List.folding_map payments ~init:initial_receipt_chain
      ~f:(fun acc_hash payment ->
        let {User_command.payload; _} = payment in
        let new_hash = Receipt.Chain_hash.cons payload acc_hash in
        (new_hash, new_hash) )
  in
  List.zip_exn hashes payments

let gen_test =
  let keys = Array.init 2 ~f:(fun _ -> Signature_lib.Keypair.create ()) in
  gen ~keys ~max_amount:10000 ~max_fee:1000

let%test_unit "json" =
  Quickcheck.test ~trials:20 gen_test ~sexp_of:sexp_of_t ~f:(fun t ->
      assert (For_tests.check_encoding ~equal t) )
