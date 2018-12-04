open Core_kernel

module Make
    (Payment : Intf.Payment)
    (Receipt_chain_hash : Intf.Receipt_chain_hash
                          with type payment_payload := Payment.Payload.t)
    (Key_value_db : Key_value_database.S
                    with type key := Receipt_chain_hash.t
                     and type value :=
                                (Receipt_chain_hash.t, Payment.t) Tree_node.t) :
  Intf.Test.S
  with type receipt_chain_hash := Receipt_chain_hash.t
   and type payment := Payment.t
   and type database := Key_value_db.t = struct
  type t = Key_value_db.t

  let create ~directory = Key_value_db.create ~directory

  let prove t ~proving_receipt ~resulting_receipt =
    let open Or_error.Let_syntax in
    let rec parent_traversal start_receipt last_receipt :
        Payment.t list Or_error.t =
      match%bind
        Key_value_db.get t ~key:last_receipt
        |> Result.of_option
             ~error:
               (Error.createf
                  !"Cannot retrieve receipt: %{sexp: Receipt_chain_hash.t}"
                  last_receipt)
      with
      | Root ->
          Or_error.errorf
            !"The payment of root hash %{sexp: Receipt_chain_hash.t} is not \
              recorded"
            last_receipt
      | Child {value; parent; _} ->
          if Receipt_chain_hash.equal start_receipt last_receipt then
            Or_error.return [value]
          else
            let%map subresult = parent_traversal start_receipt parent in
            value :: subresult
    in
    let%map result = parent_traversal proving_receipt resulting_receipt in
    {Payment_proof.initial_receipt= proving_receipt; payments= List.rev result}

  let get_payment t ~receipt =
    Key_value_db.get t ~key:receipt
    |> Option.bind ~f:(function Root -> None | Child {value; _} -> Some value)

  let add t ~previous (payment : Payment.t) =
    let payload = Payment.payload payment in
    let receipt_chain_hash = Receipt_chain_hash.cons payload previous in
    let node, status =
      Option.value_map
        (Key_value_db.get t ~key:receipt_chain_hash)
        ~default:
          ( Some (Tree_node.Child {parent= previous; value= payment})
          , `Ok receipt_chain_hash )
        ~f:(function
          | Root ->
              ( Some (Child {parent= previous; value= payment})
              , `Duplicate receipt_chain_hash )
          | Child {parent= retrieved_parent; _} ->
              if not (Receipt_chain_hash.equal previous retrieved_parent) then
                (None, `Error_multiple_previous_receipts retrieved_parent)
              else
                ( Some (Child {parent= previous; value= payment})
                , `Duplicate receipt_chain_hash ))
    in
    Option.iter node ~f:(function node ->
        Key_value_db.set t ~key:receipt_chain_hash ~data:node ) ;
    status

  let database t = t
end

