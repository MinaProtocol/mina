open Core_kernel
open Async_kernel
open Coda_base

module Inputs = Full_frontier.Inputs

module Make (Inputs : Inputs.S) :
  Coda_intf.Transition_frontier_intf
  with type mostly_validated_external_transition :=
              ( [`Time_received] * Truth.true_t
              , [`Proof] * Truth.true_t
              , [`Frontier_dependencies] * Truth.true_t
              , [`Staged_ledger_diff] * Truth.false_t )
              Inputs.External_transition.Validation.with_transition
   and type external_transition_validated :=
              Inputs.External_transition.Validated.t
   and type staged_ledger_diff := Inputs.Staged_ledger_diff.t
   and type staged_ledger := Inputs.Staged_ledger.t
   and type transaction_snark_scan_state := Inputs.Staged_ledger.Scan_state.t
   and type verifier := Inputs.Verifier.t = struct
  module Full_frontier = Full_frontier.Make (Inputs)

  (* include (Base_frontier : module type Base_frontier with type t := Base_frontier.t) *)
  [%define_locally
  Full_frontier.
    ( Breadcrumb
    , Diff
    , Hash )]

  module Inputs_with_full_frontier = struct
    include Inputs
    module Frontier = Full_frontier
  end

  module Persistence = Persistence.Make (Inputs_with_full_frontier)
  module Extensions = Extensions.Make (Inputs_with_full_frontier)

  (* This is a temporary hack for commiting information into the snarked ledger.
   * Long term, the code should derive a fresh mask, perform transaction logic
   * on that, and then commit it. Interface differences between the ledger db
   * and ledger mask make this currently impossible.
   *)
  module Ledger_db_transaction_logic = Coda_base.Transaction_logic.Make (struct
    include Coda_base.Ledger.Db

    type location = Location.t

    let get_or_create ledger key =
      let key, loc =
        match
          get_or_create_account_exn ledger key (Account.initialize key)
        with
        | `Existed, loc ->
            ([], loc)
        | `Added, loc ->
            ([key], loc)
      in
      (key, get ledger loc |> Option.value_exn, loc)
  end

  type t =
    { frontier: Base_frontier.t
    ; persistence: Persistence.t
    ; extensions: Extensions.t }

  let create_clean config ~root_ledger =
    let persistent_frontier = Persistent_frontier.create ~logger ~root in
    let%map root = Root.create_genesis () in
    Root_ledger.reset_to_genesis root_ledger;
    Persistent_frontier.reset persistent_db ~root;
    let frontier = Full_frontier.create ~logger:config.logger ~root ~consensus_local_state:config.consensus_local_state in
    let persistence = Persistence.create persistent_frontier in
    let extensions = Extensions.create ~logger ~root in
    {frontier; persistence; extensions}

  let sync_persistence_and_load config ~root_ledger ~persistent_frontier in
    if
      Frozen_ledger_hash.equal
        (Persistent_frontier.get_root pers_frontier).snarked_ledger_hash
        (Root_ledger.merkle_root root_ledger)
    then (
      (* TODO: log error *)
      assert (
        Frontier_hash.equal
          (Persistent_frontier.get_frontier_hash pers_frontier)
          (Root_ledger.get_frontier_hash root_ledger));
      load config ~root_ledger ~persistent_frontier:pers_frontier)
    else (
      match Persistent_frontier.fast_forward_root pers_frontier ~target_root:(Root_ledger.get_root_state_hash root_ledger) with
      | Error (`Failure err) ->
          (* TODO: recover *)
          failwiths (Error.sexp_of_t err)
      | Error `Target_not_found ->
          failwith "TODO"
      | Ok () ->
          load config ~root_ledger ~persistent_frontier:pers_frontier)

  let create config =
    let root_ledger = Root_ledger.create ~directory:config.root_ledger_directory in
    if Root_ledger.is_initialized root_ledger then
      let persistent_frontier = Persistent_frontier.create ~directory:persistent_db_directory in
      match Persistent_frontier.check persistent_frontier with
      | Error `Not_initialized ->
          create_from_root_ledger config ~root_ledger
      | Error `Corrupt ->
          failwith "TODO"
      | Ok () ->
          sync_persistence_and_load config ~root_ledger ~persistent_frontier
    else
      create_clean config

  let add_breadcrumb t breadcrumb =
    let open Deferred.Or_error.Let_syntax in
    let%bind diffs = Deferred.return @@ calculate_diffs t.frontier breadcrumb in
    let%bind () = Deferred.return @@ apply_diffs t.frontier breadcrumb in
    Persistence.notify t.persistence ~diffs ~target_hash:t.frontier.hash;
    Extensions.notify t.extensions ~diffs
end

include Make (struct
  module Verifier = Verifier
  module Ledger_proof = Ledger_proof
  module Transaction_snark_work = Transaction_snark_work
  module External_transition = Coda_transition.External_transition
  module Internal_transition = Coda_transition.Internal_transition
  module Staged_ledger_diff = Staged_ledger_diff
  module Staged_ledger = Staged_ledger

  let max_length = Consensus.Constants.k
end)
