open Core_kernel
open Async_kernel

module type S = sig
  include Coda.Ledger_builder_controller_intf
end

module Make (Ledger_builder_hash : sig
  type t
end) (Ledger_builder : sig
  type t [@@deriving bin_io]

  val create : unit -> t
end) (Ledger_builder_transition : sig
  type t
end) (Ledger_hash : sig
  type t [@@deriving bin_io]
end) (Ledger : sig
  type t

  val merkle_root : t -> Ledger_hash.t
end) (State : sig
  type t
end) (Valid_transaction : sig
  type t
end) (Net : sig
  type t

  module Ledger_builder_io :
    Coda.Ledger_builder_io_intf
    with type net := t
     and type ledger_builder := Ledger_builder.t
     and type ledger_builder_hash := Ledger_builder_hash.t
     and type state := State.t
end) (Snark_pool : sig
  type t
end)
(Store : Storage.With_checksum_intf) =
struct
  module Config = struct
    type t =
      { keep_count: int [@default 50]
      ; parent_log: Logger.t
      ; net_deferred: Net.t Deferred.t
      ; ledger_builder_transitions:
          (Valid_transaction.t list * State.t * Ledger_builder_transition.t)
          Linear_pipe.Reader.t
      ; genesis_ledger: Ledger.t
      ; disk_location: string
      ; snark_pool: Snark_pool.t }
    [@@deriving make]
  end

  module State = struct
    type t =
      { locked_ledger_builder: Ledger_hash.t * Ledger_builder.t
      ; longest_branch_tip: Ledger_hash.t * Ledger_builder.t }
    [@@deriving bin_io]

    let create genesis_ledger : t =
      let root = Ledger.merkle_root genesis_ledger in
      { locked_ledger_builder= (root, Ledger_builder.create ())
      ; longest_branch_tip= (root, Ledger_builder.create ()) }
  end

  type t =
    {ledger_builder_io: Net.Ledger_builder_io.t; log: Logger.t; state: State.t}

  let create (config: Config.t) =
    let log = Logger.child config.parent_log "ledger_builder_controller" in
    let storage_controller =
      Store.Controller.create ~parent_log:log [%bin_type_class : State.t]
    in
    let%bind state =
      match%map Store.load storage_controller config.disk_location with
      | Ok state -> state
      | Error (`IO_error e) ->
          Logger.info log "Ledger failed to load from storage %s; recreating"
            (Error.to_string_hum e) ;
          State.create config.genesis_ledger
      | Error `No_exist ->
          Logger.info log "Ledger doesn't exist in storage; recreating" ;
          State.create config.genesis_ledger
      | Error `Checksum_no_match ->
          Logger.warn log "Checksum failed when loading ledger, recreating" ;
          State.create config.genesis_ledger
    in
    let%map net = config.net_deferred in
    { ledger_builder_io= Net.Ledger_builder_io.create net
    ; log= Logger.child config.parent_log "ledger_builder_controller"
    ; state }
end
