open Core_kernel
open Mina_base
open Mina_transition
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
    module V1 = struct
      type t =
        { commands:
            ( User_command.Stable.V1.t
            , Transaction_hash.Stable.V1.t )
            With_hash.Stable.V1.t
            With_status.Stable.V1.t
            list
        ; fee_transfers:
            (Fee_transfer.Single.Stable.V1.t * Fee_transfer_type.Stable.V1.t)
            list
        ; coinbase: Currency.Amount.Stable.V1.t
        ; coinbase_receiver: Public_key.Compressed.Stable.V1.t option }

      let to_latest = Fn.id
    end
  end]
end

module Protocol_state = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { previous_state_hash: State_hash.Stable.V1.t
        ; blockchain_state: Mina_state.Blockchain_state.Value.Stable.V1.t
        ; consensus_state: Consensus.Data.Consensus_state.Value.Stable.V1.t }

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { creator: Public_key.Compressed.Stable.V1.t
      ; winner: Public_key.Compressed.Stable.V1.t
      ; protocol_state: Protocol_state.Stable.V1.t
      ; transactions: Transactions.Stable.V1.t
      ; snark_jobs: Transaction_snark_work.Info.Stable.V1.t list
      ; proof: Proof.Stable.V1.t }

    let to_latest = Fn.id
  end
end]

let participants ~next_available_token
    {transactions= {commands; fee_transfers; _}; creator; winner; _} =
  let open Account_id.Set in
  let _next_available_token, user_command_set =
    List.fold commands ~init:(next_available_token, empty)
      ~f:(fun (next_available_token, set) user_command ->
        ( User_command.next_available_token user_command.data.data
            next_available_token
        , union set
            ( of_list
            @@ User_command.accounts_accessed ~next_available_token
                 user_command.data.data ) ) )
  in
  let fee_transfer_participants =
    List.fold fee_transfers ~init:empty ~f:(fun set (ft, _) ->
        add set (Fee_transfer.Single.receiver ft) )
  in
  add
    (add
       (union user_command_set fee_transfer_participants)
       (Account_id.create creator Token_id.default))
    (Account_id.create winner Token_id.default)

let participant_pks
    {transactions= {commands; fee_transfers; _}; creator; winner; _} =
  let open Public_key.Compressed.Set in
  let user_command_set =
    List.fold commands ~init:empty ~f:(fun set user_command ->
        union set @@ of_list
        @@ List.map ~f:Account_id.public_key
        @@ User_command.accounts_accessed
             ~next_available_token:Token_id.invalid user_command.data.data )
  in
  let fee_transfer_participants =
    List.fold fee_transfers ~init:empty ~f:(fun set (ft, _) ->
        add set ft.receiver_pk )
  in
  add (add (union user_command_set fee_transfer_participants) creator) winner

let commands {transactions= {Transactions.commands; _}; _} = commands

let validate_transactions ((transition_with_hash, _validity) as transition) =
  let staged_ledger_diff =
    External_transition.Validated.staged_ledger_diff transition
  in
  let external_transition = With_hash.data transition_with_hash in
  let coinbase_receiver =
    External_transition.coinbase_receiver external_transition
  in
  let supercharge_coinbase =
    External_transition.supercharge_coinbase external_transition
  in
  Staged_ledger.Pre_diff_info.get_transactions ~coinbase_receiver
    ~supercharge_coinbase staged_ledger_diff

let of_transition external_transition tracked_participants
    (calculated_transactions : Transaction.t With_status.t list) =
  let open External_transition.Validated in
  let creator = block_producer external_transition in
  let winner = block_winner external_transition in
  let protocol_state =
    { Protocol_state.previous_state_hash= parent_hash external_transition
    ; blockchain_state=
        External_transition.Validated.blockchain_state external_transition
    ; consensus_state=
        External_transition.Validated.consensus_state external_transition }
  in
  let next_available_token =
    protocol_state.blockchain_state.snarked_next_available_token
  in
  let transactions, _next_available_token =
    List.fold calculated_transactions
      ~init:
        ( { Transactions.commands= []
          ; fee_transfers= []
          ; coinbase= Currency.Amount.zero
          ; coinbase_receiver= None }
        , next_available_token )
      ~f:(fun (acc_transactions, next_available_token) -> function
        | {data= Command (Snapp_command _); _} -> failwith "Not implemented"
        | {data= Command command; status} -> (
            let command = (command :> User_command.t) in
            let should_include_transaction command participants =
              List.exists
                (User_command.accounts_accessed ~next_available_token command)
                ~f:(fun account_id ->
                  Public_key.Compressed.Set.mem participants
                    (Account_id.public_key account_id) )
            in
            match tracked_participants with
            | `Some interested_participants
              when not
                     (should_include_transaction command
                        interested_participants) ->
                ( acc_transactions
                , User_command.next_available_token command
                    next_available_token )
            | `All | `Some _ ->
                (* Should include this command. *)
                ( { acc_transactions with
                    commands=
                      { With_status.data=
                          { With_hash.data= command
                          ; hash= Transaction_hash.hash_command command }
                      ; status }
                      :: acc_transactions.commands }
                , User_command.next_available_token command
                    next_available_token ) )
        | {data= Fee_transfer fee_transfer; _} ->
            let fee_transfer_list =
              List.map (Mina_base.Fee_transfer.to_list fee_transfer)
                ~f:(fun f -> (f, Fee_transfer_type.Fee_transfer))
            in
            let fee_transfers =
              match tracked_participants with
              | `All ->
                  fee_transfer_list
              | `Some interested_participants ->
                  List.filter
                    ~f:(fun ({receiver_pk= pk; _}, _) ->
                      Public_key.Compressed.Set.mem interested_participants pk
                      )
                    fee_transfer_list
            in
            ( { acc_transactions with
                fee_transfers= fee_transfers @ acc_transactions.fee_transfers
              }
            , next_available_token )
        | {data= Coinbase {Coinbase.amount; fee_transfer; receiver}; _} ->
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
            ( { acc_transactions with
                fee_transfers
              ; coinbase_receiver= Some receiver
              ; coinbase=
                  Currency.Amount.(
                    Option.value_exn (add amount acc_transactions.coinbase)) }
            , next_available_token ) )
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
  {creator; winner; protocol_state; transactions; snark_jobs; proof}
