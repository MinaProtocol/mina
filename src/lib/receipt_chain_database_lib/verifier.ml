open Core_kernel

module Make
    (Transaction : Intf.Payment)
    (Receipt_chain_hash : Intf.Receipt_chain_hash
                          with type payment_payload := Transaction.payload) =
struct
  let verify ~resulting_receipt = function
    | (proving_receipt, _) :: merkle_list ->
        let open Result.Let_syntax in
        let%bind derived_receipt_chain =
          List.fold_result merkle_list ~init:proving_receipt
            ~f:(fun prev_receipt (expected_receipt, payment) ->
              let computed_receipt =
                Receipt_chain_hash.cons payment prev_receipt
              in
              if Receipt_chain_hash.equal expected_receipt computed_receipt
              then Ok expected_receipt
              else
                Or_error.errorf
                  !"Receipt hashes should be equal (%{sexp: \
                    Receipt_chain_hash.t}, %{sexp: Receipt_chain_hash.t})"
                  expected_receipt computed_receipt )
        in
        Result.ok_if_true
          (Receipt_chain_hash.equal resulting_receipt derived_receipt_chain)
          ~error:
            (Error.createf
               !"Unable to derivie resulting receipt %{sexp: \
                 Receipt_chain_hash.t}"
               resulting_receipt)
    | [] -> Or_error.error_string "A merkle list should be non-empty"
end
