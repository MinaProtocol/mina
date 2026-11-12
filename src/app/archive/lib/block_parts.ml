(* What the archive records about a block, whatever version the block came
   in. Each hash here is derived by the rules of the block's own version; the
   processor stores them as given rather than deriving them again from types
   of the latest version, which would give the wrong hash for an older
   block. *)

open Core_kernel
open Mina_base
open Mina_transaction
open Mina_state

type transaction =
  | Command of { command : User_command.t; hash : Transaction_hash.t }
  | Fee_transfer of
      { fee_transfer : Fee_transfer.t
      ; hashes : Transaction_hash.t list
            (** The hashes of the single fee transfers, in the order of
                [Fee_transfer.to_numbered_list]. *)
      }
  | Coinbase of
      { coinbase : Coinbase.t
      ; hash : Transaction_hash.t
      ; fee_transfer_hash : Transaction_hash.t option
            (** The hash of the fee transfer the coinbase pays, if any. *)
      }

type t =
  { state_hash : State_hash.t
  ; parent_hash : State_hash.t
  ; creator : Signature_lib.Public_key.Compressed.t
  ; block_winner : Signature_lib.Public_key.Compressed.t
  ; last_vrf_output : string
  ; snarked_ledger_hash : Frozen_ledger_hash.t
  ; staking_epoch_data : Epoch_data.Value.t
  ; next_epoch_data : Epoch_data.Value.t
  ; min_window_density : Mina_numbers.Length.t
  ; sub_window_densities : Mina_numbers.Length.t list
  ; total_currency : Currency.Amount.t
  ; ledger_hash : Ledger_hash.t
  ; height : Mina_numbers.Length.t
  ; global_slot_since_hard_fork : Mina_numbers.Global_slot_since_hard_fork.t
  ; global_slot_since_genesis : Mina_numbers.Global_slot_since_genesis.t
  ; timestamp : Block_time.t
  ; protocol_version : Protocol_version.t
  ; proposed_protocol_version : Protocol_version.t option
  ; transactions : transaction With_status.t list Lazy.t
        (** Lazy, so that a block already in the archive costs nothing to
            derive. *)
  }

let transaction_of_latest ~command_hash : Transaction.t -> transaction =
  function
  | Command command ->
      Command { command; hash = command_hash command }
  | Fee_transfer fee_transfer ->
      Fee_transfer
        { fee_transfer
        ; hashes =
            Fee_transfer.to_numbered_list fee_transfer
            |> List.map ~f:(fun (_, single) ->
                   Transaction_hash.hash_fee_transfer single )
        }
  | Coinbase coinbase ->
      Coinbase
        { coinbase
        ; hash = Transaction_hash.hash_coinbase coinbase
        ; fee_transfer_hash =
            Coinbase.fee_transfer coinbase
            |> Option.map ~f:(fun { Coinbase.Fee_transfer.receiver_pk; fee } ->
                   Fee_transfer.Single.create ~receiver_pk ~fee
                     ~fee_token:Token_id.default
                   |> Transaction_hash.hash_fee_transfer )
        }

(** The parts of a block, from its protocol state, of whatever version, and
    [get_transactions], which gives its transactions from its coinbase
    receiver and whether its coinbase is supercharged, with the hashes of its
    commands given by [command_hash]. *)
let of_protocol_state ~command_hash ~state_hash ~protocol_state
    ~get_transactions ~protocol_version ~proposed_protocol_version =
  let consensus_state = Protocol_state.consensus_state protocol_state in
  let blockchain_state = Protocol_state.blockchain_state protocol_state in
  let transactions =
    lazy
      (let coinbase_receiver =
         Consensus.Data.Consensus_state.coinbase_receiver consensus_state
       in
       let supercharge_coinbase =
         Consensus.Data.Consensus_state.supercharge_coinbase consensus_state
       in
       match get_transactions ~coinbase_receiver ~supercharge_coinbase with
       | Ok transactions ->
           List.map transactions
             ~f:(With_status.map ~f:(transaction_of_latest ~command_hash))
       | Error e ->
           Error.raise (Staged_ledger.Pre_diff_info.Error.to_error e) )
  in
  { state_hash
  ; parent_hash = Protocol_state.previous_state_hash protocol_state
  ; creator = Consensus.Data.Consensus_state.block_creator consensus_state
  ; block_winner =
      Consensus.Data.Consensus_state.block_stake_winner consensus_state
  ; last_vrf_output =
      Consensus.Data.Consensus_state.last_vrf_output consensus_state
  ; snarked_ledger_hash = Blockchain_state.snarked_ledger_hash blockchain_state
  ; staking_epoch_data =
      Consensus.Data.Consensus_state.staking_epoch_data consensus_state
  ; next_epoch_data =
      Consensus.Data.Consensus_state.next_epoch_data consensus_state
  ; min_window_density =
      Consensus.Data.Consensus_state.min_window_density consensus_state
  ; sub_window_densities =
      Consensus.Data.Consensus_state.sub_window_densities consensus_state
  ; total_currency =
      Consensus.Data.Consensus_state.total_currency consensus_state
  ; ledger_hash =
      Blockchain_state.staged_ledger_hash blockchain_state
      |> Staged_ledger_hash.ledger_hash
  ; height = Consensus.Data.Consensus_state.blockchain_length consensus_state
  ; global_slot_since_hard_fork =
      Consensus.Data.Consensus_state.curr_global_slot consensus_state
  ; global_slot_since_genesis =
      Consensus.Data.Consensus_state.global_slot_since_genesis consensus_state
  ; timestamp = Blockchain_state.timestamp blockchain_state
  ; protocol_version
  ; proposed_protocol_version
  ; transactions
  }

