open Core
open Async

module Mode = struct
  type t = Auto | Legacy
end

open struct
  module Ledger = Mina_ledger.Ledger
  module Ledger_transfer =
    Mina_ledger.Ledger_transfer.Make (Mina_ledger.Ledger) (Ledger.Db)
end

module type CONTEXT = sig
  val precomputed_values : Precomputed_values.t
end

module Locations = struct
  (* mina_net2: KEEP *)
  let mina_net2 config_dir = config_dir ^/ "mina_net2"

  (* root: MIGRATE *)

  let root_snarked_ledger config_dir = config_dir ^/ "root" ^/ "snarked_ledger"

  (* internal-tracing: FRESH *)

  let internal_tracing config_dir = config_dir ^/ "internal-tracing"

  (* wallets: KEEP *)

  let wallets config_dir = config_dir ^/ "wallets"

  (* genesis: FRESH *)

  let genesis config_dir = config_dir ^/ "genesis" [@@warning "-32"]

  (***************)

  let frontier config_dir = config_dir ^/ "frontier" [@@warning "-32"]
end

(* This is the Polyfilling API used for hardfork in AUTO mode. Functions named
   [migrate_*] will need to be reimplemented once Ledger Migration PRs are
   merged. *)
module AutoPolyfilled = struct
  [@@@warning "-32"]
  (* Have it for now as all functions are not referred. This is a WIP. And
     should be removed once we complete this feature. *)

  let create_config_dir ?(fresh = false) ~fork_config_dir () =
    if fresh then Mina_stdlib_unix.File_system.rmrf fork_config_dir ;
    Unix.mkdir ~p:() fork_config_dir

  let keep_mina_net2 ~source_config_dir ~fork_config_dir =
    Mina_stdlib_unix.File_system.cp ~r:true
      ~src:(Locations.mina_net2 source_config_dir)
      ~dest:(Locations.mina_net2 fork_config_dir)

  let migrate_root_snarked_ledgers ~context:(module Context : CONTEXT)
      ~(source_snarked_ledger : Ledger.Root.t) ~fork_config_dir :
      _ Deferred.Or_error.t =
    let open Context in
    let%map.Deferred () =
      Unix.mkdir ~p:() (Locations.root_snarked_ledger fork_config_dir)
    in
    let ledger_depth = Precomputed_values.ledger_depth precomputed_values in
    let dest_snarked_ledger =
      Ledger.Db.create
        ~directory_name:(Locations.root_snarked_ledger fork_config_dir)
        ~fresh:true ~depth:ledger_depth ()
    in
    Ledger_transfer.transfer_accounts
      ~src:(Ledger.Root.as_masked source_snarked_ledger)
      ~dest:dest_snarked_ledger

  let create_internal_tracing ~fork_config_dir =
    Unix.mkdir ~p:() (Locations.internal_tracing fork_config_dir)

  let keep_wallets ~source_config_dir ~fork_config_dir =
    (* WARN: we're symlinking to the directory as we may not have the permission
       to copy it. That folder should be read-only to MINA so it should be fine. *)
    Unix.symlink
      ~target:(Locations.wallets source_config_dir)
      ~link_name:(Locations.wallets fork_config_dir)

  let create_genesis ~source_config_dir:_ ~fork_config_dir:_ = failwith "TODO"
end
