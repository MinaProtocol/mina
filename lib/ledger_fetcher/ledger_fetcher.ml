open Core_kernel
open Async_kernel

module type S = sig
  include Minibit.Ledger_fetcher_intf
end

module type Inputs_intf = sig
  include Protocols.Minibit_pow.Inputs_intf
  module Net : Minibit.Network_intf with type ledger := Ledger.t
                                     and type 'a hash := 'a Hash.t
                                     and type state := State.t
end

module Make
  (Inputs : Inputs_intf)
= struct
  open Inputs

  module Ledger_hash = Hashable.Make(struct
    type t = Ledger.t Hash.t [@@deriving sexp, compare, hash]
  end)

  type t =
    { strongest_ledgers : (Ledger.t Hash.t * Strength.t) Heap.t
    ; hash_to_ledger : (Ledger.t * State.t) Ledger_hash.Table.t
    ; net : Net.t Deferred.t
    ; log : Logger.t
    }

  (* For now: Keep the top 50 ledgers (by strength), prune everything else *)
  let prune t =
    let rec go () =
      if Heap.length t.strongest_ledgers > 50 then
        let (h, _) = Heap.pop_exn t.strongest_ledgers in
        Ledger_hash.Table.remove t.hash_to_ledger h;
        go ()
      else ()
    in
    go ()

  let add t h ledger state =
    Ledger_hash.Table.set t.hash_to_ledger ~key:h ~data:(ledger, state);
    Heap.add t.strongest_ledgers (h, state.strength);
    prune t

  let local_get t h =
    match Ledger_hash.Table.find t.hash_to_ledger h with
    | None -> Or_error.errorf !"Couldn't find %{sexp:Ledger.t Hash.t} locally" h
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

  let create ~parent_log ~net_deferred ~ledger_transitions =
    let t =
      { strongest_ledgers = Heap.create ~cmp:(fun (_, s) (_, s') -> Strength.compare s s') ()
      ; hash_to_ledger = Ledger_hash.Table.create ()
      ; net = net_deferred
      ; log = Logger.child parent_log "ledger-fetcher"
      }
    in
    don't_wait_for begin
      Linear_pipe.iter ledger_transitions ~f:(fun (h, transactions, state) ->
        let open Deferred.Let_syntax in
        match%map get t h with
        | Error e ->
          Logger.warn t.log "Failed to keep-up with transactions (can't get ledger %s)" (Error.to_string_hum e)
        | Ok unsafe_ledger ->
          let ledger = Ledger.copy unsafe_ledger in
          List.iter transactions ~f:(fun transaction ->
            match Ledger.apply_transaction ledger transaction with
            | Error e ->
                Logger.warn t.log "Failed to apply a transaction %s" (Error.to_string_hum e)
            | Ok () -> ()
          );
          add t h ledger state
      )
    end;
    t
end

