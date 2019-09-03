open Core_kernel
open Coda_base

module Make (Inputs : Inputs.With_base_frontier_intf) = struct
  module Locations = struct
    let snarked_ledger root = Filename.concat root "snarked_ledger"
    let state_hash root = Filename.concat root "state_hash"
    let frontier_hash root = Filename.concat root "frontier_hash"
  end

  (* TODO: create a reusable singleton factory abstraction *)
  module rec Instance_type : sig
    type t =
      { snarked_ledger: Ledger.Db.t
      ; factory: Factory_type.t }
  end = Instance_type
  and Factory_type : sig
    type t =
      { directory: string
      ; mutable instance: Instance_type.t option }
  end = Factory_type

  module Instance = struct
    type t = Instance_type.t
    open Instance_type

    let create ~directory factory =
      let snarked_ledger = Ledger.Db.create ~directory_name:(Locations.snarked_ledger directory) () in
      {snarked_ledger; factory}

    let destroy t =
      Ledger.Db.close t.snarked_ledger;
      t.factory.instance <- None

    (* [new] TODO: encapsulate functionality of snarked ledger *)
    let snarked_ledger {snarked_ledger; _} = snarked_ledger

    (* defaults to genesis *)
    let load_root_identifier _ =
      failwith "TODO"

    (*
    let at_genesis t =
      let%map state_hash = load_state_hash t in
      let snarked_ledger_hash = Ledger.Db.merkle_root t.snarked_ledger in
      State_hash.equal state_hash (With_hash.hash Genesis_protocol_state.t)
      && Ledger_hash.equal snarked_ledger_hash (Ledger.merkle_root Genesis_ledger.t)
    *)
  end

  type t = Factory_type.t
  open Factory_type

  let create ~directory =
    {directory; instance= None}

  let create_instance_exn t =
    assert (t.instance = None);
    let instance = Instance.create ~directory:t.directory t in
    t.instance <- Some instance;
    instance
end
