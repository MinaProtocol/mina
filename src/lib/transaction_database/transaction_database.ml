open Coda_base
open Core
open Signature_lib

module Payment_participants = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { sender: Public_key.Compressed.Stable.V1.t option
          ; receiver: Public_key.Compressed.Stable.V1.t option }
        [@@deriving bin_io, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t =
    { sender: Public_key.Compressed.t option
    ; receiver: Public_key.Compressed.t option }
end

module Database =
  Rocksdb.Serializable.Make
    (Transaction.Stable.V1)
    (Payment_participants.Stable.V1)

type user_transactions =
  {sent: Transaction.t list; received: Transaction.t list}

type cache =
  { user_transactions: user_transactions Public_key.Compressed.Table.t
  ; all_transactions: Transaction.Hash_set.t }

type t = {database: Database.t; cache: cache}

let create ?directory_name () =
  let directory =
    match directory_name with
    | None ->
        Uuid.to_string (Uuid_unix.create ())
    | Some name ->
        name
  in
  { database= Database.create ~directory
  ; cache=
      { user_transactions= Public_key.Compressed.Table.create ()
      ; all_transactions= Transaction.Hash_set.create () } }

(* TODO: make load function #2333 *)

let close {database; _} = Database.close database

let add t transaction =
  match Hash_set.strict_add t.cache.all_transactions transaction with
  | Error _ ->
      ()
  | Ok () ->
      let sender_and_receiver_pairs =
        match transaction with
        | Fee_transfer (One (pk, _)) ->
            [Payment_participants.{receiver= Some pk; sender= None}]
        | Fee_transfer (Two ((pk1, _), (pk2, _))) ->
            [ {receiver= Some pk1; sender= None}
            ; {receiver= Some pk2; sender= None} ]
        | Coinbase {Coinbase.proposer; _} ->
            [{receiver= Some proposer; sender= None}]
        | User_command checked_user_command ->
            let user_command =
              User_command.forget_check checked_user_command
            in
            let sender = Some (User_command.sender user_command) in
            let payload = User_command.payload user_command in
            let receiver =
              Some
                ( match User_command_payload.body payload with
                | Stake_delegation (Set_delegate {new_delegate}) ->
                    new_delegate
                | Payment {receiver; _} ->
                    receiver )
            in
            [{receiver; sender}]
      in
      let transaction_with_pairs =
        List.map sender_and_receiver_pairs ~f:(fun pair -> (transaction, pair))
      in
      Database.set_batch t.database ~update_pairs:transaction_with_pairs
        ~remove_keys:[] ;
      List.iter sender_and_receiver_pairs ~f:(fun {sender; receiver} ->
          Option.iter sender ~f:(fun new_transaction_sender ->
              Hashtbl.update t.cache.user_transactions new_transaction_sender
                ~f:(function
                | Some transactions ->
                    {transactions with sent= transaction :: transactions.sent}
                | None ->
                    {sent= [transaction]; received= []} ) ) ;
          Option.iter receiver ~f:(fun new_transaction_receiver ->
              Hashtbl.update t.cache.user_transactions new_transaction_receiver
                ~f:(function
                | Some transactions ->
                    { transactions with
                      received= transaction :: transactions.received }
                | None ->
                    {sent= []; received= [transaction]} ) ) )

let get_transactions {cache= {user_transactions; _}; _} public_key =
  let open Option in
  value ~default:[]
  @@ ( Hashtbl.find user_transactions public_key
     (* You should not have a transaction where you are a sender and a receiver *)
     >>| fun {sent; received} -> sent @ received )
