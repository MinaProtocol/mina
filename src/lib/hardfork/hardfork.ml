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

  val runtime_config_ledger : Runtime_config.Ledger.t
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

  let genesis config_dir = config_dir ^/ "genesis"

  let genesis_ledger config_dir ~hash =
    config_dir ^/ "genesis" ^/ "genesis_ledger_" ^ hash

  (***************)

  let frontier config_dir = config_dir ^/ "frontier"
end

(* This is the Polyfilling API used for hardfork in AUTO mode. Functions named
   [migrate_*] will need to be reimplemented once Ledger Migration PRs are
   merged. *)
module AutoPolyfilled = struct
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

  let create_genesis ~context:(module Context : CONTEXT) ~fork_config_dir =
    let open Context in
    let%map.Deferred () =
      Unix.mkdir ~p:() (Locations.genesis fork_config_dir)
    in
    (* Transfer genesis ledger *)
    let ledger_depth = Precomputed_values.ledger_depth precomputed_values in
    let genesis_ledger_hash =
      runtime_config_ledger.hash
      |> Option.value_exn
           ~message:
             "No hash found for runtime config ledger, can't locate genesis \
              ledger"
    in
    let dest_genesis_ledger =
      Ledger.Db.create
        ~directory_name:
          (Locations.genesis_ledger fork_config_dir ~hash:genesis_ledger_hash)
        ~fresh:true ~depth:ledger_depth ()
    in
    let source_genesis_ledger =
      Lazy.force @@ Precomputed_values.genesis_ledger precomputed_values
    in
    let%bind.Deferred.Or_error _ =
      Deferred.return
      @@ Ledger_transfer.transfer_accounts ~src:source_genesis_ledger
           ~dest:dest_genesis_ledger
    in
    (* Create epoch ledger from fresh *)
    failwith "TODO"

  let transfer_frontier ~source_config_dir ~fork_config_dir =
    (* TODO: figure out what should we do exactly on frontier database instead of a copy-paste *)
    Mina_stdlib_unix.File_system.cp ~r:true
      ~src:(Locations.frontier source_config_dir)
      ~dest:(Locations.frontier fork_config_dir)
end
