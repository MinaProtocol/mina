open Coda_base
include Coda_base.User_command.Stable.V1

let get_participants user_command =
  let sender = User_command.sender user_command in
  let payload = User_command.payload user_command in
  match User_command_payload.body payload with
  | Stake_delegation {new_delegate} ->
      [sender; new_delegate]
  | Payment {receiver; _} ->
      [sender; receiver]
  | Chain_voting _ ->
      [sender]

module Gen = User_command.Gen

let on_delegation_command user_command ~f =
  let sender = User_command.sender user_command in
  match User_command.(Payload.body @@ payload user_command) with
  | Payment _ | Chain_voting _ ->
      ()
  | Stake_delegation _ ->
      f sender

let assert_same_set expected_transactions transactions =
  User_command.Set.(
    [%test_eq: t] (of_list expected_transactions) (of_list transactions))
