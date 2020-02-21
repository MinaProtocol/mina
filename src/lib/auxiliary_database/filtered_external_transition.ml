open Core
open Coda_base
open Coda_transition
open Signature_lib

module Transactions = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { user_commands: User_command.Stable.V2.t list
        ; fee_transfers: Fee_transfer.Single.Stable.V1.t list
        ; coinbase: Currency.Amount.Stable.V1.t }

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        { user_commands: User_command.Stable.V1.t list
        ; fee_transfers: Fee_transfer.Single.Stable.V1.t list
        ; coinbase: Currency.Amount.Stable.V1.t }

      let to_latest {user_commands; fee_transfers; coinbase} =
        { V2.user_commands=
            List.map ~f:User_command.Stable.V1.to_latest user_commands
        ; fee_transfers
        ; coinbase }
    end
  end]

  type t = Stable.Latest.t =
    { user_commands: User_command.t list
    ; fee_transfers: Fee_transfer.Single.t list
    ; coinbase: Currency.Amount.t }
end

module Protocol_state = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { previous_state_hash: State_hash.Stable.V1.t
        ; blockchain_state: Coda_state.Blockchain_state.Value.Stable.V1.t
        ; consensus_state: Consensus.Data.Consensus_state.Value.Stable.V1.t }

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { previous_state_hash: State_hash.t
    ; blockchain_state: Coda_state.Blockchain_state.Value.t
    ; consensus_state: Consensus.Data.Consensus_state.Value.t }
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      { creator: Public_key.Compressed.Stable.V1.t
      ; protocol_state: Protocol_state.Stable.V1.t
      ; transactions: Transactions.Stable.V2.t
      ; snark_jobs: Transaction_snark_work.Info.Stable.V1.t list
      ; proof: Proof.Stable.V1.t }

    let to_latest = Fn.id
  end

  module V1 = struct
    type t =
      { creator: Public_key.Compressed.Stable.V1.t
      ; protocol_state: Protocol_state.Stable.V1.t
      ; transactions: Transactions.Stable.V1.t
      ; snark_jobs: Transaction_snark_work.Info.Stable.V1.t list
      ; proof: Proof.Stable.V1.t }

    let to_latest {creator; protocol_state; transactions; snark_jobs; proof} =
      { V2.creator
      ; protocol_state
      ; transactions= Transactions.Stable.V1.to_latest transactions
      ; snark_jobs
      ; proof }
  end
end]

type t = Stable.Latest.t =
  { creator: Public_key.Compressed.t
  ; protocol_state: Protocol_state.t
  ; transactions: Transactions.t
  ; snark_jobs: Transaction_snark_work.Info.t list
  ; proof: Proof.t }

let participants {transactions= {user_commands; fee_transfers; _}; creator; _}
    =
  let open Account_id.Set in
  let user_command_set =
    List.fold user_commands ~init:empty ~f:(fun set user_command ->
        union set (of_list @@ User_command.accounts_accessed user_command) )
  in
  let fee_transfer_participants =
    List.fold fee_transfers ~init:empty ~f:(fun set (pk, _) ->
        add set (Account_id.create pk Token_id.default) )
  in
  add
    (union user_command_set fee_transfer_participants)
    (Account_id.create creator Token_id.default)

let participant_pks
    {transactions= {user_commands; fee_transfers; _}; creator; _} =
  let open Public_key.Compressed.Set in
  let user_command_set =
    List.fold user_commands ~init:empty ~f:(fun set user_command ->
        union set @@ of_list
        @@ List.map ~f:Account_id.public_key
        @@ User_command.accounts_accessed user_command )
  in
  let fee_transfer_participants =
    List.fold fee_transfers ~init:empty ~f:(fun set (pk, _) -> add set pk)
  in
  add (union user_command_set fee_transfer_participants) creator

let user_commands {transactions= {Transactions.user_commands; _}; _} =
  user_commands

let validate_transactions external_transition =
  let staged_ledger_diff =
    External_transition.Validated.staged_ledger_diff external_transition
  in
  Staged_ledger.Pre_diff_info.get_transactions staged_ledger_diff

let of_transition external_transition tracked_participants
    (calculated_transactions : Transaction.t list) =
  let open External_transition.Validated in
  let creator = block_producer external_transition in
  let protocol_state =
    { Protocol_state.previous_state_hash= parent_hash external_transition
    ; blockchain_state=
        External_transition.Validated.blockchain_state external_transition
    ; consensus_state=
        External_transition.Validated.consensus_state external_transition }
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
            List.exists (User_command.accounts_accessed user_command)
              ~f:(fun account_id ->
                Public_key.Compressed.Set.mem participants
                  (Account_id.public_key account_id) )
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
          let fee_transfer_list = One_or_two.to_list fee_transfer in
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
  let snark_jobs =
    List.map
      ( Staged_ledger_diff.completed_works
      @@ External_transition.Validated.staged_ledger_diff external_transition
      )
      ~f:Transaction_snark_work.info
  in
  let proof =
    External_transition.Validated.protocol_state_proof external_transition
  in
  {creator; protocol_state; transactions; snark_jobs; proof}