let%test_module "receipt_database" =
  ( module struct
    module Payment = struct
      include Char

      module Payload = struct
        type nonrec t = t
      end

      let payload = Fn.id
    end

    module Receipt_chain_hash = struct
      include String

      let empty = ""

      let cons (payment : Payment.t) t = String.of_char payment ^ t
    end

    module Key_value_db =
      Key_value_database.Make_mock
        (Receipt_chain_hash)
        (struct
          type t = (Receipt_chain_hash.t, Payment.t) Tree_node.t
          [@@deriving sexp]
        end)

    module Receipt_db = Make (Payment) (Receipt_chain_hash) (Key_value_db)
    module Verifier = Verifier.Make (Payment) (Receipt_chain_hash)

    let populate_random_path ~db payments initial_receipt_hash =
      List.fold payments ~init:[initial_receipt_hash]
        ~f:(fun current_leaves payment ->
          let selected_forked_node = List.random_element_exn current_leaves in
          match Receipt_db.add db ~previous:selected_forked_node payment with
          | `Ok checking_receipt -> checking_receipt :: current_leaves
          | `Duplicate _ -> current_leaves
          | `Error_multiple_previous_receipts _ ->
              failwith "We should not have multiple previous receipts" )
      |> ignore

    let%test_unit "Recording a sequence of payments can generate a valid \
                   proof from the first payment to the last payment" =
      Quickcheck.test
        ~sexp_of:[%sexp_of: Receipt_chain_hash.t * Payment.t list]
        Quickcheck.Generator.(
          tuple2 Receipt_chain_hash.gen (list_non_empty Payment.gen))
        ~f:(fun (initial_receipt_chain, payments) ->
          let db = Receipt_db.create ~directory:"" in
          let resulting_receipt, expected_merkle_path =
            List.fold_map payments ~init:initial_receipt_chain
              ~f:(fun prev_receipt_chain payment ->
                match
                  Receipt_db.add db ~previous:prev_receipt_chain payment
                with
                | `Ok new_receipt_chain -> (new_receipt_chain, payment)
                | `Duplicate _ ->
                    failwith
                      "Each receipt chain in a sequence should be unique"
                | `Error_multiple_previous_receipts _ ->
                    failwith "We should not have multiple previous receipts" )
          in
          let proving_receipt =
            Receipt_chain_hash.cons (List.hd_exn payments)
              initial_receipt_chain
          in
          [%test_result: (Receipt_chain_hash.t, Payment.t) Payment_proof.t]
            ~message:"Proofs should be equal"
            ~expect:
              { Payment_proof.initial_receipt= proving_receipt
              ; payments= expected_merkle_path }
            ( Receipt_db.prove db ~proving_receipt ~resulting_receipt
            |> Or_error.ok_exn ) )

    let%test_unit "There exists a valid proof if a path exists in a tree of \
                   payments" =
      Quickcheck.test
        ~sexp_of:[%sexp_of: Receipt_chain_hash.t * Payment.t * Payment.t list]
        Quickcheck.Generator.(
          tuple3 Receipt_chain_hash.gen Payment.gen
            (list_non_empty Payment.gen))
        ~f:(fun (prev_receipt_chain, initial_payment, payments) ->
          let db = Receipt_db.create ~directory:"" in
          let initial_receipt_chain =
            match
              Receipt_db.add db ~previous:prev_receipt_chain initial_payment
            with
            | `Ok receipt_chain -> receipt_chain
            | `Duplicate _ ->
                failwith
                  "There should be no duplicate inserts since the first \
                   payment is only being inserted"
            | `Error_multiple_previous_receipts _ ->
                failwith
                  "There should be no errors with previous receipts since the \
                   first payment is only being inserted"
          in
          populate_random_path ~db payments initial_receipt_chain ;
          let random_receipt_chain =
            List.filter
              (Hashtbl.keys (Receipt_db.database db))
              ~f:(Fn.compose not (String.equal prev_receipt_chain))
            |> List.random_element_exn
          in
          let proof =
            Receipt_db.prove db ~proving_receipt:initial_receipt_chain
              ~resulting_receipt:random_receipt_chain
            |> Or_error.ok_exn
          in
          assert (
            Verifier.verify proof ~resulting_receipt:random_receipt_chain
            |> Result.is_ok ) )

    let%test_unit "A proof should not exist if a proving receipt does not \
                   exist in the database" =
      Quickcheck.test
        ~sexp_of:[%sexp_of: Receipt_chain_hash.t * Payment.t * Payment.t list]
        Quickcheck.Generator.(
          tuple3 Receipt_chain_hash.gen Payment.gen
            (list_non_empty Payment.gen))
        ~f:(fun (initial_receipt_chain, unrecorded_payment, payments) ->
          let db = Receipt_db.create ~directory:"" in
          populate_random_path ~db payments initial_receipt_chain ;
          let nonexisting_receipt_chain =
            let receipt_chains = Hashtbl.keys (Receipt_db.database db) in
            let largest_receipt_chain =
              List.max_elt receipt_chains ~compare:(fun chain1 chain2 ->
                  Int.compare (String.length chain1) (String.length chain2) )
              |> Option.value_exn
            in
            Receipt_chain_hash.cons unrecorded_payment largest_receipt_chain
          in
          let random_receipt_chain =
            List.filter
              (Hashtbl.keys (Receipt_db.database db))
              ~f:(Fn.compose not (String.equal initial_receipt_chain))
            |> List.random_element_exn
          in
          assert (
            Receipt_db.prove db ~proving_receipt:nonexisting_receipt_chain
              ~resulting_receipt:random_receipt_chain
            |> Or_error.is_error ) )
  end )
