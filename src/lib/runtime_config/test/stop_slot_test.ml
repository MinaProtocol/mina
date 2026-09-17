(** Checks a network's hard fork stop-slot schedule by driving the daemon's own
    scheduling logic.

    Nothing here reimplements slot arithmetic. Every derived value comes from
    the same chain of calls the daemon makes when it arms the auto hard fork in
    [src/app/cli/src/init/mina_run.ml]:

    {v
      Runtime_config.slot_tx_end / slot_chain_end
      Runtime_config.hard_fork_genesis_slot_delta
      Runtime_config.scheduled_hard_fork_genesis_slot
      Genesis_ledger_helper.make_genesis_constants   (config -> constants)
      Consensus.Constants.create
      Consensus.Data.Consensus_time.of_global_slot / start_time / epoch / slot
      Block_time.diff                                (window durations)
    v}

    A shipped network config is in one of two states, and this test checks
    whichever one the network is in:

    - [Scheduled]: the next hard fork is armed. The config declares the whole
      stop-slot family, and the daemon must derive from it the times that were
      communicated to node operators.
    - [Forked]: that hard fork has happened, and the config the network now
      ships is the fork config it produced. No stop slots are declared any
      more, and the recorded fork must be the one the schedule aimed at.

    The test supplies two things: the runtime config of the network under test,
    and that network's compiled constants. The latter are needed because this
    test binary is not built with the target network's profile -- under the
    default [dev] profile a slot is 2 s rather than devnet's 180 s -- so they
    are given explicitly rather than read from [Node_config].

    Counters: [slot_tx_end] and [slot_chain_end] are
    [Global_slot_since_hard_fork], counted from the network's last hard fork
    genesis. A fork config's [proof.fork.global_slot_since_genesis] is a
    different counter; the two must never be compared directly. They meet only
    at the fork itself: the new fork config's [global_slot_since_genesis] is
    the previous one's plus the hard fork genesis slot. For devnet that is
    445860 + 413700 = 859560. *)

open Core

(** The compiled constants of the network under test. *)
module Network_constants = struct
  type t =
    { constraint_constants : Genesis_constants.Constraint_constants.t
    ; genesis_constants : Genesis_constants.t
    }
end

(** Reading a shipped runtime config the way the daemon reads it. *)
module Config = struct
  let of_file path =
    Yojson.Safe.from_file path |> Runtime_config.of_yojson
    |> Result.map_error ~f:Error.of_string
    |> Or_error.ok_exn

  (** Same merge the daemon performs: the runtime config overrides the compiled
      genesis constants. *)
  let genesis_constants ~(network : Network_constants.t)
      (config : Runtime_config.t) =
    Genesis_ledger_helper.make_genesis_constants ~logger:(Logger.null ())
      ~default:network.genesis_constants config
    |> Or_error.ok_exn

  (** The genesis time the config declares, formatted the same way the daemon
      logs slot times in [mina_run.ml]. *)
  let genesis_time ~network config =
    let genesis_constants = genesis_constants ~network config in
    Genesis_constants.to_time genesis_constants.protocol.genesis_state_timestamp
    |> Time_float.to_string_iso8601_basic ~zone:Time_float.Zone.utc

  (** [proof.fork], set once the network has hard forked. *)
  let fork (config : Runtime_config.t) =
    Option.bind config.proof ~f:(fun (proof : Runtime_config.Proof_keys.t) ->
        proof.fork )
end

(** The schedule a runtime config declares, plus the daemon-derived quantities
    that follow from it. *)
