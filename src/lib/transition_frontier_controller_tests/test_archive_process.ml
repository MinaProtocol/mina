open Async
open Core
open Coda_base

let max_length = 6

module Stubs = Stubs.Make (struct
  let max_length = max_length
end)

open Stubs
module Receipt_chain = Archive_process.Receipt_chain.Make (Stubs)

(* TODO: test that receipt chains are done *)
let%test_module "Receipt Chain" =
  ( module struct
    let logger = Logger.create ()

    let trust_system = Trust_system.null ()

    let create_receipt_chain_database () =
      let directory = File_system.make_directory_name None in
      Receipt_chain_database.create ~directory

    let send_payment (sender_account, sender_sk) staged_ledger
        accounts_with_secret_keys =
      let public_keys =
        List.map accounts_with_secret_keys ~f:(fun (_, account) ->
            Account.public_key account )
      in
      let receiver_pk = List.random_element_exn public_keys in
      let payment =
        Option.value_exn
          (create_payment ~staged_ledger
             (sender_account, sender_sk)
             receiver_pk (Currency.Amount.of_int 1))
      in
      Sequence.singleton payment

    let create_breadcrumbs ~logger ~trust_system ~size
        (sender_account, sender_sk) root =
      Deferred.all
      @@ Quickcheck.random_value
           (gen_linear_breadcrumbs
              ~gen_payments:(send_payment (sender_account, sender_sk))
              ~logger ~trust_system ~size
              ~accounts_with_secret_keys:Genesis_ledger.accounts root)

    let get_receipt_chain breadcrumb public_key =
      let ledger =
        Staged_ledger.ledger
        @@ Transition_frontier.(Breadcrumb.staged_ledger breadcrumb)
      in
      let location =
        Option.value_exn (Ledger.location_of_key ledger public_key)
      in
      (Option.value_exn (Ledger.get ledger location)).receipt_chain_hash

    let%test_unit "A node that has transactions in different blocks that are \
                   lined up and they can create a merkle proof for these \
                   transactions up to the best breadcrumb" =
      let largest_private_key_opt, largest_account =
        Genesis_ledger.largest_account_exn ()
      in
      let largest_public_key = Account.public_key largest_account in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier =
            create_root_frontier ~logger Genesis_ledger.accounts
          in
          let root = Transition_frontier.root frontier in
          let%bind created_breadcrumbs =
            create_breadcrumbs ~logger ~trust_system ~size:max_length
              (largest_account, Option.value_exn largest_private_key_opt)
              root
          in
          let transition_frontier_diffs =
            List.folding_map created_breadcrumbs ~init:root
              ~f:(fun previous added ->
                ( added
                , Transition_frontier.Diff.New_breadcrumb {previous; added} )
            )
          in
          let%map () =
            Deferred.List.iter created_breadcrumbs
              ~f:(Transition_frontier.add_breadcrumb_exn frontier)
          in
          let archive_diffs =
            List.map transition_frontier_diffs ~f:(fun diff ->
                Option.value_exn
                  (Transition_frontier.Diff.Archive_diff
                   .of_transition_frontier_diff diff) )
          in
          let receipt_chain_database = create_receipt_chain_database () in
          (* TODO: fix this *)
          let receipt_chain =
            Receipt_chain.Writer.create ~logger receipt_chain_database
          in
          List.iter archive_diffs ~f:(function
            | Transition_frontier.Diff.Archive_diff.Breadcrumb_added
                { block= transition_with_hash, _
                ; senders_previous_receipt_chains } ->
                Receipt_chain.Writer.add receipt_chain transition_with_hash
                  senders_previous_receipt_chains
            | Root_transitioned _ ->
                failwith "We should only be processing Root_transitioned diffs" ) ;
          let best_tip_receipt_hash =
            get_receipt_chain
              (Transition_frontier.best_tip frontier)
              largest_public_key
          in
          (* Create a receipt_chain_proof for each transaction that the largest public key made that occurred for a block and checking the length of the proof *)
          List.fold_result created_breadcrumbs ~init:0
            ~f:(fun index breadcrumb ->
              let proving_receipt =
                get_receipt_chain breadcrumb largest_public_key
              in
              let open Or_error.Let_syntax in
              let resulting_receipt = best_tip_receipt_hash in
              let%bind ({payments; _} as proof) =
                Receipt_chain.Reader.prove receipt_chain ~proving_receipt
                  ~resulting_receipt
              in
              let payments_length = List.length payments in
              let expected_payments_length = max_length - index in
              let%bind () =
                Result.ok_if_true
                  (expected_payments_length = payments_length)
                  ~error:
                    (Error.createf
                       !"Expected length of Merkle list %i\n\
                        \ Acount length of merkle list is %i"
                       expected_payments_length payments_length)
              in
              let%map () =
                Receipt_chain_database.verify ~resulting_receipt proof
              in
              index + 1 )
          |> Or_error.ok_exn |> ignore )
  end )
