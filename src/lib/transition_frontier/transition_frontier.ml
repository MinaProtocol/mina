open Async_kernel
open Coda_base
open Core_kernel
open Protocols.Coda_pow

module type Inputs_intf = Transition_frontier0.Inputs_intf

module Make (Inputs : Inputs_intf) :
  Transition_frontier_intf
  with type state_hash := State_hash.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type ledger_database := Ledger.Db.t
   and type staged_ledger_diff := Inputs.Staged_ledger_diff.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type masked_ledger := Ledger.Mask.Attached.t
   and type transaction_snark_scan_state := Inputs.Staged_ledger.Scan_state.t
   and type consensus_local_state := Consensus.Local_state.t = struct
  module Transition_frontier0 = Transition_frontier0.Make (Inputs)

  module Extensions = struct
    module Snark_pool_refcount = Snark_pool_refcount.Make (struct
      include Inputs
      module Transition_frontier = Transition_frontier0
    end)

    type t = {snark_pool_refcount: Snark_pool_refcount.t} [@@deriving fields]

    let create () = {snark_pool_refcount= Snark_pool_refcount.create ()}

    let handle_diff t frontier diff =
      let use handler field = handler (Field.get field t) frontier diff in
      Fields.iter ~snark_pool_refcount:(use Snark_pool_refcount.handle_diff)
  end

  type t = {frontier0: Transition_frontier0.t; extensions: Extensions.t}

  module Breadcrumb = Transition_frontier0.Breadcrumb

  module For_tests = struct
    let root_snarked_ledger t =
      Transition_frontier0.For_tests.root_snarked_ledger t.frontier0
  end

  exception Already_exists = Transition_frontier0.Already_exists

  exception Parent_not_found = Transition_frontier0.Parent_not_found

  let create ~logger ~root_transition ~root_snarked_ledger
      ~root_transaction_snark_scan_state ~root_staged_ledger_diff
      ~consensus_local_state : t Deferred.t =
    let open Deferred.Let_syntax in
    let%bind f =
      Transition_frontier0.create ~logger ~root_transition ~root_snarked_ledger
        ~root_transaction_snark_scan_state ~root_staged_ledger_diff
        ~consensus_local_state
    in
    return {frontier0= f; extensions= Extensions.create ()}

  let add_breadcrumb_exn t bc =
    Extensions.handle_diff t.extensions t.frontier0
      (Transition_frontier0.add_breadcrumb_exn t.frontier0 bc)

  let all_breadcrumbs t = Transition_frontier0.all_breadcrumbs t.frontier0

  let best_tip t = Transition_frontier0.best_tip t.frontier0

  let best_tip_path_length_exn t =
    Transition_frontier0.best_tip_path_length_exn t.frontier0

  let clear_paths t = Transition_frontier0.clear_paths t.frontier0

  let consensus_local_state t =
    Transition_frontier0.consensus_local_state t.frontier0

  let find t hash = Transition_frontier0.find t.frontier0 hash

  let find_exn t hash = Transition_frontier0.find_exn t.frontier0 hash

  let hash_path t bc = Transition_frontier0.hash_path t.frontier0 bc

  let iter t ~f = Transition_frontier0.iter t.frontier0 ~f

  let logger t = Transition_frontier0.logger t.frontier0

  let max_length = Transition_frontier0.max_length

  let path_map t bc ~f = Transition_frontier0.path_map t.frontier0 bc ~f

  let root t = Transition_frontier0.root t.frontier0

  let successor_hashes t hash =
    Transition_frontier0.successor_hashes t.frontier0 hash

  let successor_hashes_rec t hash =
    Transition_frontier0.successor_hashes_rec t.frontier0 hash

  let successors t bc = Transition_frontier0.successors t.frontier0 bc

  let successors_rec t bc = Transition_frontier0.successors_rec t.frontier0 bc
end
