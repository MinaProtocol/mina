open Core_kernel
open Mina_base

type t = Block.with_hash * State_hash.t Mina_stdlib.Nonempty_list.t
[@@deriving sexp]

let to_yojson (block_with_hashes, _) =
  Block.with_hash_to_yojson block_with_hashes

let lift (b, v) =
  match v with
  | _, _, _, (`Delta_block_chain, Truth.True delta_block_chain_proof), _, _, _
    ->
      (b, delta_block_chain_proof)

let forget (b, _) = b

let remember (b, delta_block_chain_proof) =
  ( b
  , ( (`Time_received, Truth.True ())
    , (`Genesis_state, Truth.True ())
    , (`Proof, Truth.True ())
    , (`Delta_block_chain, Truth.True delta_block_chain_proof)
    , (`Frontier_dependencies, Truth.True ())
    , (`Staged_ledger_diff, Truth.True ())
    , (`Protocol_versions, Truth.True ()) ) )

let delta_block_chain_proof (_, d) = d

let valid_commands ({ With_hash.data = _, body; _ }, _) =
  Staged_ledger_diff.With_hashes_computed.commands body
  |> List.map ~f:(fun cmd ->
         (* This is safe because at this point the stage ledger diff has been
              applied successfully. *)
         let (`If_this_is_used_it_should_have_a_comment_justifying_it data) =
           User_command.to_valid_unsafe cmd.data
         in
         { cmd with data } )

let unsafe_of_trusted_block ~delta_block_chain_proof
    (`This_block_is_trusted_to_be_safe b) =
  (b, delta_block_chain_proof)

let state_hash (b, _) = State_hash.With_state_hashes.state_hash b

let state_body_hash (t, _) =
  State_hash.With_state_hashes.state_body_hash t
    ~compute_hashes:
      (Fn.compose Mina_state.Protocol_state.hashes
         (Fn.compose Header.protocol_state fst) )

let header t = t |> forget |> With_hash.data |> fst

let account_ids_accessed ~constraint_constants
    ({ With_hash.data = header, body; _ }, _) =
  let consensus_state =
    Header.protocol_state header |> Mina_state.Protocol_state.consensus_state
  in
  let transactions =
    Staged_ledger.Pre_diff_info.get_transactions_exn ~constraint_constants
      ~consensus_state body.Staged_ledger_diff.With_hashes_computed.diff
  in
  List.map transactions ~f:(fun { data = txn; status } ->
      Mina_transaction.Transaction.account_access_statuses txn status )
  |> List.concat
  |> List.dedup_and_sort
       ~compare:[%compare: Account_id.t * [ `Accessed | `Not_accessed ]]

let transactions ~constraint_constants ({ With_hash.data = header, body; _ }, _)
    =
  let consensus_state =
    Header.protocol_state header |> Mina_state.Protocol_state.consensus_state
  in
  Staged_ledger.Pre_diff_info.get_transactions_exn ~constraint_constants
    ~consensus_state body.Staged_ledger_diff.With_hashes_computed.diff

let block ((b, _) : t) : Block.t =
  Block.forget_computed_hashes b |> With_hash.data
