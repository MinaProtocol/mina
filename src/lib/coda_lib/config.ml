open Async_kernel
open Coda_base
open Auxiliary_database
open Signature_lib

(* TODO: Pass banlist to modules discussed in Ban Reasons issue: https://github.com/CodaProtocol/coda/issues/852 *)

module Snark_worker_config = struct
  type t =
    { initial_snark_worker_key: Public_key.Compressed.t option
    ; shutdown_on_disconnect: bool }
end

(** If ledger_db_location is None, will auto-generate a db based on a UUID *)
type t =
  { conf_dir: string
  ; logger: Logger.t
  ; pids: Child_processes.Termination.t
  ; trust_system: Trust_system.t
  ; monitor: Monitor.t option
  ; initial_propose_keypairs: Keypair.Set.t
  ; work_selection_method: (module Work_selector.Selection_method_intf)
  ; snark_worker_config: Snark_worker_config.t
  ; work_reassignment_wait: int
  ; net_config: Coda_networking.Config.t
  ; snark_pool_disk_location: string
  ; wallets_disk_location: string
  ; ledger_db_location: string option
  ; transition_frontier_location: string option
  ; staged_ledger_transition_backup_capacity: int [@default 10]
  ; time_controller: Block_time.Controller.t
  ; receipt_chain_database: Receipt_chain_database.t
  ; transaction_database: Transaction_database.t
  ; external_transition_database: External_transition_database.t
  ; snark_work_fee: Currency.Fee.t
  ; consensus_local_state: Consensus.Data.Local_state.t
  ; is_archive_node: bool [@default false] }
[@@deriving make]
