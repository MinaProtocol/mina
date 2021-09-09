open Mina_transition
open Core_kernel
open Mina_base
module Breadcrumb = Transition_frontier.Breadcrumb

(* TODO: We should be able to fully deserialize and serialize via json *)

module Transition_frontier = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Breadcrumb_added of
            { block:
                ( External_transition.Stable.V1.t
                , State_hash.Stable.V1.t )
                With_hash.Stable.V1.t
            ; sender_receipt_chains_from_parent_ledger:
                (Account_id.Stable.V1.t * Receipt.Chain_hash.Stable.V1.t) list
            }
        | Root_transitioned of
            Transition_frontier.Diff.Root_transition.Lite.Stable.V1.t
        | Bootstrap of {lost_blocks: State_hash.Stable.V1.t list}

      let to_latest = Fn.id
    end
  end]
end

module Transaction_pool = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { added: User_command.Stable.V1.t list
        ; removed: User_command.Stable.V1.t list }

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      | Transition_frontier of Transition_frontier.Stable.V1.t
      | Transaction_pool of Transaction_pool.Stable.V1.t

    let to_latest = Fn.id
  end
end]

module Builder = struct
  let breadcrumb_added breadcrumb =
    let ((block, _) as validated_block) =
      Breadcrumb.validated_transition breadcrumb
    in
    let commands = External_transition.Validated.commands validated_block in
    let sender_receipt_chains_from_parent_ledger =
      let senders =
        commands
        |> List.map ~f:(fun {data; _} ->
               User_command.(fee_payer (forget_check data)) )
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
                 Ledger.location_of_account ledger sender
               in
               let%map {receipt_chain_hash; _} =
                 Ledger.get ledger ledger_location
               in
               (sender, receipt_chain_hash)) )
    in
    Transition_frontier.Breadcrumb_added
      {block; sender_receipt_chains_from_parent_ledger}

  let user_commands user_commands =
    Transaction_pool {Transaction_pool.added= user_commands; removed= []}
end
