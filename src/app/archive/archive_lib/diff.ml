open Mina_transition
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
  let breadcrumb_added breadcrumb =
    let ((block, _) as validated_block) =
      Breadcrumb.validated_transition breadcrumb
    in
    let commands = Mina_block.Validated.valid_commands validated_block in
    let sender_receipt_chains_from_parent_ledger =
      let senders =
        commands
        |> List.map ~f:(fun { data; _ } ->
               User_command.(fee_payer (forget_check data)))
        |> Account_id.Set.of_list
      in
      let ledger =
        Staged_ledger.ledger @@ Breadcrumb.staged_ledger breadcrumb
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
               (sender, receipt_chain_hash)))
    in
    Transition_frontier.Breadcrumb_added
      { block = With_hash.map ~f:External_transition.compose block
      ; sender_receipt_chains_from_parent_ledger
      }

  let user_commands user_commands =
    Transaction_pool { Transaction_pool.added = user_commands; removed = [] }
end
