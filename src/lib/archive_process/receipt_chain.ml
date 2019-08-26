open Core
open Coda_base
open Signature_lib

exception
  Receipt_chain_hash_multiple_parents of
    ( [`Existing_parent of Receipt.Chain_hash.t]
    * [`New_parent of Receipt.Chain_hash.t] )

module Make (Inputs : Transition_frontier.Inputs_intf) = struct
  open Inputs

  type t = {receipt_chain_database: Receipt_chain_database.t; logger: Logger.t}

  module Writer = struct
    let create ~logger receipt_chain_database = {receipt_chain_database; logger}

    let add {receipt_chain_database; logger}
        {With_hash.data= external_transition; hash= _}
        previous_receipt_chains_from_parent_block =
      let sorted_user_commands =
        External_transition.user_commands external_transition
        |> List.sort
             ~compare:
               (Comparable.lift ~f:User_command.nonce
                  Coda_numbers.Account_nonce.compare)
      in
      List.fold sorted_user_commands
        ~init:previous_receipt_chains_from_parent_block
        ~f:(fun previous_receipt_chains user_command ->
          let sender = User_command.sender user_command in
          let previous = Map.find_exn previous_receipt_chains sender in
          match
            Receipt_chain_database.add receipt_chain_database ~previous
              user_command
          with
          | `Ok receipt_chain ->
              Logger.debug logger
                !"The $receipt_chain of $user_command is $hash"
                ~location:__LOC__ ~module_:__MODULE__
                ~metadata:
                  [ ( "receipt_chain"
                    , Receipt.Chain_hash.to_yojson receipt_chain ) ] ;
              Public_key.Compressed.Map.set previous_receipt_chains ~key:sender
                ~data:receipt_chain
          | `Duplicate receipt_chain ->
              Logger.warn logger
                !"$receipt_chain already exists in database"
                ~location:__LOC__ ~module_:__MODULE__
                ~metadata:
                  [ ( "receipt_chain"
                    , Receipt.Chain_hash.to_yojson receipt_chain ) ] ;
              previous_receipt_chains
          | `Error_multiple_previous_receipts existing_parent ->
              raise
                (Receipt_chain_hash_multiple_parents
                   (`Existing_parent existing_parent, `New_parent previous)) )
      |> ignore
  end

  module Reader = struct
    let prove {receipt_chain_database; _} =
      Receipt_chain_database.prove receipt_chain_database
  end
end
