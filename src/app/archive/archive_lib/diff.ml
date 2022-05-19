open Mina_block
open Core_kernel
open Mina_base
module Breadcrumb = Transition_frontier.Breadcrumb

(* TODO: We should be able to fully deserialize and serialize via json *)

(* these types are serialized for communication between the daemon and archive node,
   which should be compiled with the same sources

   the RPC is itself not versioned, so these types do not need to be versioned
*)

module Transition_frontier = struct
  type t =
    | Breadcrumb_added of
        { block :
            External_transition.Raw.Stable.Latest.t
            State_hash.With_state_hashes.Stable.Latest.t
              (* ledger index, account *)
        ; accounts_accessed : (int * Mina_base.Account.Stable.Latest.t) list
        ; accounts_created :
            (Account_id.Stable.Latest.t * Currency.Fee.Stable.Latest.t) list
        ; tokens_used :
            (Token_id.Stable.Latest.t * Account_id.Stable.Latest.t option) list
        ; sender_receipt_chains_from_parent_ledger :
            (Account_id.Stable.Latest.t * Receipt.Chain_hash.Stable.Latest.t)
            list
        }
    | Root_transitioned of
        Transition_frontier.Diff.Root_transition.Lite.Stable.Latest.t
    | Bootstrap of { lost_blocks : State_hash.Stable.Latest.t list }
  [@@deriving bin_io_unversioned]
end

module Transaction_pool = struct
  type t =
    { added : User_command.Stable.Latest.t list
    ; removed : User_command.Stable.Latest.t list
    }
  [@@deriving bin_io_unversioned]
end

type t =
  | Transition_frontier of Transition_frontier.t
  | Transaction_pool of Transaction_pool.t
[@@deriving bin_io_unversioned]

module Builder = struct
  let breadcrumb_added ~(precomputed_values : Precomputed_values.t) breadcrumb =
    let validated_block = Breadcrumb.validated_transition breadcrumb in
    let commands = Mina_block.Validated.valid_commands validated_block in
    let staged_ledger = Breadcrumb.staged_ledger breadcrumb in
    let ledger = Staged_ledger.ledger staged_ledger in
    let sender_receipt_chains_from_parent_ledger =
      let senders =
        commands
        |> List.map ~f:(fun { data; _ } ->
               User_command.(fee_payer (forget_check data)) )
        |> Account_id.Set.of_list
      in
      Set.to_list senders
      |> List.map ~f:(fun sender ->
             Option.value_exn
               (let open Option.Let_syntax in
               let%bind ledger_location =
                 Mina_ledger.Ledger.location_of_account ledger sender
               in
               let%map { receipt_chain_hash; _ } =
                 Mina_ledger.Ledger.get ledger ledger_location
               in
               (sender, receipt_chain_hash)) )
    in
    let block_with_hash = Mina_block.Validated.forget validated_block in
    let block = With_hash.data block_with_hash in
    let account_ids_accessed = Mina_block.account_ids_accessed block in
    let accounts_accessed =
      List.filter_map account_ids_accessed ~f:(fun acct_id ->
          (* an accessed account may not be the ledger *)
          let%bind.Option index =
            Option.try_with (fun () ->
                Mina_ledger.Ledger.index_of_account_exn ledger acct_id )
          in
          let account = Mina_ledger.Ledger.get_at_index_exn ledger index in
          Some (index, account) )
    in
    let accounts_created =
      let account_creation_fee =
        precomputed_values.constraint_constants.account_creation_fee
      in
      let previous_block_state_hash =
        Mina_block.header block |> Header.protocol_state
        |> Mina_state.Protocol_state.previous_state_hash
      in
      List.map
        (Staged_ledger.latest_block_accounts_created staged_ledger
           ~previous_block_state_hash ) ~f:(fun acct_id ->
          (acct_id, account_creation_fee) )
    in
    let tokens_used =
      let unique_tokens =
        List.map account_ids_accessed ~f:Account_id.token_id
        |> List.dedup_and_sort ~compare:Token_id.compare
      in
      List.map unique_tokens ~f:(fun token_id ->
          let owner = Mina_ledger.Ledger.token_owner ledger token_id in
          (token_id, owner) )
    in
    Transition_frontier.Breadcrumb_added
      { block = With_hash.map ~f:External_transition.compose block_with_hash
      ; accounts_accessed
      ; accounts_created
      ; tokens_used
      ; sender_receipt_chains_from_parent_ledger
      }

  let user_commands user_commands =
    Transaction_pool { Transaction_pool.added = user_commands; removed = [] }
end
