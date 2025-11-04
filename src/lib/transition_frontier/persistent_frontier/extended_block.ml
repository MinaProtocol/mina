open Core_kernel
open Mina_base

module Update_coinbase_stack_and_get_data_result_or_commands = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        | Update_coinbase_stack_and_get_data_result of
            Staged_ledger.Update_coinbase_stack_and_get_data_result.Stable.V1.t
        | Commands of User_command.Stable.V2.t With_status.Stable.V2.t list

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t =
      { header : Mina_block.Header.Stable.V2.t
      ; diff :
          ( Transaction_snark_work.Stable.V2.t
          , unit )
          Staged_ledger_diff.Pre_diff_two.Stable.V2.t
          * ( Transaction_snark_work.Stable.V2.t
            , unit )
            Staged_ledger_diff.Pre_diff_one.Stable.V2.t
            option
            (* RE [diff] field: it is a weird way to store transactions:
               * commands field will be represented as a list of [unit] entries.
               * But we store actual commands separately,
               * and this representation is still lightweight.
               * TODO In future worth considering not storing a list of [()]s.
            *)
      ; update_coinbase_stack_and_get_data_result :
          Update_coinbase_stack_and_get_data_result_or_commands.Stable.V1.t
      ; state_body_hash : State_body_hash.Stable.V1.t
      }

    let to_latest = Fn.id
  end
end]

let update_coinbase_stack_and_get_data_result = function
  | { Stable.Latest.update_coinbase_stack_and_get_data_result =
        Update_coinbase_stack_and_get_data_result res
    ; _
    } ->
      Some res
  | _ ->
      None

let to_block
    { Stable.Latest.header; diff; update_coinbase_stack_and_get_data_result; _ }
    =
  let cmds =
    match update_coinbase_stack_and_get_data_result with
    | Update_coinbase_stack_and_get_data_result (_, witnesses, _, _, _) ->
        let witness_to_cmd tx =
          Mina_transaction_logic.Transaction_applied.With_account_update_digests
          .command_with_status
          @@ Transaction_snark_scan_state.Transaction_with_witness
             .With_account_update_digests
             .Stable
             .Latest
             .transaction_with_info tx
        in
        List.filter_map ~f:witness_to_cmd witnesses
    | Commands commands ->
        commands
  in
  let diff' = Staged_ledger_diff.Diff.replace_cmds_exn cmds diff in
  Mina_block.Stable.Latest.create ~header
    ~body:
      { Staged_ledger_diff.Body.Stable.Latest.staged_ledger_diff =
          { diff = diff' }
      }

let take_hashes_from_witnesses ~proof_cache_db
    ~(witnesses : Transaction_snark_scan_state.Transaction_with_witness.t list)
    block =
  let header = Mina_block.Stable.Latest.header block in
  let { Staged_ledger_diff.Body.Stable.Latest.staged_ledger_diff = { diff } } =
    Mina_block.Stable.Latest.body block
  in
  let witness_to_cmd tx =
    Mina_transaction_logic.Transaction_applied.transaction_with_status
      tx
        .Transaction_snark_scan_state.Transaction_with_witness
         .transaction_with_info
    |> function
    | { With_status.data = Mina_transaction.Transaction.Command tx; status } ->
        Some { With_status.data = tx; status }
    | _ ->
        None
  in
  let cmds = List.filter_map ~f:witness_to_cmd witnesses in
  let diff' =
    Staged_ledger_diff.Diff.(
      map
        ~f1:(Transaction_snark_work.write_all_proofs_to_disk ~proof_cache_db)
        ~f2:Fn.id diff
      |> replace_cmds_exn cmds)
  in
  let body' = Staged_ledger_diff.Body.create { diff = diff' } in
  Mina_block.create ~header ~body:body'

let of_validate_block ?update_coinbase_stack_and_get_data_result
    (block : Mina_block.Validated.t) =
  let diff =
    Mina_block.Validated.body block
    |> Staged_ledger_diff.Body.staged_ledger_diff
  in
  let read_proofs = With_status.map ~f:User_command.read_all_proofs_from_disk in
  let update_coinbase_stack_and_get_data_result =
    match update_coinbase_stack_and_get_data_result with
    | Some upd ->
        Update_coinbase_stack_and_get_data_result_or_commands.Stable.Latest
        .Update_coinbase_stack_and_get_data_result
          (Staged_ledger.Update_coinbase_stack_and_get_data_result
           .read_all_proofs_from_disk upd )
    | None ->
        Commands (Staged_ledger_diff.commands diff |> List.map ~f:read_proofs)
  in
  { Stable.Latest.header =
      Mina_block.Validated.header block
      (* |> With_hash.data |> Mina_block.read_all_proofs_from_disk *)
  ; update_coinbase_stack_and_get_data_result
  ; state_body_hash = Mina_block.Validated.state_body_hash block
  ; diff =
      Staged_ledger_diff.Diff.map
        ~f1:Transaction_snark_work.read_all_proofs_from_disk ~f2:ignore
        diff.diff
  }