module Schedule = struct
  type t =
    { slot_tx_end : Mina_numbers.Global_slot_since_hard_fork.t
    ; slot_chain_end : Mina_numbers.Global_slot_since_hard_fork.t
    ; hard_fork_genesis_slot_delta : Mina_numbers.Global_slot_span.t
    ; hard_fork_genesis_slot : Mina_numbers.Global_slot_since_hard_fork.t
    ; consensus_constants : Consensus.Constants.t
    }

  let require field = function
    | Some v ->
        v
    | None ->
        failwithf "runtime config: %s is not set" field ()

  (** [None] when the config arms no hard fork at all -- the state a config is
      in between forks. A config that sets only part of the family is a bug, so
      that case still fails. *)
  let of_config ~(network : Network_constants.t) (config : Runtime_config.t) =
    match
      ( Runtime_config.slot_tx_end config
      , Runtime_config.slot_chain_end config
      , Runtime_config.hard_fork_genesis_slot_delta config )
    with
    | None, None, None ->
        None
    | _ ->
        let genesis_constants = Config.genesis_constants ~network config in
        let consensus_constants =
          Consensus.Constants.create
            ~constraint_constants:network.constraint_constants
            ~protocol_constants:genesis_constants.protocol
        in
        Some
          { slot_tx_end =
              require "daemon.slot_tx_end" (Runtime_config.slot_tx_end config)
          ; slot_chain_end =
              require "daemon.slot_chain_end"
                (Runtime_config.slot_chain_end config)
          ; hard_fork_genesis_slot_delta =
              require "daemon.hard_fork_genesis_slot_delta"
                (Runtime_config.hard_fork_genesis_slot_delta config)
          ; hard_fork_genesis_slot =
              require "scheduled hard fork genesis slot"
                (Runtime_config.scheduled_hard_fork_genesis_slot config)
          ; consensus_constants
          }

  let of_file ~network path = of_config ~network (Config.of_file path)

  let slot_tx_end t = t.slot_tx_end

  let slot_chain_end t = t.slot_chain_end

  let hard_fork_genesis_slot_delta t = t.hard_fork_genesis_slot_delta

  let hard_fork_genesis_slot t = t.hard_fork_genesis_slot

  let consensus_time t slot =
    Consensus.Data.Consensus_time.of_global_slot
      ~constants:t.consensus_constants slot

  (** Block time at which a slot begins -- the daemon's own computation. *)
  let block_time_of_slot t slot =
    Consensus.Data.Consensus_time.start_time ~constants:t.consensus_constants
      (consensus_time t slot)

  (** Formatted the same way the daemon logs it in [mina_run.ml]. *)
  let time_of_slot t slot =
    Block_time.to_time_exn (block_time_of_slot t slot)
    |> Time_float.to_string_iso8601_basic ~zone:Time_float.Zone.utc

  let hours_between t ~from_slot ~to_slot =
    let span =
      Block_time.diff
        (block_time_of_slot t to_slot)
        (block_time_of_slot t from_slot)
    in
    Int64.to_int_exn (Block_time.Span.to_ms span) / 3_600_000

  (** Blocks are still produced in this window, but must be empty. *)
  let empty_block_hours t =
    hours_between t ~from_slot:t.slot_tx_end ~to_slot:t.slot_chain_end

  (** No blocks at all in this window. *)
  let downtime_hours t =
    hours_between t ~from_slot:t.slot_chain_end
      ~to_slot:t.hard_fork_genesis_slot

  (** Total time users cannot transact. *)
  let no_transaction_hours t =
    hours_between t ~from_slot:t.slot_tx_end ~to_slot:t.hard_fork_genesis_slot

  let epoch_of_slot t slot =
    Unsigned.UInt32.to_int
      (Consensus.Data.Consensus_time.epoch (consensus_time t slot))

  let slot_in_epoch t slot =
    Unsigned.UInt32.to_int
      (Consensus.Data.Consensus_time.slot (consensus_time t slot))
end

(** What a network's config is expected to declare. *)
module Expected = struct
  (** An armed schedule, and the times the daemon must derive from it. *)
  type schedule =
    { slot_tx_end : int
    ; slot_chain_end : int
    ; hard_fork_genesis_slot_delta : int
    ; hard_fork_genesis_slot : int
    ; tx_end_time : string
    ; chain_end_time : string
    ; hard_fork_genesis_time : string
    ; empty_block_hours : int
    ; downtime_hours : int
    ; no_transaction_hours : int
    ; tx_end_epoch : int
    ; tx_end_slot_in_epoch : int
    }

  (** A schedule that has run its course: the config is now the fork config
      that hard fork produced. *)
  type forked =
    { genesis_time : string  (** [genesis.genesis_state_timestamp]. *)
    ; previous_fork_slot_since_genesis : int
          (** [proof.fork.global_slot_since_genesis] of the config this one
              replaced, i.e. the base of the [Global_slot_since_hard_fork]
              counter the schedule was expressed in. *)
    ; hard_fork_genesis_slot : int
          (** The genesis slot the schedule aimed at, since that base. *)
    ; fork_slot_since_genesis : int
          (** [proof.fork.global_slot_since_genesis] of this config. *)
    ; fork_blockchain_length : int  (** [proof.fork.blockchain_length]. *)
    }

  (* Both networks are [Forked] right now, so nothing builds a [Scheduled]
     value; the warning is silenced rather than the branch deleted, because
     arming the next hard fork means setting the stop slots in the shipped
     config and flipping the expectation below back to [Scheduled]. *)
  type t = Scheduled of schedule | Forked of forked [@@warning "-37"]
end

let case name f = Alcotest.test_case name `Quick f

let scheduled_suite ~network ~(expected : Expected.schedule) ~config_path =
  let open Expected in
  let schedule () =
    Schedule.require "daemon stop slot schedule"
      (Schedule.of_file ~network config_path)
  in
  let slot = Mina_numbers.Global_slot_since_hard_fork.to_int in
  [ case "configured slots are the agreed values" (fun () ->
        let t = schedule () in
        Alcotest.(check int)
          "slot_tx_end" expected.slot_tx_end
          (slot (Schedule.slot_tx_end t)) ;
        Alcotest.(check int)
          "slot_chain_end" expected.slot_chain_end
          (slot (Schedule.slot_chain_end t)) ;
        Alcotest.(check int)
          "hard_fork_genesis_slot_delta" expected.hard_fork_genesis_slot_delta
          (Mina_numbers.Global_slot_span.to_int
             (Schedule.hard_fork_genesis_slot_delta t) ) )
  ; case "daemon derives hard fork genesis slot as chain_end + delta" (fun () ->
        Alcotest.(check int)
          "hard_fork_genesis_slot" expected.hard_fork_genesis_slot
          (slot (Schedule.hard_fork_genesis_slot (schedule ()))) )
  ; case "slots are correctly ordered" (fun () ->
        let t = schedule () in
        Alcotest.(check bool)
          "slot_tx_end < slot_chain_end" true
          (slot (Schedule.slot_tx_end t) < slot (Schedule.slot_chain_end t)) ;
        Alcotest.(check bool)
          "slot_chain_end <= hard fork genesis slot" true
          ( slot (Schedule.slot_chain_end t)
          <= slot (Schedule.hard_fork_genesis_slot t) ) )
  ; case "daemon places transaction stop at the agreed time" (fun () ->
        let t = schedule () in
        Alcotest.(check string)
          "tx end time" expected.tx_end_time
          (Schedule.time_of_slot t (Schedule.slot_tx_end t)) )
  ; case "daemon places chain stop at the agreed time" (fun () ->
        let t = schedule () in
        Alcotest.(check string)
          "chain end time" expected.chain_end_time
          (Schedule.time_of_slot t (Schedule.slot_chain_end t)) )
  ; case "daemon places hard fork genesis at the agreed time" (fun () ->
        let t = schedule () in
        Alcotest.(check string)
          "hard fork genesis time" expected.hard_fork_genesis_time
          (Schedule.time_of_slot t (Schedule.hard_fork_genesis_slot t)) )
  ; case "windows have the communicated durations" (fun () ->
        let t = schedule () in
        Alcotest.(check int)
          "hours of empty blocks (tx stop -> chain stop)"
          expected.empty_block_hours
          (Schedule.empty_block_hours t) ;
        Alcotest.(check int)
          "hours of downtime (chain stop -> hard fork genesis)"
          expected.downtime_hours
          (Schedule.downtime_hours t) ;
        Alcotest.(check int)
          "hours without transactions (tx stop -> hard fork genesis)"
          expected.no_transaction_hours
          (Schedule.no_transaction_hours t) )
  ; case "transaction stop lands where expected in the epoch schedule"
      (fun () ->
        let t = schedule () in
        let s = Schedule.slot_tx_end t in
        Alcotest.(check int)
          "epoch of slot_tx_end" expected.tx_end_epoch
          (Schedule.epoch_of_slot t s) ;
        Alcotest.(check int)
          "slot-in-epoch of slot_tx_end" expected.tx_end_slot_in_epoch
          (Schedule.slot_in_epoch t s) )
  ]

let forked_suite ~network ~(expected : Expected.forked) ~config_path =
  let open Expected in
  let config () = Config.of_file config_path in
  let fork () = Schedule.require "proof.fork" (Config.fork (config ())) in
  [ case "no hard fork is armed any more" (fun () ->
        Alcotest.(check bool)
          "daemon declares no stop slot schedule" true
          (Option.is_none (Schedule.of_config ~network (config ()))) )
  ; case "config is the fork config the schedule produced" (fun () ->
        Alcotest.(check int)
          "expected fork slot is chain start + hard fork genesis slot"
          expected.fork_slot_since_genesis
          ( expected.previous_fork_slot_since_genesis
          + expected.hard_fork_genesis_slot ) ;
        Alcotest.(check int)
          "proof.fork.global_slot_since_genesis"
          expected.fork_slot_since_genesis (fork ()).global_slot_since_genesis ;
        Alcotest.(check int)
          "proof.fork.blockchain_length" expected.fork_blockchain_length
          (fork ()).blockchain_length )
  ; case "hard fork genesis is at the agreed time" (fun () ->
        Alcotest.(check string)
          "genesis time" expected.genesis_time
          (Config.genesis_time ~network (config ())) )
  ]

let suite ~network ~(expected : Expected.t) ~config_path =
  match expected with
  | Expected.Scheduled expected ->
      scheduled_suite ~network ~expected ~config_path
  | Expected.Forked expected ->
      forked_suite ~network ~expected ~config_path

(* ------------------------------------------------------------------ *)
(* devnet                                                             *)
(* ------------------------------------------------------------------ *)

(* Devnet's compiled constants, from src/lib/node_config/profiled/mainnet.ml
   which devnet.ml includes. They are restated here because this binary is not
   a devnet build and node_config_profiled.mli does not expose the per-profile
   modules. The genesis timestamp is deliberately NOT set here -- it comes from
   the runtime config under test, via make_genesis_constants. *)
let devnet : Network_constants.t =
  let (module Compiled) = Genesis_constants.profiled () in
  let compiled = Compiled.genesis_constants in
  { constraint_constants =
      { Compiled.constraint_constants with block_window_duration_ms = 180_000 }
  ; genesis_constants =
      { compiled with
        protocol =
          { compiled.protocol with
            k = 290
          ; slots_per_epoch = 7140
          ; slots_per_sub_window = 7
          ; grace_period_slots = 2160
          ; delta = 0
          }
      }
  }

(* Devnet hard forked on 2026-08-19, at the end of the schedule this test used
   to check: slot_tx_end 413540, slot_chain_end 413640, delta 60, so hard fork
   genesis slot 413700 counted from the previous fork base 445860. The config
   devnet now ships is the fork config that produced. *)
let devnet_expected : Expected.t =
  Forked
    { genesis_time = "2026-08-19T18:00:00.000000Z"
    ; previous_fork_slot_since_genesis = 445860
    ; hard_fork_genesis_slot = 413700
    ; fork_slot_since_genesis = 859560
    ; fork_blockchain_length = 545433
    }

(* Copied next to the test executable by the rule in ./dune, so the assertions
   run against the config that actually ships. *)
let devnet_config_path = "devnet.json"

(* ------------------------------------------------------------------ *)
(* mainnet                                                            *)
(* ------------------------------------------------------------------ *)

(* Mainnet's compiled constants are the ones devnet.ml includes, so the same
   values apply. They are restated rather than shared with [devnet] above to
   keep each network's expectations independently readable: if the two ever
   diverge, only the affected network's block changes. *)
let mainnet : Network_constants.t =
  let (module Compiled) = Genesis_constants.profiled () in
  let compiled = Compiled.genesis_constants in
  { constraint_constants =
      { Compiled.constraint_constants with block_window_duration_ms = 180_000 }
  ; genesis_constants =
      { compiled with
        protocol =
          { compiled.protocol with
            k = 290
          ; slots_per_epoch = 7140
          ; slots_per_sub_window = 7
          ; grace_period_slots = 2160
          ; delta = 0
          }
      }
  }

(* Mainnet hard forked on 2026-09-03, two weeks after devnet, at the end of its
   own schedule: slot_tx_end 393800, slot_chain_end 393900, delta 60, so hard
   fork genesis slot 393960 counted from the previous fork base 564480. *)
let mainnet_expected : Expected.t =
  Forked
    { genesis_time = "2026-09-03T18:00:00.000000Z"
    ; previous_fork_slot_since_genesis = 564480
    ; hard_fork_genesis_slot = 393960
    ; fork_slot_since_genesis = 958440
    ; fork_blockchain_length = 548146
    }

let mainnet_config_path = "mainnet.json"

let () =
  Alcotest.run "Hard fork stop slot schedule"
    [ ( "devnet"
      , suite ~network:devnet ~expected:devnet_expected
          ~config_path:devnet_config_path )
    ; ( "mainnet"
      , suite ~network:mainnet ~expected:mainnet_expected
          ~config_path:mainnet_config_path )
    ]
