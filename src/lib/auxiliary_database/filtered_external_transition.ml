open Core
open Coda_base
open Coda_transition
open Signature_lib

module Transactions = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { user_commands: User_command.Stable.V1.t list
          ; fee_transfers: Fee_transfer.Single.Stable.V1.t list
          ; coinbase: Currency.Amount.Stable.V1.t }
        [@@deriving bin_io, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t =
    { user_commands: User_command.t list
    ; fee_transfers: Fee_transfer.Single.t list
    ; coinbase: Currency.Amount.t }
end

module Protocol_state = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { previous_state_hash: State_hash.Stable.V1.t
          ; blockchain_state: Coda_state.Blockchain_state.Value.Stable.V1.t }
        [@@deriving bin_io, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t =
    { previous_state_hash: State_hash.t
    ; blockchain_state: Coda_state.Blockchain_state.Value.t }
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { creator: Public_key.Compressed.Stable.V1.t
        ; protocol_state: Protocol_state.Stable.V1.t
        ; transactions: Transactions.Stable.V1.t }
      [@@deriving bin_io, version {unnumbered}]
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t =
  { creator: Public_key.Compressed.t
  ; protocol_state: Protocol_state.t
  ; transactions: Transactions.t }

let participants {transactions= {user_commands; fee_transfers; _}; creator; _}
    =
  let open Public_key.Compressed.Set in
  let user_command_set =
    List.fold user_commands ~init:empty ~f:(fun set user_command ->
        union set (of_list @@ User_command.accounts_accessed user_command) )
  in
  let fee_transfer_participants =
    List.fold fee_transfers ~init:empty ~f:(fun set (pk, _) -> add set pk)
  in
  add (union user_command_set fee_transfer_participants) creator

let user_commands {transactions= {Transactions.user_commands; _}; _} =
  user_commands

let of_transition tracked_participants external_transition =
  let open External_transition.Validated in
  let creator = proposer external_transition in
  let protocol_state =
    { Protocol_state.previous_state_hash= parent_hash external_transition
    ; blockchain_state=
        Coda_state.Protocol_state.blockchain_state
        @@ protocol_state external_transition }
  in
  let open Result.Let_syntax in
  let%map calculated_transactions =
    Staged_ledger.Pre_diff_info.get_transactions
    @@ staged_ledger_diff external_transition
  in
  let transactions =
    List.fold calculated_transactions
      ~init:
        { Transactions.user_commands= []
        ; fee_transfers= []
        ; coinbase= Currency.Amount.zero } ~f:(fun acc_transactions -> function
      | User_command checked_user_command -> (
          let user_command = User_command.forget_check checked_user_command in
          let should_include_transaction user_command participants =
            List.exists
              (User_command.accounts_accessed user_command)
              ~f:(Public_key.Compressed.Set.mem participants)
          in
          match tracked_participants with
          | `Some interested_participants
            when not
                   (should_include_transaction user_command
                      interested_participants) ->
              acc_transactions
          | _ ->
              { acc_transactions with
                user_commands= user_command :: acc_transactions.user_commands
              } )
      | Fee_transfer fee_transfer ->
          let fee_transfer_list =
            match fee_transfer with
            | One fee_transfer1 ->
                [fee_transfer1]
            | Two (fee_transfer1, fee_transfer2) ->
                [fee_transfer1; fee_transfer2]
          in
          let fee_transfers =
            match tracked_participants with
            | `All ->
                fee_transfer_list
            | `Some interested_participants ->
                List.filter
                  ~f:(fun (pk, _) ->
                    Public_key.Compressed.Set.mem interested_participants pk )
                  fee_transfer_list
          in
          { acc_transactions with
            fee_transfers= fee_transfers @ acc_transactions.fee_transfers }
      | Coinbase {Coinbase.amount; _} ->
          { acc_transactions with
            coinbase=
              Currency.Amount.(
                Option.value_exn (add amount acc_transactions.coinbase)) } )
  in
  {creator; protocol_state; transactions}
