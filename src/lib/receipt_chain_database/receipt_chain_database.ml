open Core_kernel
open Coda_base
module Intf = Intf
module Tree_node = Tree_node

module Make
    (Monad : Key_value_database.Monad.S) (Config : sig
        type t
    end)
    (Key_value_db : Key_value_database.Intf.S
                    with module M := Monad
                     and type key := Receipt.Chain_hash.t
                     and type value := Tree_node.t
                     and type config := Config.t) =
struct
  type t = Key_value_db.t

  let create config = Key_value_db.create config

  module Prover =
    Merkle_list_prover.Make
      (Monad)
      (struct
        type value = Tree_node.t

        type proof_elem = User_command.t

        type context = Key_value_db.t * Receipt.Chain_hash.t

        let to_proof_elem ({Tree_node.key= _; value; parent= _} : value) :
            proof_elem =
          value

        let get_previous ~context ({Tree_node.key; value= _; parent} : value) =
          let t, proving_receipt = context in
          if Receipt.Chain_hash.equal key proving_receipt then
            Monad.return None
          else Key_value_db.get t ~key:parent
      end)

  module Verifier = Merkle_list_verifier.Make (struct
    type proof_elem = User_command.t

    type hash = Receipt.Chain_hash.t [@@deriving eq]

    let hash parent_hash proof_elem =
      Receipt.Chain_hash.cons
        (User_command (User_command.payload proof_elem))
        parent_hash
  end)

  let prove t ~(proving_receipt : Receipt.Chain_hash.t)
      ~(resulting_receipt : Receipt.Chain_hash.t) =
    let open Monad.Let_syntax in
    let%bind tree_node = Key_value_db.get t ~key:resulting_receipt in
    let open Monad.Result.Let_syntax in
    let%bind chain_value =
      Monad.return
      @@ Result.of_option tree_node
           ~error:
             (Error.createf
                !"Could not retrieve resulting receipt \
                  %{sexp:Receipt.Chain_hash.t}"
                resulting_receipt)
    in
    let%bind initial_value, proof =
      Prover.prove ~context:(t, proving_receipt) chain_value
      |> Monad.Result.lift
    in
    if Receipt.Chain_hash.equal initial_value.key proving_receipt then
      Monad.return @@ Ok (initial_value.key, proof)
    else
      Monad.return
      @@ Or_error.errorf
           !"Cannot retrieve receipt: %{sexp: Receipt.Chain_hash.t}"
           initial_value.key

  let verify = Verifier.verify

  let get_payment t ~receipt =
    let open Monad.Option.Let_syntax in
    let%map result = Key_value_db.get t ~key:receipt in
    result.value

  let add t ~previous (user_command : User_command.t) =
    let open Monad.Let_syntax in
    let payload = User_command.payload user_command in
    let receipt_chain_hash =
      Receipt.Chain_hash.cons (User_command payload) previous
    in
    let%bind tree_node = Key_value_db.get t ~key:receipt_chain_hash in
    let node, status =
      Option.value_map tree_node
        ~default:
          ( Some
              { Tree_node.parent= previous
              ; value= user_command
              ; key= receipt_chain_hash }
          , `Ok receipt_chain_hash )
        ~f:(fun {parent= retrieved_parent; _} ->
          if not (Receipt.Chain_hash.equal previous retrieved_parent) then
            (None, `Error_multiple_previous_receipts retrieved_parent)
          else
            ( Some
                {parent= previous; value= user_command; key= receipt_chain_hash}
            , `Duplicate receipt_chain_hash ) )
    in
    let%map () =
      Option.value_map node ~default:(Monad.return ()) ~f:(function node ->
          Key_value_db.set t ~key:receipt_chain_hash ~data:node )
    in
    status

  let database t = t
end

module Make_ident = Make (Key_value_database.Monad.Ident)

let%test_module "receipt_database" =
  ( module struct
    module Key_value_db =
      Key_value_database.Make_mock
        (Receipt.Chain_hash)
        (struct
          type t = Tree_node.t [@@deriving sexp]
        end)

    module Receipt_db = Make_ident (Unit) (Key_value_db)

    let populate_random_path ~db user_commands initial_receipt_hash =
      List.fold user_commands ~init:[initial_receipt_hash]
        ~f:(fun current_leaves user_command ->
          let selected_forked_node = List.random_element_exn current_leaves in
          match
            Receipt_db.add db ~previous:selected_forked_node user_command
          with
          | `Ok checking_receipt ->
              checking_receipt :: current_leaves
          | `Duplicate _ ->
              current_leaves
          | `Error_multiple_previous_receipts _ ->
              failwith "We should not have multiple previous receipts" )
      |> ignore

    let user_command_gen =
      User_command.Gen.payment_with_random_participants
        ~keys:
          (Array.init 5 ~f:(fun (_ : int) -> Signature_lib.Keypair.create ()))
        ~max_amount:10000 ~max_fee:1000 ()

    (* HACK: Limited tirals because tests were taking too long *)
    let%test_unit "Recording a sequence of user commands can generate a valid \
                   proof from the first user command to the last user command"
        =
      Quickcheck.test ~trials:100
        ~sexp_of:[%sexp_of: Receipt.Chain_hash.t * User_command.t list]
        Quickcheck.Generator.(
          tuple2 Receipt.Chain_hash.gen (list_non_empty user_command_gen))
        ~f:(fun (initial_receipt_chain, user_commands) ->
          let db = Receipt_db.create () in
          let resulting_receipt, expected_merkle_path =
            List.fold_map user_commands ~init:initial_receipt_chain
              ~f:(fun prev_receipt_chain user_command ->
                match
                  Receipt_db.add db ~previous:prev_receipt_chain user_command
                with
                | `Ok new_receipt_chain ->
                    (new_receipt_chain, user_command)
                | `Duplicate _ ->
                    failwith
                      "Each receipt chain in a sequence should be unique"
                | `Error_multiple_previous_receipts _ ->
                    failwith "We should not have multiple previous receipts" )
          in
          let expected_merkle_path =
            Option.value_exn (Non_empty_list.of_list_opt expected_merkle_path)
          in
          let proving_receipt =
            Receipt.Chain_hash.cons
              (User_command (User_command.payload @@ List.hd_exn user_commands))
              initial_receipt_chain
          in
          [%test_result: Receipt.Chain_hash.t * User_command.t list]
            ~message:"Proofs should be equal"
            ~expect:(proving_receipt, Non_empty_list.tail expected_merkle_path)
            ( Receipt_db.prove db ~proving_receipt ~resulting_receipt
            |> Or_error.ok_exn ) )

    let%test_unit "There exists a valid proof if a path exists in a tree of \
                   user commands" =
      Quickcheck.test ~trials:100
        ~sexp_of:
          [%sexp_of:
            Receipt.Chain_hash.t * User_command.t * User_command.t list]
        Quickcheck.Generator.(
          tuple3 Receipt.Chain_hash.gen user_command_gen
            (list_non_empty user_command_gen))
        ~f:(fun (prev_receipt_chain, initial_user_command, user_commands) ->
          let db = Receipt_db.create () in
          let initial_receipt_chain =
            match
              Receipt_db.add db ~previous:prev_receipt_chain
                initial_user_command
            with
            | `Ok receipt_chain ->
                receipt_chain
            | `Duplicate _ ->
                failwith
                  "There should be no duplicate inserts since the first user \
                   command is only being inserted"
            | `Error_multiple_previous_receipts _ ->
                failwith
                  "There should be no errors with previous receipts since the \
                   first user command is only being inserted"
          in
          populate_random_path ~db user_commands initial_receipt_chain ;
          let random_receipt_chain =
            List.filter
              (Hashtbl.keys (Receipt_db.database db))
              ~f:(Fn.compose not (Receipt.Chain_hash.equal prev_receipt_chain))
            |> List.random_element_exn
          in
          let generated_initial_receipt_chain, merkle_proof =
            Receipt_db.prove db ~proving_receipt:initial_receipt_chain
              ~resulting_receipt:random_receipt_chain
            |> Or_error.ok_exn
          in
          assert (
            Receipt.Chain_hash.equal generated_initial_receipt_chain
              initial_receipt_chain ) ;
          assert (
            Receipt_db.verify ~init:generated_initial_receipt_chain
              merkle_proof random_receipt_chain
            |> Option.is_some ) )

    let%test_unit "A proof should not exist if a proving receipt does not \
                   exist in the database" =
      Quickcheck.test ~trials:100
        ~sexp_of:
          [%sexp_of:
            Receipt.Chain_hash.t * User_command.t * User_command.t list]
        Quickcheck.Generator.(
          tuple3 Receipt.Chain_hash.gen user_command_gen
            (list_non_empty user_command_gen))
        ~f:
          (fun (initial_receipt_chain, unrecorded_user_command, user_commands) ->
          let db = Receipt_db.create () in
          populate_random_path ~db user_commands initial_receipt_chain ;
          let nonexisting_receipt_chain =
            let receipt_chains = Hashtbl.keys (Receipt_db.database db) in
            let largest_receipt_chain =
              List.find_map receipt_chains ~f:(fun receipt_chain ->
                  let new_receipt_chain =
                    Receipt.Chain_hash.cons
                      (User_command
                         (User_command.payload unrecorded_user_command))
                      receipt_chain
                  in
                  Option.some_if
                    ( not
                    @@ Hashtbl.mem (Receipt_db.database db) new_receipt_chain
                    )
                    new_receipt_chain )
              |> Option.value_exn
            in
            largest_receipt_chain
          in
          let random_receipt_chain =
            List.filter
              (Hashtbl.keys (Receipt_db.database db))
              ~f:
                (Fn.compose not
                   (Receipt.Chain_hash.equal initial_receipt_chain))
            |> List.random_element_exn
          in
          assert (
            Receipt_db.prove db ~proving_receipt:nonexisting_receipt_chain
              ~resulting_receipt:random_receipt_chain
            |> Or_error.is_error ) )
  end )

module Rocksdb =
  Rocksdb.Serializable.Make
    (Receipt.Chain_hash.Stable.Latest)
    (Tree_node.Stable.Latest)
include Make_ident (String) (Rocksdb)
