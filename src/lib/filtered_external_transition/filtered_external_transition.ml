open Core_kernel
open Mina_base
open Mina_transaction
open Signature_lib

module Fee_transfer_type = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Fee_transfer | Fee_transfer_via_coinbase

      let to_latest = Fn.id
    end
  end]
end

module Transactions = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { commands :
            ( User_command.Stable.V2.t
            , Transaction_hash.Stable.V1.t )
            With_hash.Stable.V1.t
            With_status.Stable.V2.t
            list
        ; fee_transfers :
            (Fee_transfer.Single.Stable.V2.t * Fee_transfer_type.Stable.V1.t)
            list
        ; coinbase : Currency.Amount.Stable.V1.t
        ; coinbase_receiver : Public_key.Compressed.Stable.V1.t option
        }

      let to_latest = Fn.id
    end
  end]
end

module Protocol_state = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { previous_state_hash : State_hash.Stable.V1.t
        ; blockchain_state : Mina_state.Blockchain_state.Value.Stable.V2.t
        ; consensus_state : Consensus.Data.Consensus_state.Value.Stable.V1.t
        }

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      { creator : Public_key.Compressed.Stable.V1.t
      ; winner : Public_key.Compressed.Stable.V1.t
      ; protocol_state : Protocol_state.Stable.V2.t
      ; transactions : Transactions.Stable.V2.t
      ; snark_jobs : Transaction_snark_work.Info.Stable.V2.t list
      ; proof : Proof.Stable.V2.t
      }

    let to_latest = Fn.id
  end
end]

let participants
    { transactions = { commands; fee_transfers; _ }; creator; winner; _ } =
  let open Account_id.Set in
  let user_command_set =
    List.fold commands ~init:empty ~f:(fun set user_command ->
        union set
          (of_list @@ User_command.accounts_referenced user_command.data.data) )
  in
  let fee_transfer_participants =
    List.fold fee_transfers ~init:empty ~f:(fun set (ft, _) ->
        add set (Fee_transfer.Single.receiver ft) )
  in
  add
    (add
       (union user_command_set fee_transfer_participants)
       (Account_id.create creator Token_id.default) )
    (Account_id.create winner Token_id.default)

let participant_pks
    { transactions = { commands; fee_transfers; _ }; creator; winner; _ } =
  let open Public_key.Compressed.Set in
  let user_command_set =
    List.fold commands ~init:empty ~f:(fun set user_command ->
        union set @@ of_list
        @@ List.map ~f:Account_id.public_key
        @@ User_command.accounts_referenced user_command.data.data )
  in
  let fee_transfer_participants =
    List.fold fee_transfers ~init:empty ~f:(fun set (ft, _) ->
        add set ft.receiver_pk )
  in
  add (add (union user_command_set fee_transfer_participants) creator) winner

let commands { transactions = { Transactions.commands; _ }; _ } = commands

let validate_transactions block =
  let consensus_state =
    block |> Mina_block.header |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.consensus_state
  in
  let open Consensus.Data in
  let coinbase_receiver = Consensus_state.coinbase_receiver consensus_state in
  let supercharge_coinbase =
    Consensus_state.supercharge_coinbase consensus_state
  in
  let staged_ledger_diff =
    block |> Mina_block.body |> Mina_block.Body.staged_ledger_diff
  in
  Staged_ledger.Pre_diff_info.get_transactions ~coinbase_receiver
    ~supercharge_coinbase staged_ledger_diff

let filter_protocol_state protocol_state : Protocol_state.t =
  Mina_state.Protocol_state.
    { previous_state_hash = previous_state_hash protocol_state
    ; blockchain_state = blockchain_state protocol_state
    ; consensus_state = consensus_state protocol_state
    }

let of_transition block tracked_participants
    (calculated_transactions : Transaction.t With_status.t list) =
  let header = Mina_block.header block in
  let staged_ledger_diff =
    block |> Mina_block.body |> Mina_block.Body.staged_ledger_diff
  in
  let consensus_state =
    header |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.consensus_state
  in
  let protocol_state =
    header |> Mina_block.Header.protocol_state |> filter_protocol_state
  in
  let transactions =
    List.fold calculated_transactions
      ~init:
        { Transactions.commands = []
        ; fee_transfers = []
        ; coinbase = Currency.Amount.zero
        ; coinbase_receiver = None
        } ~f:(fun acc_transactions -> function
      | { data = Command command; status } -> (
          let command = (command :> User_command.t) in
          let should_include_transaction command participants =
            List.exists (User_command.accounts_referenced command)
              ~f:(fun account_id ->
                Public_key.Compressed.Set.mem participants
                  (Account_id.public_key account_id) )
          in
          match tracked_participants with
          | `Some interested_participants
            when not
                   (should_include_transaction command interested_participants)
            ->
              acc_transactions
          | `All | `Some _ ->
              (* Should include this command. *)
              { acc_transactions with
                commands =
                  { With_status.data =
                      { With_hash.data = command
                      ; hash = Transaction_hash.hash_command command
                      }
                  ; status
                  }
                  :: acc_transactions.commands
              } )
      | { data = Fee_transfer fee_transfer; _ } ->
          let fee_transfer_list =
            List.map (Mina_base.Fee_transfer.to_list fee_transfer) ~f:(fun f ->
                (f, Fee_transfer_type.Fee_transfer) )
          in
          let fee_transfers =
            match tracked_participants with
            | `All ->
                fee_transfer_list
            | `Some interested_participants ->
                List.filter
                  ~f:(fun ({ receiver_pk = pk; _ }, _) ->
                    Public_key.Compressed.Set.mem interested_participants pk )
                  fee_transfer_list
          in
          { acc_transactions with
            fee_transfers = fee_transfers @ acc_transactions.fee_transfers
          }
      | { data = Coinbase { Coinbase.amount; fee_transfer; receiver }; _ } ->
          let fee_transfer =
            Option.map
              ~f:(fun ft ->
                ( Coinbase_fee_transfer.to_fee_transfer ft
                , Fee_transfer_type.Fee_transfer_via_coinbase ) )
              fee_transfer
          in
          let fee_transfers =
            List.append
              (Option.to_list fee_transfer)
              acc_transactions.fee_transfers
          in
          { acc_transactions with
            fee_transfers
          ; coinbase_receiver = Some receiver
          ; coinbase =
              Currency.Amount.(
                Option.value_exn (add amount acc_transactions.coinbase))
          } )
  in
  let snark_jobs =
    staged_ledger_diff |> Staged_ledger_diff.completed_works
    |> List.map ~f:Transaction_snark_work.info
  in
  let open Consensus.Data in
  let creator = Consensus_state.block_creator consensus_state in
  let winner = Consensus_state.block_stake_winner consensus_state in
  let proof = Mina_block.Header.protocol_state_proof header in
  { creator; winner; protocol_state; transactions; snark_jobs; proof }
