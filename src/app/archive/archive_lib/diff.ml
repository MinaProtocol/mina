open Coda_transition
open Signature_lib
open Coda_base

module Transition_frontier = struct
  type t =
    | Breadcrumb_added of
        { block: (External_transition.t, State_hash.t) With_hash.t
        ; sender_receipt_chains_from_parent_ledger:
            Receipt.Chain_hash.t Public_key.Compressed.Map.t }
    | Root_transitioned of {new_: State_hash.t; garbage: State_hash.t list}
    | Bootstrap of {lost_blocks: State_hash.t list}
end

module Transaction_pool = struct
  type t = {added: Block_time.t User_command.Map.t; removed: User_command.Set.t}
end

type t =
  | Transition_frontier of Transition_frontier.t
  | Transaction_pool of Transaction_pool.t