(** The parts of a block of the latest version. *)
let of_latest ~constraint_constants ~state_hash
    ~(protocol_state : Protocol_state.Value.t)
    ~(staged_ledger_diff : Staged_ledger_diff.t) ~protocol_version
    ~proposed_protocol_version =
  of_protocol_state ~command_hash:Transaction_hash.hash_command_with_hashes
    ~state_hash ~protocol_state
    ~get_transactions:(fun ~coinbase_receiver ~supercharge_coinbase ->
      Staged_ledger.Pre_diff_info.get_transactions ~constraint_constants
        ~coinbase_receiver ~supercharge_coinbase staged_ledger_diff )
    ~protocol_version ~proposed_protocol_version

let of_precomputed_v5 ~constraint_constants ~proof_cache_db
    (t : Mina_block.Precomputed.Stable.V5.t) =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let staged_ledger_diff =
    Staged_ledger_diff.write_all_proofs_to_disk ~signature_kind ~proof_cache_db
      t.staged_ledger_diff
  in
  of_latest ~constraint_constants
    ~state_hash:
      (Mina_block.Precomputed.Versioned.state_hashes (V5 t)).state_hash
    ~protocol_state:t.protocol_state ~staged_ledger_diff
    ~protocol_version:t.protocol_version
    ~proposed_protocol_version:t.proposed_protocol_version

(* The protocol state and staged ledger diff are read at the versions a V4
   block carries, so that a later change to either stops this compiling,
   rather than letting a V4 block be read by the rules of a newer version. *)
let of_precomputed_v4 ~constraint_constants ~proof_cache_db
    (t : Mina_block.Precomputed.Stable.V4.t) =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  of_protocol_state ~command_hash:Transaction_hash.hash_command_with_hashes
    ~state_hash:
      (Mina_block.Precomputed.Versioned.state_hashes (V4 t)).state_hash
    ~protocol_state:
      (Protocol_state.Value.Stable.V3.to_latest
         (t.protocol_state : Protocol_state.Value.Stable.V3.t) )
    ~get_transactions:(fun ~coinbase_receiver ~supercharge_coinbase ->
      Staged_ledger.Pre_diff_info.get_transactions_stable_v3
        ~constraint_constants ~coinbase_receiver ~supercharge_coinbase
        (t.staged_ledger_diff : Staged_ledger_diff.Stable.V3.t)
      |> Result.map
           ~f:
             (List.map
                ~f:
                  (With_status.map
                     ~f:
                       (Transaction.write_all_proofs_to_disk ~signature_kind
                          ~proof_cache_db ) ) ) )
    ~protocol_version:t.protocol_version
    ~proposed_protocol_version:t.proposed_protocol_version

(* The coinbase of the Berkeley era on mainnet, which the Mesa hard fork
   halved along with the slot time. A block doesn't record its coinbase, so a
   V3 block's transactions need it in place of the current one. *)
let berkeley_coinbase_amount = Currency.Amount.of_mina_int_exn 720

(* A V3 block's transactions are derived as a V4 block's are, from its diff
   converted to the version a V4 block carries, which only extends zkApp
   states. Each command takes the Berkeley hash of the command it was
   converted from, found by the latest hash of the converted command. *)
let of_precomputed_v3 ~constraint_constants ~proof_cache_db
    (t : Mina_block.Precomputed.V3.t) =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let berkeley_hashes =
    lazy
      (let two, one =
         Berkeley_types.Diff.commands_with_hashes t.staged_ledger_diff
       in
       let { Staged_ledger_diff.Pre_diff_two.commands; _ } = two in
       let one_commands =
         Option.value_map one ~default:[]
           ~f:(fun { Staged_ledger_diff.Pre_diff_one.commands; _ } -> commands)
       in
       List.map (commands @ one_commands)
         ~f:(fun { With_status.data = command, hash; _ } ->
           ( Transaction_hash.hash_command
               (Berkeley_types.User_command.to_mesa command)
           , hash ) )
       |> Transaction_hash.Map.of_alist_exn )
  in
  of_protocol_state
    ~command_hash:(fun command ->
      Map.find_exn
        (Lazy.force berkeley_hashes)
        (Transaction_hash.hash_command_with_hashes command) )
    ~state_hash:
      (Mina_block.Precomputed.Versioned.state_hashes (V3 t)).state_hash
    ~protocol_state:
      (Protocol_state.Value.Stable.V3.to_latest
         (t.protocol_state : Protocol_state.Value.Stable.V3.t) )
    ~get_transactions:(fun ~coinbase_receiver ~supercharge_coinbase ->
      Staged_ledger.Pre_diff_info.get_transactions_stable_v3
        ~constraint_constants:
          { constraint_constants with
            coinbase_amount = berkeley_coinbase_amount
          }
        ~coinbase_receiver ~supercharge_coinbase
        (Berkeley_types.Diff.to_mesa t.staged_ledger_diff)
      |> Result.map
           ~f:
             (List.map
                ~f:
                  (With_status.map
                     ~f:
                       (Transaction.write_all_proofs_to_disk ~signature_kind
                          ~proof_cache_db ) ) ) )
    ~protocol_version:t.protocol_version
    ~proposed_protocol_version:t.proposed_protocol_version

let of_precomputed ~constraint_constants ~proof_cache_db :
    Mina_block.Precomputed.Versioned.t -> t = function
  | V5 t ->
      of_precomputed_v5 ~constraint_constants ~proof_cache_db t
  | V4 t ->
      of_precomputed_v4 ~constraint_constants ~proof_cache_db t
  | V3 t ->
      of_precomputed_v3 ~constraint_constants ~proof_cache_db t
