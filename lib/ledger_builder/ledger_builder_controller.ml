open Core_kernel
open Async_kernel

module type S = sig
  include Ledger_builder_controller_intf
end

module Make (Ledger_builder : sig
  type t
end) (Merkle_root : sig
  type t
end) (Ledger : sig
  type t
end) (Net : sig
  module Ledger_builder_io :
    Coda.Ledger_builder_io_intf
    with type t := t
     and type ledger_builder := ledger_builder
     and type ledger_builder_hash := ledger_builder_hash
     and type state := state

  type t
end) =
struct
  module Config = struct
    type t =
      { keep_count: int [@default 50]
      ; parent_log: Logger.t
      ; net_deferred: Net.t Deferred.t
      ; ledger_builder_transitions:
          ( transaction_with_valid_signature list
          * state
          * ledger_builder_transition )
          Linear_pipe.Reader.t
      ; disk_location: string
      ; snark_pool: snark_pool }
    [@@deriving make]
  end

  let create (config: Config.t) =
    let%bind net = config.net_deferred in
    Net.

  type t =
    { locked_ledger_builder: Ledger_builder.t
    ; longest_branch_tip: Ledger_builder.t }
end
