open Core_kernel
open Async_kernel

module type S = sig
  include Minibit.Ledger_fetcher_intf
end

module type Inputs_intf = sig
  include Protocols.Minibit_pow.Inputs_intf
  module Net : Minibit.Network_intf with type ledger := Ledger.t
                                     and type ledger_hash := Ledger_hash.t
                                     and type state := State.t
  module Store : Storage.With_checksum_intf
  module Transaction_pool : Minibit.Transaction_pool_intf with type transaction_with_valid_signature := Transaction.With_valid_signature.t
  module Genesis : sig val state : State.t end
  module Genesis_ledger : sig val ledger : Ledger.t end
end

module Make
  (Inputs : Inputs_intf)
  : Minibit.Ledger_fetcher_intf with type ledger_hash := Inputs.Ledger_hash.t
                                and type ledger := Inputs.Ledger.t
                                and type transaction_with_valid_signature := Inputs.Transaction.With_valid_signature.t
                                and type state := Inputs.State.t
                                and type net := Inputs.Net.t

= struct
  open Inputs

  module Config = struct
    type t =
      { keep_count : int [@default 50]
      ; parent_log : Logger.t
      ; net_deferred : Net.t Deferred.t
      ; ledger_transitions : (Ledger_hash.t * Transaction.With_valid_signature.t list * State.t) Linear_pipe.Reader.t
      ; disk_location : Store.location
      }
    [@@deriving make]
  end

  let heap_cmp (_, s) (_, s') = Strength.compare s s'

  module State = struct
    module T = struct
      type t =
        { strongest_ledgers : (Ledger_hash.t * Strength.t) Heap.t
        ; hash_to_ledger : (Ledger.t * State.t) Ledger_hash.Table.t
        }
    end

    include T
    include Bin_prot.Utils.Make_binable(struct
      module Binable = struct
        type t =
          { strongest_ledgers : (Ledger_hash.t * Strength.t) list
          ; hash_to_ledger : (Ledger.t * State.t) Ledger_hash.Table.t
          }
        [@@deriving bin_io]
      end

      type t = T.t
      let to_binable ({strongest_ledgers ; hash_to_ledger} : t) : Binable.t =
        { strongest_ledgers = Heap.to_list strongest_ledgers
        ; hash_to_ledger
        }

      let of_binable ({Binable.strongest_ledgers ; hash_to_ledger} : Binable.t) : t =
        { strongest_ledgers = Heap.of_list strongest_ledgers ~cmp:heap_cmp
        ; hash_to_ledger
        }
    end)

    let create () : t =
      { strongest_ledgers = Heap.create ~cmp:heap_cmp ()
      ; hash_to_ledger = Ledger_hash.Table.create ()
      }
  end

  (* Invariant: After t is fully created (create returns), the following is always true
   * 1. $len(t.state.strongest_ledgers) > 0$
   * 2. $\forall hash \in t.state.strongest_ledgers, \exists hash in t.state.hash_to_ledger$
   *)
  type t =
    { state : State.t
    ; net : Net.t Deferred.t
    ; log : Logger.t
    ; keep_count : int
    ; storage_controller : State.t Store.Controller.t
    ; disk_location : Store.location
    ; all_new_states_reader : (Ledger.t * Inputs.State.t) Linear_pipe.Reader.t
    }

  (* TODO: Improve heuristic for "best" ledger. Perhaps take a confidence
   * percentage and look back x-strengths to meet that confidence *)
  let best_ledger t =
    let (h, _) = Heap.top_exn t.state.strongest_ledgers in
    fst (Ledger_hash.Table.find_exn t.state.hash_to_ledger h)

  (* For now: Keep the top 50 ledgers (by strength), prune everything else *)
  let prune t =
    let rec go () =
      if Heap.length t.state.strongest_ledgers > t.keep_count then begin
        let (h, _) = Heap.pop_exn t.state.strongest_ledgers in
        Ledger_hash.Table.remove t.state.hash_to_ledger h;
        go ()
      end
    in
    go ()

  let add t h ledger state =
    Ledger_hash.Table.set t.state.hash_to_ledger ~key:h ~data:(ledger, state);
    Heap.add t.state.strongest_ledgers (h, state.strength);
    prune t

  let local_get t h =
    match Ledger_hash.Table.find t.state.hash_to_ledger h with
    | None -> Or_error.errorf !"Couldn't find %{sexp:Ledger_hash.t} locally" h
    | Some x -> Or_error.return x

  let get t h : Ledger.t Deferred.Or_error.t =
    match local_get t h with
    | Error _ ->
      let%bind net = t.net in
      let open Deferred.Or_error.Let_syntax in
      let%map (ledger, state) = Net.Ledger_fetcher_io.get_ledger_at_hash net h in
      add t h ledger state;
      ledger
    | Ok (l,s) -> Deferred.Or_error.return l

  let initialize t =
    if Heap.length t.state.strongest_ledgers = 0 then begin
      let genesis_ledger = Genesis_ledger.ledger in
      add t (Ledger.merkle_root genesis_ledger) genesis_ledger Genesis.state;
    end

  let strongest_ledgers t =
    let best_strength = ref Strength.zero in
    Linear_pipe.filter_map t.all_new_states_reader ~f:(fun (ledger, state) ->
      let new_strength = Inputs.State.strength state in
      if Strength.(<) !best_strength new_strength then begin
        best_strength := new_strength;
        Some (ledger, state)
      end else
        None
    )

  let materialize_new_state t =
    let (hash, _) = Heap.top_exn t.state.strongest_ledgers in
    Or_error.ok_exn (local_get t hash)

  let create (config : Config.t) =
    let (all_new_states_reader, all_new_states_writer) = Linear_pipe.create () in
    let storage_controller =
      Store.Controller.create
        ~parent_log:config.parent_log
        [%bin_type_class: State.t]
    in
    let log = Logger.child config.parent_log "ledger-fetcher" in
    let%map state =
      match%map Store.load storage_controller config.disk_location with
      | Ok state -> state
      | Error (`IO_error e) ->
        Logger.info log "Ledger failed to load from storage %s; recreating" (Error.to_string_hum e);
        State.create ()
      | Error `No_exist ->
        Logger.info log "Ledger doesn't exist in storage; recreating";
        State.create ()
      | Error `Checksum_no_match ->
        Logger.warn log "Checksum failed when loading ledger, recreating";
        State.create ()
    in

    let t =
      { state
      ; net = config.net_deferred
      ; log
      ; keep_count = config.keep_count
      ; storage_controller
      ; disk_location = config.disk_location
      ; all_new_states_reader
      }
    in

    initialize t;
    let initial_strong_state = materialize_new_state t in
    Linear_pipe.write_or_exn ~capacity:1 all_new_states_writer all_new_states_reader initial_strong_state;

    don't_wait_for begin
      Linear_pipe.iter config.ledger_transitions ~f:(fun (h, transactions, state) ->
        let open Deferred.Let_syntax in
        (* Notice: This pipe iter blocks upstream while it's materializing ledgers from the network (potentially) AND saving to disk *)
        match%bind get t h with
        | Error e ->
          Logger.warn t.log "Failed to keep-up with transactions (can't get ledger %s)" (Error.to_string_hum e);
          return ()
        | Ok unsafe_ledger ->
          let ledger = Ledger.copy unsafe_ledger in
          List.iter transactions ~f:(fun transaction ->
            match Ledger.apply_transaction ledger transaction with
            | Error e ->
                Logger.warn t.log "Failed to apply a transaction %s" (Error.to_string_hum e)
            | Ok () -> ()
          );
          add t h ledger state;
          (* Capacity is tiny because contract is that miner will cancel whenever
           * new tip is received *)
          let next_state = materialize_new_state t in
          Linear_pipe.write_or_exn ~capacity:1 all_new_states_writer all_new_states_reader next_state;
          (* TODO: Make state saving more efficient and in appropriate places (see #180) *)
          Store.store t.storage_controller t.disk_location t.state
      )
    end;
    t
end

