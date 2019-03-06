open Core_kernel

module Make
    (Payment : Intf.Payment)
    (Receipt_chain_hash : Intf.Receipt_chain_hash
                          with type payment_payload := Payment.Payload.t) :
  Intf.Verifier
  with type receipt_chain_hash := Receipt_chain_hash.t
   and type payment := Payment.t = struct
  let verify ~resulting_receipt {Payment_proof.initial_receipt; payments} =
    match payments with
    | _ :: merkle_list ->
        let derived_receipt_chain =
          List.fold merkle_list ~init:initial_receipt
            ~f:(fun prev_receipt payment ->
              Receipt_chain_hash.cons (Payment.payload payment) prev_receipt )
        in
        Result.ok_if_true
          (Receipt_chain_hash.equal resulting_receipt derived_receipt_chain)
          ~error:
            (Error.createf
               !"Unable to derive resulting receipt %{sexp: \
                 Receipt_chain_hash.t}"
               resulting_receipt)
    | [] -> Or_error.error_string "A merkle list should be non-empty"
end
