open Core_kernel
open Coda_base

module Make (Inputs : Inputs.With_base_frontier_intf) = struct
  open Inputs

  module Db = Database.Make (Inputs)
  module Sync = Sync.Make (struct
    include Inputs
    module Db = Db
  end)

  (* TODO: create a reusable singleton factory abstraction *)
  module rec Instance_type : sig
    type t =
      { db: Db.t
      ; factory: Factory_type.t }
  end = Instance_type
  and Factory_type : sig
    type t =
      { logger: Logger.t
      ; directory: string
      ; mutable instance: Instance_type.t option }
  end = Factory_type

  module Instance = struct
    type t = Instance_type.t
    open Instance_type

    let create ~logger ~directory factory =
      {db = Db.create ~logger ~directory; factory}

    let destroy t =
      Db.close t.db;
      t.factory.instance <- None

    let factory {factory; _} = factory

    let fast_forward t target_root =
      let open Frontier in
      let open Result.Let_syntax in
      let lift_error r msg = Result.map_error r ~f:(Fn.const (Error.of_string msg)) in
      let%bind root_hash = lift_error (Db.get_root_hash t.db) "failed to get root hash" in
      if State_hash.equal root_hash target_root.state_hash then
        let%bind frontier_hash = lift_error (Db.get_frontier_hash t.db) "failed to get frontier hash" in
        (* TODO: gracefully recover from this state *)
        Result.ok_if_true (Hash.equal frontier_hash target_root.frontier_hash)
          ~error:(Error.of_string "already at persistent root, but frontier hash did not match")
      else
        failwith "TODO"

    let load_full_frontier _t _persistent_root ~consensus_local_state:_ =
      failwith "TODO"
      (*
      let open Result.Let_syntax in
      let%map {root_data; root_transition} = Db.get_root t.db in
      let staged_ledger_mask = failwith "TODO" in
      let staged_ledger =
        Staged_ledger.of_scan_state_and_ledger
          ~logger ~verifier
          ~snarked_ledger_hash
          ~ledger:staged_ledger_mask
          ~scan_state:root_data.scan_state
          ~pending_coinbases:root_data.pending_coinbase
      in
      let frontier =
        Full_frontier.create
          ~logger:t.logger
          ~root_transition
          ~root_staged_ledger
          ~consensus_local_state
      in
      (* TODO reconstruct and add breadcrumbs dfs, set best tip, perform basic validation *)
      frontier
      *)
  end
  
  type t = Factory_type.t
  open Factory_type

  let create ~logger ~directory =
    {logger; directory; instance= None}

  let create_instance_exn t =
    assert (t.instance = None);
    let instance = Instance.create ~logger:t.logger ~directory:t.directory t in
    t.instance <- Some instance;
    instance
end
