open Async_kernel
open Core_kernel
open Signed
open Unsigned
open Currency
open Fold_lib
open Signature_lib
open Snark_params
open Num_util

module Segment_id = Mina_numbers.Nat.Make32 ()

module Wire_types = Mina_wire_types.Consensus_proof_of_stake

module Make_sig (A : Wire_types.Types.S) = struct
  module type S =
    Proof_of_stake_intf.Full
      with type Data.Consensus_state.Value.Stable.V2.t =
        A.Data.Consensus_state.Value.V2.t
end

module Make_str (A : Wire_types.Concrete) = struct
  module Time = Block_time
  module Run = Snark_params.Tick.Run
  module Length = Mina_numbers.Length

  module type CONTEXT = sig
    val logger : Logger.t

    val constraint_constants : Genesis_constants.Constraint_constants.t

    val consensus_constants : Constants.t
  end

  module type CONTEXT_WITH_LEDGER_SYNC = sig
    include CONTEXT

    val ledger_sync_config : Syncable_ledger.daemon_config
  end

  let make_checked t = Snark_params.Tick.Run.make_checked t

  let name = "proof_of_stake"

  let genesis_ledger_total_currency ~ledger =
    Mina_ledger.Ledger.foldi ~init:Amount.zero (Lazy.force ledger)
      ~f:(fun _addr sum (account : Mina_base.Account.t) ->
        (* only default token matters for total currency used to determine stake *)
        if Mina_base.(Token_id.equal account.token_id Token_id.default) then
          Amount.add sum (Balance.to_amount @@ account.balance)
          |> Option.value_exn ?here:None ?error:None
               ~message:"failed to calculate total currency in genesis ledger"
        else sum )

  let genesis_ledger_hash ~ledger =
    Mina_ledger.Ledger.merkle_root (Lazy.force ledger)
    |> Mina_base.Frozen_ledger_hash.of_ledger_hash

  let compute_delegatee_table keys ~iter_accounts =
    let open Mina_base in
    let outer_table = Public_key.Compressed.Table.create () in
    iter_accounts (fun i (acct : Account.t) ->
        if
          Option.is_some acct.delegate
          (* Only default tokens may delegate. *)
          && Token_id.equal acct.token_id Token_id.default
          && Public_key.Compressed.Set.mem keys (Option.value_exn acct.delegate)
        then
          Public_key.Compressed.Table.update outer_table
            (Option.value_exn acct.delegate) ~f:(function
            | None ->
                Account.Index.Table.of_alist_exn [ (i, acct) ]
            | Some table ->
                Account.Index.Table.add_exn table ~key:i ~data:acct ;
                table ) ) ;
    (* TODO: this metric tracking currently assumes that the result of
       compute_delegatee_table is called with the full set of block production
       keypairs every time the set changes, which is true right now, but this
       should be control flow should be refactored to make this clearer *)
    let num_delegators =
      Public_key.Compressed.Table.fold outer_table ~init:0
        ~f:(fun ~key:_ ~data sum -> sum + Account.Index.Table.length data)
    in
    Mina_metrics.Gauge.set Mina_metrics.Consensus.staking_keypairs
      (Float.of_int @@ Public_key.Compressed.Set.length keys) ;
    Mina_metrics.Gauge.set Mina_metrics.Consensus.stake_delegators
      (Float.of_int num_delegators) ;
    outer_table

  let compute_delegatee_table_ledger_db keys ledger =
    O1trace.sync_thread "compute_delegatee_table_ledger_db" (fun () ->
        compute_delegatee_table keys ~iter_accounts:(fun f ->
            Mina_ledger.Ledger.Db.iteri ledger ~f:(fun i acct -> f i acct) ) )

  let compute_delegatee_table_genesis_ledger keys ledger =
    O1trace.sync_thread "compute_delegatee_table_genesis_ledger" (fun () ->
        compute_delegatee_table keys ~iter_accounts:(fun f ->
            Mina_ledger.Ledger.iteri ledger ~f:(fun i acct -> f i acct) ) )

  module Typ = Snark_params.Tick.Typ

  module Configuration = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { delta : int
          ; k : int
          ; slots_per_epoch : int
          ; slot_duration : int
          ; epoch_duration : int
          ; genesis_state_timestamp : Block_time.Stable.V1.t
          ; acceptable_network_delay : int
          }
        [@@deriving yojson, fields]

        let to_latest = Fn.id
      end
    end]

    let t ~constraint_constants ~protocol_constants =
      let constants =
        Constants.create ~constraint_constants ~protocol_constants
      in
      let of_int32 = UInt32.to_int in
      let of_span = Fn.compose Int64.to_int Block_time.Span.to_ms in
      { delta = of_int32 constants.delta
      ; k = of_int32 constants.k
      ; slots_per_epoch = of_int32 constants.slots_per_epoch
      ; slot_duration = of_span constants.slot_duration_ms
      ; epoch_duration = of_span constants.epoch_duration
      ; genesis_state_timestamp = constants.genesis_state_timestamp
      ; acceptable_network_delay = of_span constants.delta_duration
      }
  end

  module Constants = Constants
  module Genesis_epoch_data = Genesis_epoch_data

  module Data = struct
    module Epoch_seed = struct
      include Mina_base.Epoch_seed

      let initial : t = of_hash Outside_hash_image.t

      let update (seed : t) vrf_result =
        let open Random_oracle in
        hash ~init:Hash_prefix_states.epoch_seed
          [| (seed :> Tick.Field.t); vrf_result |]
        |> of_hash

      let update_var (seed : var) vrf_result =
        let open Random_oracle.Checked in
        make_checked (fun () ->
            hash ~init:Hash_prefix_states.epoch_seed
              [| var_to_hash_packed seed; vrf_result |]
            |> var_of_hash_packed )
    end

    module Epoch_and_slot = struct
      type t = Epoch.t * Slot.t [@@deriving sexp]

      let of_time_exn ~(constants : Constants.t) tm : t =
        let epoch = Epoch.of_time_exn tm ~constants in
        let time_since_epoch =
          Time.diff tm (Epoch.start_time epoch ~constants)
        in
        let slot =
          uint32_of_int64
          @@ Int64.Infix.(
               Time.Span.to_ms time_since_epoch
               / Time.Span.to_ms constants.slot_duration_ms)
        in
        (epoch, slot)
    end

    module Block_data = struct
      type t =
        { stake_proof : Stake_proof.t
        ; global_slot : Mina_numbers.Global_slot_since_hard_fork.t
        ; global_slot_since_genesis : Mina_numbers.Global_slot_since_genesis.t
        ; vrf_result : Random_oracle.Digest.t
        }

      let prover_state { stake_proof; _ } = stake_proof

      let global_slot { global_slot; _ } = global_slot

      let epoch_ledger { stake_proof; _ } = stake_proof.ledger

      let global_slot_since_genesis { global_slot_since_genesis; _ } =
        global_slot_since_genesis

      let coinbase_receiver { stake_proof; _ } =
        stake_proof.coinbase_receiver_pk
    end

    module Epoch_data_for_vrf = struct
      [%%versioned
      module Stable = struct
        [@@@no_toplevel_latest_type]

        module V2 = struct
          type t =
            { epoch_ledger : Mina_base.Epoch_ledger.Value.Stable.V1.t
            ; epoch_seed : Mina_base.Epoch_seed.Stable.V1.t
            ; epoch : Mina_numbers.Length.Stable.V1.t
            ; global_slot : Mina_numbers.Global_slot_since_hard_fork.Stable.V1.t
            ; global_slot_since_genesis :
                Mina_numbers.Global_slot_since_genesis.Stable.V1.t
            ; delegatee_table :
                Mina_base.Account.Stable.V2.t
                Mina_base.Account.Index.Stable.V1.Table.t
                Public_key.Compressed.Stable.V1.Table.t
            }
          [@@deriving sexp]

          let to_latest = Fn.id
        end
      end]

      type t = Stable.Latest.t =
        { epoch_ledger : Mina_base.Epoch_ledger.Value.t
        ; epoch_seed : Mina_base.Epoch_seed.t
        ; epoch : Mina_numbers.Length.t
        ; global_slot : Mina_numbers.Global_slot_since_hard_fork.t
        ; global_slot_since_genesis : Mina_numbers.Global_slot_since_genesis.t
        ; delegatee_table :
            Mina_base.Account.t Mina_base.Account.Index.Table.t
            Public_key.Compressed.Table.t
        }
      [@@deriving sexp]
    end

    module Slot_won = struct
      [%%versioned
      module Stable = struct
        [@@@no_toplevel_latest_type]

        module V2 = struct
          type t =
            { delegator :
                Public_key.Compressed.Stable.V1.t
                * Mina_base.Account.Index.Stable.V1.t
            ; producer : Keypair.Stable.V1.t
            ; global_slot : Mina_numbers.Global_slot_since_hard_fork.Stable.V1.t
            ; global_slot_since_genesis :
                Mina_numbers.Global_slot_since_genesis.Stable.V1.t
            ; vrf_result : Consensus_vrf.Output_hash.Stable.V1.t
            }
          [@@deriving sexp]

          let to_latest = Fn.id
        end
      end]

      type t = Stable.Latest.t =
        { delegator : Public_key.Compressed.t * Mina_base.Account.Index.t
        ; producer : Keypair.t
        ; global_slot : Mina_numbers.Global_slot_since_hard_fork.t
        ; global_slot_since_genesis : Mina_numbers.Global_slot_since_genesis.t
        ; vrf_result : Consensus_vrf.Output_hash.t
        }
      [@@deriving sexp]
    end

    module Local_state = struct
      module Snapshot = struct
        module Ledger_snapshot = struct
          type t =
            | Genesis_epoch_ledger of Mina_ledger.Ledger.t
            | Ledger_db of Mina_ledger.Ledger.Db.t

          let merkle_root = function
            | Genesis_epoch_ledger ledger ->
                Mina_ledger.Ledger.merkle_root ledger
            | Ledger_db ledger ->
                Mina_ledger.Ledger.Db.merkle_root ledger

          let compute_delegatee_table keys ledger =
            match ledger with
            | Genesis_epoch_ledger ledger ->
                compute_delegatee_table_genesis_ledger keys ledger
            | Ledger_db ledger ->
                compute_delegatee_table_ledger_db keys ledger

          let close = function
            | Genesis_epoch_ledger _ ->
                ()
            | Ledger_db ledger ->
                Mina_ledger.Ledger.Db.close ledger

          let remove ~location = function
            | Genesis_epoch_ledger _ ->
                ()
            | Ledger_db ledger ->
                Mina_ledger.Ledger.Db.close ledger ;
                File_system.rmrf location

          let ledger_subset keys ledger =
            let open Mina_ledger in
            match ledger with
            | Genesis_epoch_ledger ledger ->
                Sparse_ledger.of_ledger_subset_exn ledger keys
            | Ledger_db db_ledger ->
                let ledger = Ledger.of_database db_ledger in
                let subset_ledger =
                  Sparse_ledger.of_ledger_subset_exn ledger keys
                in
                ignore
                  ( Ledger.unregister_mask_exn ~loc:__LOC__ ledger
                    : Ledger.unattached_mask ) ;
                subset_ledger
        end

        type t =
          { ledger : Ledger_snapshot.t
          ; delegatee_table :
              Mina_base.Account.t Mina_base.Account.Index.Table.t
              Public_key.Compressed.Table.t
          }

        let delegators t key =
          Public_key.Compressed.Table.find t.delegatee_table key

        let to_yojson { ledger; delegatee_table } =
          `Assoc
            [ ( "ledger_hash"
              , Ledger_snapshot.merkle_root ledger
                |> Mina_base.Ledger_hash.to_yojson )
            ; ( "delegators"
              , `Assoc
                  ( Hashtbl.to_alist delegatee_table
                  |> List.map ~f:(fun (key, delegators) ->
                         ( Public_key.Compressed.to_string key
                         , `Assoc
                             ( Hashtbl.to_alist delegators
                             |> List.map ~f:(fun (addr, account) ->
                                    ( Int.to_string addr
                                    , Mina_base.Account.to_yojson account ) ) )
                         ) ) ) )
            ]

        let ledger t = t.ledger
      end

      module Data = struct
        type epoch_ledger_uuids =
          { staking : Uuid.t
          ; next : Uuid.t
          ; genesis_state_hash : Mina_base.State_hash.t
          }

        (* Invariant: Snapshot's delegators are taken from accounts in block_production_pubkeys *)
        type t =
          { mutable staking_epoch_snapshot : Snapshot.t
          ; mutable next_epoch_snapshot : Snapshot.t
          ; last_checked_slot_and_epoch :
              (Epoch.t * Slot.t) Public_key.Compressed.Table.t
          ; mutable last_epoch_delegatee_table :
              Mina_base.Account.t Mina_base.Account.Index.Table.t
              Public_key.Compressed.Table.t
              Option.t
          ; mutable epoch_ledger_uuids : epoch_ledger_uuids
          ; epoch_ledger_location : string
          }

        let to_yojson t =
          `Assoc
            [ ( "staking_epoch_snapshot"
              , [%to_yojson: Snapshot.t] t.staking_epoch_snapshot )
            ; ( "next_epoch_snapshot"
              , [%to_yojson: Snapshot.t] t.next_epoch_snapshot )
            ; ( "last_checked_slot_and_epoch"
              , `Assoc
                  ( Public_key.Compressed.Table.to_alist
                      t.last_checked_slot_and_epoch
                  |> List.map ~f:(fun (key, epoch_and_slot) ->
                         ( Public_key.Compressed.to_string key
                         , [%to_yojson: Epoch.t * Slot.t] epoch_and_slot ) ) )
              )
            ]
      end

      (* The outer ref changes whenever we swap in new staker set; all the snapshots are recomputed *)
      type t = Data.t ref [@@deriving to_yojson]

      let staking_epoch_ledger_location (t : t) =
        !t.epoch_ledger_location ^ Uuid.to_string !t.epoch_ledger_uuids.staking

      let next_epoch_ledger_location (t : t) =
        !t.epoch_ledger_location ^ Uuid.to_string !t.epoch_ledger_uuids.next

      let current_epoch_delegatee_table ~(local_state : t) =
        !local_state.staking_epoch_snapshot.delegatee_table

      let last_epoch_delegatee_table ~(local_state : t) =
        !local_state.last_epoch_delegatee_table

      let current_block_production_keys t =
        Public_key.Compressed.Table.keys !t.Data.last_checked_slot_and_epoch
        |> Public_key.Compressed.Set.of_list

      let make_last_checked_slot_and_epoch_table old_table new_keys ~default =
        let module Set = Public_key.Compressed.Set in
        let module Table = Public_key.Compressed.Table in
        let last_checked_slot_and_epoch = Table.create () in
        Set.iter new_keys ~f:(fun pk ->
            let data = Option.value (Table.find old_table pk) ~default in
            Table.add_exn last_checked_slot_and_epoch ~key:pk ~data ) ;
        last_checked_slot_and_epoch

      let epoch_ledger_uuids_to_yojson
          Data.{ staking; next; genesis_state_hash } =
        `Assoc
          [ ("staking", `String (Uuid.to_string staking))
          ; ("next", `String (Uuid.to_string next))
          ; ( "genesis_state_hash"
            , Mina_base.State_hash.to_yojson genesis_state_hash )
          ]

      let epoch_ledger_uuids_from_file location =
        let open Yojson.Safe.Util in
        let open Result.Let_syntax in
        let json = Yojson.Safe.from_file location in
        let uuid str =
          Result.(
            map_error
              (try_with (fun () -> Uuid.of_string str))
              ~f:(fun ex -> Exn.to_string ex))
        in
        let%bind staking = json |> member "staking" |> to_string |> uuid in
        let%bind next = json |> member "next" |> to_string |> uuid in
        let%map genesis_state_hash =
          json |> member "genesis_state_hash" |> Mina_base.State_hash.of_yojson
        in
        Data.{ staking; next; genesis_state_hash }

      let create_epoch_ledger ~location ~context:(module Context : CONTEXT)
          ~genesis_epoch_ledger =
        let open Context in
        if Sys.file_exists location then (
          [%log info]
            ~metadata:[ ("location", `String location) ]
            "Loading epoch ledger from disk: $location" ;
          Snapshot.Ledger_snapshot.Ledger_db
            (Mina_ledger.Ledger.Db.create ~directory_name:location
               ~depth:constraint_constants.ledger_depth () ) )
        else Genesis_epoch_ledger (Lazy.force genesis_epoch_ledger)

      let create block_producer_pubkeys ~context:(module Context : CONTEXT)
          ~genesis_ledger ~genesis_epoch_data ~epoch_ledger_location
          ~genesis_state_hash =
        let open Context in
        (* TODO: remove this duplicate of the genesis ledger *)
        let genesis_epoch_ledger_staking, genesis_epoch_ledger_next =
          Option.value_map genesis_epoch_data
            ~default:(genesis_ledger, genesis_ledger)
            ~f:(fun { Genesis_epoch_data.staking; next } ->
              ( staking.ledger
              , Option.value_map next ~default:staking.ledger ~f:(fun next ->
                    next.ledger ) ) )
        in
        let epoch_ledger_uuids_location = epoch_ledger_location ^ ".json" in
        let create_new_uuids () =
          let epoch_ledger_uuids =
            Data.
              { staking = Uuid_unix.create ()
              ; next = Uuid_unix.create ()
              ; genesis_state_hash
              }
          in
          Yojson.Safe.to_file epoch_ledger_uuids_location
            (epoch_ledger_uuids_to_yojson epoch_ledger_uuids) ;
          epoch_ledger_uuids
        in
        let ledger_location uuid =
          epoch_ledger_location ^ Uuid.to_string uuid
        in
        let epoch_ledger_uuids =
          if Sys.file_exists epoch_ledger_uuids_location then (
            let epoch_ledger_uuids =
              match
                epoch_ledger_uuids_from_file epoch_ledger_uuids_location
              with
              | Ok res ->
                  res
              | Error str ->
                  [%log error]
                    "Failed to read epoch ledger uuids from file $path: \
                     $error. Creating new uuids.."
                    ~metadata:
                      [ ("path", `String epoch_ledger_uuids_location)
                      ; ("error", `String str)
                      ] ;
                  create_new_uuids ()
            in
            (*If the genesis hash matches and both the files are present. If only one of them is present then it could be stale data and might cause the node to never be able to bootstrap*)
            if
              Mina_base.State_hash.equal epoch_ledger_uuids.genesis_state_hash
                genesis_state_hash
            then epoch_ledger_uuids
            else
              (*Clean-up outdated epoch ledgers*)
              let staking_ledger_location =
                ledger_location epoch_ledger_uuids.staking
              in
              let next_ledger_location =
                ledger_location epoch_ledger_uuids.next
              in
              [%log info]
                "Cleaning up old epoch ledgers with genesis state $state_hash \
                 at locations $staking and $next"
                ~metadata:
                  [ ( "state_hash"
                    , Mina_base.State_hash.to_yojson
                        epoch_ledger_uuids.genesis_state_hash )
                  ; ("staking", `String staking_ledger_location)
                  ; ("next", `String next_ledger_location)
                  ] ;
              File_system.rmrf staking_ledger_location ;
              File_system.rmrf next_ledger_location ;
              create_new_uuids () )
          else create_new_uuids ()
        in
        let staking_epoch_ledger_location =
          ledger_location epoch_ledger_uuids.staking
        in
        let staking_epoch_ledger =
          create_epoch_ledger ~location:staking_epoch_ledger_location
            ~context:(module Context)
            ~genesis_epoch_ledger:genesis_epoch_ledger_staking
        in
        let next_epoch_ledger_location =
          ledger_location epoch_ledger_uuids.next
        in
        let next_epoch_ledger =
          create_epoch_ledger ~location:next_epoch_ledger_location
            ~context:(module Context)
            ~genesis_epoch_ledger:genesis_epoch_ledger_next
        in
        ref
          { Data.staking_epoch_snapshot =
              { Snapshot.ledger = staking_epoch_ledger
              ; delegatee_table =
                  Snapshot.Ledger_snapshot.compute_delegatee_table
                    block_producer_pubkeys staking_epoch_ledger
              }
          ; next_epoch_snapshot =
              { Snapshot.ledger = next_epoch_ledger
              ; delegatee_table =
                  Snapshot.Ledger_snapshot.compute_delegatee_table
                    block_producer_pubkeys next_epoch_ledger
              }
          ; last_checked_slot_and_epoch =
              make_last_checked_slot_and_epoch_table
                (Public_key.Compressed.Table.create ())
                block_producer_pubkeys ~default:(Epoch.zero, Slot.zero)
          ; last_epoch_delegatee_table = None
          ; epoch_ledger_uuids
          ; epoch_ledger_location
          }

      let block_production_keys_swap ~(constants : Constants.t) t
          block_production_pubkeys now =
        let old : Data.t = !t in
        let s { Snapshot.ledger; delegatee_table = _ } =
          { Snapshot.ledger
          ; delegatee_table =
              Snapshot.Ledger_snapshot.compute_delegatee_table
                block_production_pubkeys ledger
          }
        in
        t :=
          { Data.staking_epoch_snapshot = s old.staking_epoch_snapshot
          ; next_epoch_snapshot =
              s old.next_epoch_snapshot
              (* assume these keys are different and therefore we haven't checked any
               * slots or epochs *)
          ; last_checked_slot_and_epoch =
              make_last_checked_slot_and_epoch_table
                !t.Data.last_checked_slot_and_epoch block_production_pubkeys
                ~default:
                  ((* TODO: Be smarter so that we don't have to look at the slot before again *)
                   let epoch, slot =
                     Epoch_and_slot.of_time_exn now ~constants
                   in
                   ( epoch
                   , UInt32.(
                       if compare slot zero > 0 then sub slot one else slot) )
                  )
          ; last_epoch_delegatee_table = None
          ; epoch_ledger_uuids = old.epoch_ledger_uuids
          ; epoch_ledger_location = old.epoch_ledger_location
          }

      type snapshot_identifier = Staking_epoch_snapshot | Next_epoch_snapshot
      [@@deriving to_yojson, equal]

      let get_snapshot (t : t) id =
        match id with
        | Staking_epoch_snapshot ->
            !t.staking_epoch_snapshot
        | Next_epoch_snapshot ->
            !t.next_epoch_snapshot

      let set_snapshot (t : t) id v =
        match id with
        | Staking_epoch_snapshot ->
            !t.staking_epoch_snapshot <- v
        | Next_epoch_snapshot ->
            !t.next_epoch_snapshot <- v

      let reset_snapshot (t : t) id ledger =
        let delegatee_table =
          compute_delegatee_table_ledger_db
            (current_block_production_keys t)
            ledger
        in
        match id with
        | Staking_epoch_snapshot ->
            !t.staking_epoch_snapshot <-
              { delegatee_table
              ; ledger = Snapshot.Ledger_snapshot.Ledger_db ledger
              }
        | Next_epoch_snapshot ->
            !t.next_epoch_snapshot <-
              { delegatee_table
              ; ledger = Snapshot.Ledger_snapshot.Ledger_db ledger
              }

      let next_epoch_ledger (t : t) =
        Snapshot.ledger @@ get_snapshot t Next_epoch_snapshot

      let staking_epoch_ledger (t : t) =
        Snapshot.ledger @@ get_snapshot t Staking_epoch_snapshot

      let _seen_slot (t : t) epoch slot =
        let module Table = Public_key.Compressed.Table in
        let unseens =
          Table.to_alist !t.last_checked_slot_and_epoch
          |> List.filter_map ~f:(fun (pk, last_checked_epoch_and_slot) ->
                 let i =
                   Tuple2.compare ~cmp1:Epoch.compare ~cmp2:Slot.compare
                     last_checked_epoch_and_slot (epoch, slot)
                 in
                 if i > 0 then None
                 else if i = 0 then
                   (*vrf evaluation was stopped at this point because it was either the end of the epoch or the key won this slot; re-check this slot when staking keys are reset so that we don't skip producing block. This will not occur in the normal flow because [slot] will be greater than the last-checked-slot*)
                   Some pk
                 else (
                   Table.set !t.last_checked_slot_and_epoch ~key:pk
                     ~data:(epoch, slot) ;
                   Some pk ) )
        in
        match unseens with
        | [] ->
            `All_seen
        | nel ->
            `Unseen (Public_key.Compressed.Set.of_list nel)

      module For_tests = struct
        type nonrec snapshot_identifier = snapshot_identifier =
          | Staking_epoch_snapshot
          | Next_epoch_snapshot

        let set_snapshot = set_snapshot

        (* if all we're testing is the ledger sync, empty delegatee table sufficient *)
        let snapshot_of_ledger (ledger : Snapshot.Ledger_snapshot.t) :
            Snapshot.t =
          { ledger; delegatee_table = Public_key.Compressed.Table.create () }
      end
    end

    module Epoch_ledger = struct
      include Mina_base.Epoch_ledger

      let genesis ~ledger =
        { Poly.hash = genesis_ledger_hash ~ledger
        ; total_currency = genesis_ledger_total_currency ~ledger
        }
    end

    module Vrf = struct
      include Consensus_vrf
      module T = Integrated

      type _ Snarky_backendless.Request.t +=
        | Winner_address :
            Mina_base.Account.Index.t Snarky_backendless.Request.t
        | Winner_pk : Public_key.Compressed.t Snarky_backendless.Request.t
        | Coinbase_receiver_pk :
            Public_key.Compressed.t Snarky_backendless.Request.t
        | Producer_private_key : Scalar.value Snarky_backendless.Request.t
        | Producer_public_key : Public_key.t Snarky_backendless.Request.t

      let%snarkydef.Snark_params.Tick get_vrf_evaluation
          ~(constraint_constants : Genesis_constants.Constraint_constants.t)
          shifted ~block_stake_winner ~block_creator ~ledger ~message =
        let open Mina_base in
        let open Snark_params.Tick in
        let%bind private_key =
          request_witness Scalar.typ (As_prover.return Producer_private_key)
        in
        let staker_addr = message.Message.delegator in
        let%bind account =
          with_label __LOC__ (fun () ->
              Frozen_ledger_hash.get ~depth:constraint_constants.ledger_depth
                ledger staker_addr )
        in
        let%bind () =
          [%with_label_ "Account is for the default token"] (fun () ->
              make_checked (fun () ->
                  Token_id.(
                    Checked.Assert.equal account.token_id
                      (Checked.constant default)) ) )
        in
        let%bind () =
          [%with_label_ "Block stake winner matches account pk"] (fun () ->
              Public_key.Compressed.Checked.Assert.equal block_stake_winner
                account.public_key )
        in
        let%bind () =
          [%with_label_ "Block creator matches delegate pk"] (fun () ->
              Public_key.Compressed.Checked.Assert.equal block_creator
                account.delegate )
        in
        let%bind delegate =
          [%with_label_ "Decompress delegate pk"] (fun () ->
              Public_key.decompress_var account.delegate )
        in
        let%map evaluation =
          with_label __LOC__ (fun () ->
              T.Checked.eval_and_check_public_key shifted ~private_key
                ~public_key:delegate message )
        in
        (evaluation, account)

      module Checked = struct
        let%snarkydef.Tick check
            ~(constraint_constants : Genesis_constants.Constraint_constants.t)
            shifted ~(epoch_ledger : Epoch_ledger.var) ~block_stake_winner
            ~block_creator ~global_slot ~seed =
          let open Snark_params.Tick in
          let%bind winner_addr =
            request_witness
              (Mina_base.Account.Index.Unpacked.typ
                 ~ledger_depth:constraint_constants.ledger_depth )
              (As_prover.return Winner_address)
          in
          let%bind result, winner_account =
            get_vrf_evaluation ~constraint_constants shifted
              ~ledger:epoch_ledger.hash ~block_stake_winner ~block_creator
              ~message:{ Message.global_slot; seed; delegator = winner_addr }
          in
          let my_stake = winner_account.balance in
          let%bind truncated_result = Output.Checked.truncate result in
          let%map satisifed =
            Threshold.Checked.is_satisfied ~my_stake
              ~total_stake:epoch_ledger.total_currency truncated_result
          in
          (satisifed, result, truncated_result, winner_account)
      end

      let eval = T.eval

      module Precomputed = struct
        let genesis_winner = Key_gen.Sample_keypairs.genesis_winner

        let genesis_stake_proof :
            genesis_epoch_ledger:Mina_ledger.Ledger.t Lazy.t -> Stake_proof.t =
         fun ~genesis_epoch_ledger ->
          let pk, sk = genesis_winner in
          let dummy_sparse_ledger =
            Mina_ledger.Sparse_ledger.of_ledger_subset_exn
              (Lazy.force genesis_epoch_ledger)
              [ Mina_base.(Account_id.create pk Token_id.default) ]
          in
          { delegator = 0
          ; delegator_pk = pk
          ; coinbase_receiver_pk = pk
          ; ledger = dummy_sparse_ledger
          ; producer_private_key = sk
          ; producer_public_key = Public_key.decompress_exn pk
          }

        let handler :
               constraint_constants:Genesis_constants.Constraint_constants.t
            -> genesis_epoch_ledger:Mina_ledger.Ledger.t Lazy.t
            -> Snark_params.Tick.Handler.t =
         fun ~constraint_constants ~genesis_epoch_ledger ->
          let pk, sk = genesis_winner in
          let dummy_sparse_ledger =
            Mina_ledger.Sparse_ledger.of_ledger_subset_exn
              (Lazy.force genesis_epoch_ledger)
              [ Mina_base.(Account_id.create pk Token_id.default) ]
          in
          let empty_pending_coinbase =
            Mina_base.Pending_coinbase.create
              ~depth:constraint_constants.pending_coinbase_depth ()
            |> Or_error.ok_exn
          in
          let ledger_handler =
            unstage (Mina_ledger.Sparse_ledger.handler dummy_sparse_ledger)
          in
          let pending_coinbase_handler =
            unstage
              (Mina_base.Pending_coinbase.handler
                 ~depth:constraint_constants.pending_coinbase_depth
                 empty_pending_coinbase ~is_new_stack:true )
          in
          let handlers =
            Snarky_backendless.Request.Handler.(
              push
                (push fail (create_single pending_coinbase_handler))
                (create_single ledger_handler))
          in
          fun (With { request; respond }) ->
            match request with
            | Winner_address ->
                respond (Provide 0)
            | Winner_pk ->
                respond (Provide pk)
            | Coinbase_receiver_pk ->
                respond (Provide pk)
            | Producer_private_key ->
                respond (Provide sk)
            | Producer_public_key ->
                respond (Provide (Public_key.decompress_exn pk))
            | _ ->
                respond
                  (Provide
                     (Option.value_exn ~message:"unhandled request"
                        (Snarky_backendless.Request.Handler.run handlers request) )
                  )
      end

      let check ~context:(module Context : CONTEXT)
          ~(global_slot : Mina_numbers.Global_slot_since_hard_fork.t) ~seed
          ~producer_private_key ~producer_public_key ~total_stake
          ~(get_delegators :
                Public_key.Compressed.t
             -> Mina_base.Account.t Mina_base.Account.Index.Table.t option ) =
        let open Context in
        let open Message in
        let open Interruptible.Let_syntax in
        let delegators =
          get_delegators producer_public_key
          |> Option.value_map ~f:Hashtbl.to_alist ~default:[]
        in
        let rec go acc = function
          | [] ->
              Interruptible.return acc
          | (delegator, (account : Mina_base.Account.t)) :: delegators ->
              let%bind () = Interruptible.return () in
              let vrf_result =
                T.eval ~constraint_constants ~private_key:producer_private_key
                  { global_slot; seed; delegator }
              in
              let truncated_vrf_result = Output.truncate vrf_result in
              [%log debug]
                "VRF result for delegator: $delegator, balance: $balance, \
                 amount: $amount, result: $result"
                ~metadata:
                  [ ( "delegator"
                    , `Int (Mina_base.Account.Index.to_int delegator) )
                  ; ( "delegator_pk"
                    , Public_key.Compressed.to_yojson account.public_key )
                  ; ("balance", `Int (Balance.to_nanomina_int account.balance))
                  ; ("amount", `Int (Amount.to_nanomina_int total_stake))
                  ; ( "result"
                    , `String
                        (* use sexp representation; int might be too small *)
                        ( Fold.string_bits truncated_vrf_result
                        |> Bignum_bigint.of_bit_fold_lsb
                        |> Bignum_bigint.sexp_of_t |> Sexp.to_string ) )
                  ] ;
              Mina_metrics.Counter.inc_one
                Mina_metrics.Consensus.vrf_evaluations ;
              if
                Threshold.is_satisfied ~my_stake:account.balance ~total_stake
                  truncated_vrf_result
              then
                let string_of_blake2 =
                  Blake2.(Fn.compose to_raw_string digest_string)
                in
                let vrf_eval = string_of_blake2 truncated_vrf_result in
                let this_vrf () =
                  go
                    (Some
                       ( `Vrf_eval vrf_eval
                       , `Vrf_output vrf_result
                       , `Delegator (account.public_key, delegator) ) )
                    delegators
                in
                match acc with
                | Some (`Vrf_eval prev_best_vrf_eval, _, _) ->
                    if String.compare prev_best_vrf_eval vrf_eval < 0 then
                      this_vrf ()
                    else go acc delegators
                | None ->
                    this_vrf ()
              else go acc delegators
        in
        go None delegators
    end

    module Optional_state_hash = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t = Mina_base.State_hash.Stable.V1.t option
          [@@deriving sexp, compare, hash, to_yojson]

          let to_latest = Fn.id
        end
      end]
    end

    module Epoch_data = struct
      include Mina_base.Epoch_data

      module Make (Lock_checkpoint : sig
        type t [@@deriving sexp, compare, hash, to_yojson]

        val typ : (Mina_base.State_hash.var, t) Typ.t

        val to_input :
          t -> Snark_params.Tick.Field.t Random_oracle.Input.Chunked.t

        val null : t
      end) =
      struct
        open Snark_params

        module Value = struct
          type t =
            ( Epoch_ledger.Value.t
            , Epoch_seed.t
            , Mina_base.State_hash.t
            , Lock_checkpoint.t
            , Length.t )
            Poly.t
          [@@deriving sexp, compare, hash, to_yojson]
        end

        let typ : (var, Value.t) Typ.t =
          Typ.of_hlistable
            [ Epoch_ledger.typ
            ; Epoch_seed.typ
            ; Mina_base.State_hash.typ
            ; Lock_checkpoint.typ
            ; Length.typ
            ]
            ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
            ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

        let to_input
            ({ ledger; seed; start_checkpoint; lock_checkpoint; epoch_length } :
              Value.t ) =
          let open Random_oracle.Input.Chunked in
          List.reduce_exn ~f:append
            [ field (seed :> Tick.Field.t)
            ; field (start_checkpoint :> Tick.Field.t)
            ; Length.to_input epoch_length
            ; Epoch_ledger.to_input ledger
            ; Lock_checkpoint.to_input lock_checkpoint
            ]

        let var_to_input
            ({ ledger; seed; start_checkpoint; lock_checkpoint; epoch_length } :
              var ) =
          let open Random_oracle.Input.Chunked in
          List.reduce_exn ~f:append
            [ field (Epoch_seed.var_to_hash_packed seed)
            ; field (Mina_base.State_hash.var_to_hash_packed start_checkpoint)
            ; Length.Checked.to_input epoch_length
            ; Epoch_ledger.var_to_input ledger
            ; field (Mina_base.State_hash.var_to_hash_packed lock_checkpoint)
            ]

        let genesis ~(genesis_epoch_data : Genesis_epoch_data.Data.t) =
          { Poly.ledger = Epoch_ledger.genesis ~ledger:genesis_epoch_data.ledger
          ; seed = genesis_epoch_data.seed
          ; start_checkpoint = Mina_base.State_hash.(of_hash zero)
          ; lock_checkpoint = Lock_checkpoint.null
          ; epoch_length = Length.of_int 1
          }
      end

      module T = struct
        include Mina_base.State_hash

        let to_input (t : t) =
          Random_oracle.Input.Chunked.field (t :> Tick.Field.t)

        let null = Mina_base.State_hash.(of_hash zero)
      end

      module Staking = Make (T)
      module Next = Make (T)

      (* stable-versioned types are disallowed as functor application results
         we create them outside the results, and make sure they match the corresponding non-versioned types
      *)

      module Staking_value_versioned = struct
        module Value = struct
          module Lock_checkpoint = Mina_base.State_hash

          [%%versioned
          module Stable = struct
            module V1 = struct
              type t =
                ( Epoch_ledger.Value.Stable.V1.t
                , Epoch_seed.Stable.V1.t
                , Mina_base.State_hash.Stable.V1.t
                , Lock_checkpoint.Stable.V1.t
                , Length.Stable.V1.t )
                Poly.Stable.V1.t
              [@@deriving sexp, compare, equal, hash, yojson]

              let to_latest = Fn.id
            end
          end]

          let (_ : (Stable.Latest.t, Staking.Value.t) Type_equal.t) =
            Type_equal.T
        end
      end

      module Next_value_versioned = struct
        module Value = struct
          module Lock_checkpoint = Mina_base.State_hash

          [%%versioned
          module Stable = struct
            module V1 = struct
              type t =
                ( Epoch_ledger.Value.Stable.V1.t
                , Epoch_seed.Stable.V1.t
                , Mina_base.State_hash.Stable.V1.t
                , Lock_checkpoint.Stable.V1.t
                , Length.Stable.V1.t )
                Poly.Stable.V1.t
              [@@deriving sexp, compare, equal, hash, yojson]

              let to_latest = Fn.id
            end
          end]

          type _unused = unit constraint Stable.Latest.t = Next.Value.t
        end
      end

      let next_to_staking (next : Next.Value.t) : Staking.Value.t = next

      let update_pair
          ((staking_data, next_data) : Staking.Value.t * Next.Value.t)
          epoch_count ~prev_epoch ~next_epoch ~next_slot
          ~prev_protocol_state_hash ~producer_vrf_result ~snarked_ledger_hash
          ~genesis_ledger_hash ~total_currency ~(constants : Constants.t) =
        let next_staking_ledger =
          (*If snarked ledger hash is still the genesis ledger hash then the epoch ledger should continue to be `next_data.ledger`. This is because the epoch ledgers at genesis can be different from the genesis ledger*)
          if
            Mina_base.Frozen_ledger_hash.equal snarked_ledger_hash
              genesis_ledger_hash
          then next_data.ledger
          else { Epoch_ledger.Poly.hash = snarked_ledger_hash; total_currency }
        in
        let staking_data', next_data', epoch_count' =
          if Epoch.(next_epoch > prev_epoch) then
            ( next_to_staking next_data
            , { Poly.seed = next_data.seed
              ; ledger = next_staking_ledger
              ; start_checkpoint =
                  prev_protocol_state_hash
                  (* TODO: We need to make sure issue #2328 is properly addressed. *)
              ; lock_checkpoint = Mina_base.State_hash.(of_hash zero)
              ; epoch_length = Length.of_int 1
              }
            , Length.succ epoch_count )
          else (
            assert (Epoch.equal next_epoch prev_epoch) ;
            ( staking_data
            , Poly.
                { next_data with
                  epoch_length = Length.succ next_data.epoch_length
                }
            , epoch_count ) )
        in
        let curr_seed, curr_lock_checkpoint =
          if Slot.in_seed_update_range next_slot ~constants then
            ( Epoch_seed.update next_data'.seed producer_vrf_result
            , prev_protocol_state_hash )
          else (next_data'.seed, next_data'.lock_checkpoint)
        in
        let next_data'' =
          Poly.
            { next_data' with
              seed = curr_seed
            ; lock_checkpoint = curr_lock_checkpoint
            }
        in
        (staking_data', next_data'', epoch_count')
    end

    module Consensus_transition = struct
      module Value = Mina_numbers.Global_slot_since_hard_fork
      include Value

      type var = Checked.t

      let genesis = zero
    end

    module Consensus_time = struct
      (* since hard fork *)
      include Global_slot

      let to_string_hum = time_hum

      (* externally, we are only interested in when the slot starts *)
      let to_time ~(constants : Constants.t) t = start_time ~constants t

      (* create dummy block to split map on *)
      let get_old ~constants (t : Global_slot.t) : Global_slot.t =
        let ( `Acceptable_network_delay _
            , `Gc_width _
            , `Gc_width_epoch gc_width_epoch
            , `Gc_width_slot gc_width_slot
            , `Gc_interval _ ) =
          Constants.gc_parameters constants
        in
        let gs = of_epoch_and_slot ~constants (gc_width_epoch, gc_width_slot) in
        if Global_slot.(t < gs) then
          (* block not beyond gc_width *)
          Global_slot.zero ~constants
        else
          (* subtract epoch, slot components of gc_width *)
          Global_slot.diff ~constants t (gc_width_epoch, gc_width_slot)

      let to_uint32 t =
        Global_slot.slot_number t
        |> Mina_numbers.Global_slot_since_hard_fork.to_uint32

      let to_global_slot = slot_number

      let of_global_slot ~(constants : Constants.t) slot =
        of_slot_number ~constants slot
    end

    module Min_window_density = struct
      (* Three cases for updating the densities of sub-windows
         - same sub-window, then add 1 to the sub-window densities
         - passed a few sub_windows, but didn't skip a window, then
         assign 0 to all the skipped sub-windows, then mark next sub-window density to be 1
         - skipped more than a window, set every sub-window to be 0 and mark next sub-window density to be 1
      *)

      let update_min_window_density ~incr_window ~constants ~prev_global_slot
          ~next_global_slot ~prev_sub_window_densities ~prev_min_window_density
          =
        (* This function takes the previous window (prev_sub_window_densities) and the next_global_slot
           (e.g. the slot of the new block) and returns minimum window density and the new block's
           window (i.e. the next window).

           The current window is obtained by projecting the previous window to the next_global_slot
           as described in the Mina consensus spec.

           Next, we use the current window and prev_min_window_density to compute the minimum window density.

           Finally, we update the current window to obtain the next window that accounts for the presenence
           of the new block.  Note that we only increment the block's sub-window when the incr_window
           parameter is true, which happens when creating a new block, but not when evaluating virtual
           minimum window densities (a.k.a. the relative minimum window density) for the long-range fork rule.

           In the following code, we deal with three different windows
           * Previous window - the previous window
           (prev_global_sub_window - sub_windows_per_window, prev_global_sub_window]

           * Current window  - the projected window used to compute the minimum window density
           [next_global_sub_window - sub_windows_per_window, next_global_sub_window)

           * Next window     - the new (or virtual) block's window that is returned
           (next_global_sub_window - sub_windows_per_window, next_global_sub_window]

           All of these are derived from prev_sub_window_densities using ring-shifting and relative sub-window indexes.
        *)
        let prev_global_sub_window =
          Global_sub_window.of_global_slot ~constants prev_global_slot
        in
        let next_global_sub_window =
          Global_sub_window.of_global_slot ~constants next_global_slot
        in
        (*
          Compute the relative sub-window indexes in [0, sub_windows_per_window) needed for ring-shifting
         *)
        let prev_relative_sub_window =
          Global_sub_window.sub_window ~constants prev_global_sub_window
        in
        let next_relative_sub_window =
          Global_sub_window.sub_window ~constants next_global_sub_window
        in

        let same_sub_window =
          Global_sub_window.equal prev_global_sub_window next_global_sub_window
        in

        (* This function checks whether the current window overlaps with the previous window.
         *   N.B. this requires the precondition that next_global_sub_window >= prev_global_sub_window
         *        whenever update_min_window_density is called.
         *)
        let overlapping_window =
          Global_sub_window.(
            add prev_global_sub_window
              (constant constants.sub_windows_per_window)
            >= next_global_sub_window)
        in

        (* Compute the current window (equivalent to ring-shifting)
           If we are not in the same sub-window and the previous window
           and the current windows overlap, then we zero the densities
           between, and not including, prev and next (relative).
        *)
        let current_sub_window_densities =
          List.mapi prev_sub_window_densities ~f:(fun i density ->
              let gt_prev_sub_window =
                Sub_window.(of_int i > prev_relative_sub_window)
              in
              let lt_next_sub_window =
                Sub_window.(of_int i < next_relative_sub_window)
              in
              let within_range =
                if
                  UInt32.compare prev_relative_sub_window
                    next_relative_sub_window
                  < 0
                then gt_prev_sub_window && lt_next_sub_window
                else gt_prev_sub_window || lt_next_sub_window
              in
              if same_sub_window then density
              else if overlapping_window && not within_range then density
              else Length.zero )
        in
        let current_window_density =
          List.fold current_sub_window_densities ~init:Length.zero ~f:Length.add
        in

        (* Compute minimum window density, taking into account the grace-period *)
        let min_window_density =
          if
            same_sub_window
            || Mina_numbers.Global_slot_since_hard_fork.compare
                 (Global_slot.slot_number next_global_slot)
                 constants.grace_period_end
               < 0
          then prev_min_window_density
          else Length.min current_window_density prev_min_window_density
        in

        (* Compute the next window by mutating the current window *)
        let next_sub_window_densities =
          List.mapi current_sub_window_densities ~f:(fun i density ->
              let is_next_sub_window =
                Sub_window.(of_int i = next_relative_sub_window)
              in
              if is_next_sub_window then
                let f = if incr_window then Length.succ else Fn.id in
                if same_sub_window then f density else f Length.zero
              else density )
        in

        (* Final result is the min window density and window for the new (or virtual) block *)
        (min_window_density, next_sub_window_densities)

      module Checked = struct
        let%snarkydef.Tick update_min_window_density
            ~(constants : Constants.var) ~prev_global_slot ~next_global_slot
            ~prev_sub_window_densities ~prev_min_window_density =
          (* Please see Min_window_density.update_min_window_density for documentation *)
          let open Tick in
          let open Tick.Checked.Let_syntax in
          let%bind prev_global_sub_window =
            Global_sub_window.Checked.of_global_slot ~constants prev_global_slot
          in
          let%bind next_global_sub_window =
            Global_sub_window.Checked.of_global_slot ~constants next_global_slot
          in
          let%bind prev_relative_sub_window =
            Global_sub_window.Checked.sub_window ~constants
              prev_global_sub_window
          in
          let%bind next_relative_sub_window =
            Global_sub_window.Checked.sub_window ~constants
              next_global_sub_window
          in
          let%bind same_sub_window =
            Global_sub_window.Checked.equal prev_global_sub_window
              next_global_sub_window
          in
          let%bind overlapping_window =
            Global_sub_window.Checked.(
              let%bind x =
                add prev_global_sub_window constants.sub_windows_per_window
              in
              x >= next_global_sub_window)
          in
          let if_ cond ~then_ ~else_ =
            let%bind cond = cond and then_ = then_ and else_ = else_ in
            Length.Checked.if_ cond ~then_ ~else_
          in
          let%bind current_sub_window_densities =
            Checked.List.mapi prev_sub_window_densities ~f:(fun i density ->
                let%bind gt_prev_sub_window =
                  Sub_window.Checked.(
                    constant (UInt32.of_int i) > prev_relative_sub_window)
                in
                let%bind lt_next_sub_window =
                  Sub_window.Checked.(
                    constant (UInt32.of_int i) < next_relative_sub_window)
                in
                let%bind within_range =
                  Sub_window.Checked.(
                    let if_ cond ~then_ ~else_ =
                      let%bind cond = cond
                      and then_ = then_
                      and else_ = else_ in
                      Boolean.if_ cond ~then_ ~else_
                    in
                    if_
                      (prev_relative_sub_window < next_relative_sub_window)
                      ~then_:Boolean.(gt_prev_sub_window &&& lt_next_sub_window)
                      ~else_:Boolean.(gt_prev_sub_window ||| lt_next_sub_window))
                in
                if_
                  (Checked.return same_sub_window)
                  ~then_:(Checked.return density)
                  ~else_:
                    (if_
                       Boolean.(overlapping_window && not within_range)
                       ~then_:(Checked.return density)
                       ~else_:(Checked.return Length.Checked.zero) ) )
          in
          let%bind current_window_density =
            Checked.List.fold current_sub_window_densities
              ~init:Length.Checked.zero ~f:Length.Checked.add
          in
          let%bind min_window_density =
            let%bind in_grace_period =
              Global_slot.Checked.( < ) next_global_slot
                (Global_slot.Checked.of_slot_number ~constants
                   constants.grace_period_end )
            in
            if_
              Boolean.(same_sub_window ||| in_grace_period)
              ~then_:(Checked.return prev_min_window_density)
              ~else_:
                (Length.Checked.min current_window_density
                   prev_min_window_density )
          in
          let%bind next_sub_window_densities =
            Checked.List.mapi current_sub_window_densities ~f:(fun i density ->
                let%bind is_next_sub_window =
                  Sub_window.Checked.(
                    constant (UInt32.of_int i) = next_relative_sub_window)
                in
                if_
                  (Checked.return is_next_sub_window)
                  ~then_:
                    (if_
                       (Checked.return same_sub_window)
                       ~then_:Length.Checked.(succ density)
                       ~else_:Length.Checked.(succ zero) )
                  ~else_:(Checked.return density) )
          in
          return (min_window_density, next_sub_window_densities)
      end

      let%test_module "Min window length tests" =
        ( module struct
          (* This is the reference implementation, which is much more readable than
             the actual implementation. The reason this one is not implemented is because
             array-indexing is not supported in Snarky. We could use list-indexing, but it
             takes O(n) instead of O(1).
          *)

          let update_min_window_density_reference_implementation ~constants
              ~prev_global_slot ~next_global_slot ~prev_sub_window_densities
              ~prev_min_window_density =
            let prev_global_sub_window =
              Global_sub_window.of_global_slot ~constants prev_global_slot
            in
            let next_global_sub_window =
              Global_sub_window.of_global_slot ~constants next_global_slot
            in
            let sub_window_diff =
              UInt32.(
                to_int
                @@ min (succ constants.sub_windows_per_window)
                @@ Global_sub_window.sub next_global_sub_window
                     prev_global_sub_window)
            in
            let n = Array.length prev_sub_window_densities in
            let current_sub_window_densities =
              Array.init n ~f:(fun i ->
                  if i + sub_window_diff < n then
                    prev_sub_window_densities.(i + sub_window_diff)
                  else Length.zero )
            in
            let current_window_density =
              Array.fold current_sub_window_densities ~init:Length.zero
                ~f:Length.add
            in
            let min_window_density =
              if
                sub_window_diff = 0
                || Mina_numbers.Global_slot_since_hard_fork.compare
                     (Global_slot.slot_number next_global_slot)
                     constants.grace_period_end
                   < 0
              then prev_min_window_density
              else Length.min current_window_density prev_min_window_density
            in
            current_sub_window_densities.(n - 1) <-
              Length.succ current_sub_window_densities.(n - 1) ;
            (min_window_density, current_sub_window_densities)

          let constants = Lazy.force Constants.for_unit_tests

          (* converting the input for actual implementation to the input required by the
             reference implementation *)
          let actual_to_reference ~prev_global_slot ~prev_sub_window_densities =
            let prev_global_sub_window =
              Global_sub_window.of_global_slot ~constants prev_global_slot
            in
            let prev_relative_sub_window =
              Sub_window.to_int
              @@ Global_sub_window.sub_window ~constants prev_global_sub_window
            in
            List.to_array
            @@ List.drop prev_sub_window_densities prev_relative_sub_window
            @ List.take prev_sub_window_densities prev_relative_sub_window
            @ [ List.nth_exn prev_sub_window_densities prev_relative_sub_window
              ]

          (* slot_diff are generated in such a way so that we can test different cases
             in the update function, I use a weighted union to generate it.
             weight | range of the slot diff
             1      | [0*slots_per_sub_window, 1*slots_per_sub_window)
             1/4    | [1*slots_per_sub_window, 2*slots_per_sub_window)
             1/9    | [2*slots_per_sub_window, 3*slots_per_sub_window)
             ...
             1/n^2  | [n*slots_per_sub_window, (n+1)*slots_per_sub_window)
          *)
          let gen_slot_diff =
            let to_int = Length.to_int in
            Quickcheck.Generator.weighted_union
            @@ List.init
                 (2 * to_int constants.sub_windows_per_window)
                 ~f:(fun i ->
                   ( 1.0 /. (Float.of_int (i + 1) ** 2.)
                   , Core.Int.gen_incl
                       (i * to_int constants.slots_per_sub_window)
                       ((i + 1) * to_int constants.slots_per_sub_window) ) )

          let num_global_slots_to_test = 1

          (* generate an initial global_slot and a list of successive global_slot following
             the initial slot. The length of the list is fixed because this same list would
             also passed into a snarky computation, and the *Typ* of the list requires a
             fixed length. *)
          let gen_global_slots :
              (Global_slot.t * Global_slot.t list) Quickcheck.Generator.t =
            let open Quickcheck.Generator in
            let open Quickcheck.Generator.Let_syntax in
            let module GS = Mina_numbers.Global_slot_since_hard_fork in
            let%bind prev_global_slot = small_positive_int in
            let%bind slot_diffs =
              Core.List.gen_with_length num_global_slots_to_test gen_slot_diff
            in
            let _, global_slots =
              List.fold slot_diffs ~init:(prev_global_slot, [])
                ~f:(fun (prev_global_slot, acc) slot_diff ->
                  let next_global_slot = prev_global_slot + slot_diff in
                  (next_global_slot, next_global_slot :: acc) )
            in
            return
              ( Global_slot.of_slot_number ~constants
                  (GS.of_int prev_global_slot)
              , List.map global_slots ~f:(fun s ->
                    Global_slot.of_slot_number ~constants (GS.of_int s) )
                |> List.rev )

          let gen_length =
            Quickcheck.Generator.union
            @@ List.init (Length.to_int constants.slots_per_sub_window)
                 ~f:(fun n -> Quickcheck.Generator.return @@ Length.of_int n)

          let gen_min_window_density =
            let open Quickcheck.Generator in
            let open Quickcheck.Generator.Let_syntax in
            let%bind prev_sub_window_densities =
              list_with_length
                (Length.to_int constants.sub_windows_per_window)
                gen_length
            in
            let min_window_density =
              let initial xs = List.(rev (tl_exn (rev xs))) in
              List.fold
                (initial prev_sub_window_densities)
                ~init:Length.zero ~f:Length.add
            in
            return (min_window_density, prev_sub_window_densities)

          let gen =
            Quickcheck.Generator.tuple2 gen_global_slots gen_min_window_density

          let update_several_times ~f ~prev_global_slot ~next_global_slots
              ~prev_sub_window_densities ~prev_min_window_density ~constants =
            List.fold next_global_slots
              ~init:
                ( prev_global_slot
                , prev_sub_window_densities
                , prev_min_window_density )
              ~f:(fun
                   ( prev_global_slot
                   , prev_sub_window_densities
                   , prev_min_window_density )
                   next_global_slot
                 ->
                let min_window_density, sub_window_densities =
                  f ~constants ~prev_global_slot ~next_global_slot
                    ~prev_sub_window_densities ~prev_min_window_density
                in
                (next_global_slot, sub_window_densities, min_window_density) )

          let update_several_times_checked ~f ~prev_global_slot
              ~next_global_slots ~prev_sub_window_densities
              ~prev_min_window_density ~constants =
            let open Tick.Checked in
            let open Tick.Checked.Let_syntax in
            List.fold next_global_slots
              ~init:
                ( prev_global_slot
                , prev_sub_window_densities
                , prev_min_window_density )
              ~f:(fun
                   ( prev_global_slot
                   , prev_sub_window_densities
                   , prev_min_window_density )
                   next_global_slot
                 ->
                let%bind min_window_density, sub_window_densities =
                  f ~constants ~prev_global_slot ~next_global_slot
                    ~prev_sub_window_densities ~prev_min_window_density
                in
                return
                  (next_global_slot, sub_window_densities, min_window_density) )

          let%test_unit "the actual implementation is equivalent to the \
                         reference implementation" =
            Quickcheck.test ~trials:100 gen
              ~f:(fun
                   ( ((prev_global_slot : Global_slot.t), next_global_slots)
                   , (prev_min_window_density, prev_sub_window_densities) )
                 ->
                let _, _, min_window_density1 =
                  update_several_times
                    ~f:(update_min_window_density ~incr_window:true)
                    ~prev_global_slot ~next_global_slots
                    ~prev_sub_window_densities ~prev_min_window_density
                    ~constants
                in
                let _, _, min_window_density2 =
                  update_several_times
                    ~f:update_min_window_density_reference_implementation
                    ~prev_global_slot ~next_global_slots
                    ~prev_sub_window_densities:
                      (actual_to_reference ~prev_global_slot
                         ~prev_sub_window_densities )
                    ~prev_min_window_density ~constants
                in
                assert (Length.(equal min_window_density1 min_window_density2)) )

          let%test_unit "Inside snark computation is equivalent to outside \
                         snark computation" =
            Quickcheck.test ~trials:100 gen
              ~f:(fun (slots, min_window_densities) ->
                Test_util.test_equal
                  (Typ.tuple3
                     (Typ.tuple2 Global_slot.typ
                        (Typ.list ~length:num_global_slots_to_test
                           Global_slot.typ ) )
                     (Typ.tuple2 Length.typ
                        (Typ.list
                           ~length:
                             (Length.to_int constants.sub_windows_per_window)
                           Length.typ ) )
                     Constants.typ )
                  (Typ.tuple3 Global_slot.typ
                     (Typ.list
                        ~length:(Length.to_int constants.sub_windows_per_window)
                        Length.typ )
                     Length.typ )
                  (fun ( (prev_global_slot, next_global_slots)
                       , (prev_min_window_density, prev_sub_window_densities)
                       , constants ) ->
                    update_several_times_checked
                      ~f:Checked.update_min_window_density ~prev_global_slot
                      ~next_global_slots ~prev_sub_window_densities
                      ~prev_min_window_density ~constants )
                  (fun ( (prev_global_slot, next_global_slots)
                       , (prev_min_window_density, prev_sub_window_densities)
                       , constants ) ->
                    update_several_times
                      ~f:(update_min_window_density ~incr_window:true)
                      ~prev_global_slot ~next_global_slots
                      ~prev_sub_window_densities ~prev_min_window_density
                      ~constants )
                  (slots, min_window_densities, constants) )
        end )
    end

    (* We have a list of state hashes. When we extend the blockchain,
       we see if the **previous** state should be saved as a checkpoint.
       This is because we have convenient access to the entire previous
       protocol state hash.

       We divide the slots of an epoch into "checkpoint windows": chunks of
       size [checkpoint_window_size]. The goal is to record the first block
       in a given window as a check-point if there are any blocks in that
       window, and zero checkpoints if the window was empty.

       To that end, we store in each state a bit [checkpoint_window_filled] which
       is true iff there has already been a state in the history of the given state
       which is in the same checkpoint window as the given state.
    *)
    module Consensus_state = struct
      module Poly = struct
        [%%versioned
        module Stable = struct
          module V1 = struct
            type ( 'length
                 , 'vrf_output
                 , 'amount
                 , 'global_slot
                 , 'global_slot_since_genesis
                 , 'staking_epoch_data
                 , 'next_epoch_data
                 , 'bool
                 , 'pk )
                 t =
                  ( 'length
                  , 'vrf_output
                  , 'amount
                  , 'global_slot
                  , 'global_slot_since_genesis
                  , 'staking_epoch_data
                  , 'next_epoch_data
                  , 'bool
                  , 'pk )
                  A.Data.Consensus_state.Poly.V1.t =
              { blockchain_length : 'length
              ; epoch_count : 'length
              ; min_window_density : 'length
              ; sub_window_densities : 'length list
              ; last_vrf_output : 'vrf_output
              ; total_currency : 'amount
              ; curr_global_slot_since_hard_fork : 'global_slot
              ; global_slot_since_genesis : 'global_slot_since_genesis
              ; staking_epoch_data : 'staking_epoch_data
              ; next_epoch_data : 'next_epoch_data
              ; has_ancestor_in_same_checkpoint_window : 'bool
              ; block_stake_winner : 'pk
              ; block_creator : 'pk
              ; coinbase_receiver : 'pk
              ; supercharge_coinbase : 'bool
              }
            [@@deriving sexp, equal, compare, hash, yojson, fields, hlist]
          end
        end]
      end

      module Value = struct
        [%%versioned
        module Stable = struct
          module V2 = struct
            type t =
              ( Length.Stable.V1.t
              , Vrf.Output.Truncated.Stable.V1.t
              , Amount.Stable.V1.t
              , Global_slot.Stable.V1.t
              , Mina_numbers.Global_slot_since_genesis.Stable.V1.t
              , Epoch_data.Staking_value_versioned.Value.Stable.V1.t
              , Epoch_data.Next_value_versioned.Value.Stable.V1.t
              , bool
              , Public_key.Compressed.Stable.V1.t )
              Poly.Stable.V1.t
            [@@deriving sexp, equal, compare, hash, yojson]

            let to_latest = Fn.id
          end
        end]

        module For_tests = struct
          let with_global_slot_since_genesis (state : t) slot_number =
            let global_slot_since_genesis :
                Mina_numbers.Global_slot_since_genesis.t =
              slot_number
            in
            { state with global_slot_since_genesis }
        end
      end

      open Snark_params.Tick

      type var =
        ( Length.Checked.t
        , Vrf.Output.Truncated.var
        , Amount.var
        , Global_slot.Checked.t
        , Mina_numbers.Global_slot_since_genesis.Checked.t
        , Epoch_data.var
        , Epoch_data.var
        , Boolean.var
        , Public_key.Compressed.var )
        Poly.t

      let typ ~(constraint_constants : Genesis_constants.Constraint_constants.t)
          : (var, Value.t) Typ.t =
        let sub_windows_per_window =
          constraint_constants.sub_windows_per_window
        in
        Snark_params.Tick.Typ.of_hlistable
          [ Length.typ
          ; Length.typ
          ; Length.typ
          ; Typ.list ~length:sub_windows_per_window Length.typ
          ; Vrf.Output.Truncated.typ
          ; Amount.typ
          ; Global_slot.typ
          ; Mina_numbers.Global_slot_since_genesis.typ
          ; Epoch_data.Staking.typ
          ; Epoch_data.Next.typ
          ; Boolean.typ
          ; Public_key.Compressed.typ
          ; Public_key.Compressed.typ
          ; Public_key.Compressed.typ
          ; Boolean.typ
          ]
          ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
          ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

      let to_input
          ({ Poly.blockchain_length
           ; epoch_count
           ; min_window_density
           ; sub_window_densities
           ; last_vrf_output
           ; total_currency
           ; curr_global_slot_since_hard_fork
           ; global_slot_since_genesis
           ; staking_epoch_data
           ; next_epoch_data
           ; has_ancestor_in_same_checkpoint_window
           ; block_stake_winner
           ; block_creator
           ; coinbase_receiver
           ; supercharge_coinbase
           } :
            Value.t ) =
        let open Random_oracle.Input.Chunked in
        List.reduce_exn ~f:append
          [ Length.to_input blockchain_length
          ; Length.to_input epoch_count
          ; Length.to_input min_window_density
          ; List.reduce_exn ~f:append
              (List.map ~f:Length.to_input sub_window_densities)
          ; Vrf.Output.Truncated.to_input last_vrf_output
          ; Amount.to_input total_currency
          ; Global_slot.to_input curr_global_slot_since_hard_fork
          ; Mina_numbers.Global_slot_since_genesis.to_input
              global_slot_since_genesis
          ; packed
              ( Mina_base.Util.field_of_bool
                  has_ancestor_in_same_checkpoint_window
              , 1 )
          ; packed (Mina_base.Util.field_of_bool supercharge_coinbase, 1)
          ; Epoch_data.Staking.to_input staking_epoch_data
          ; Epoch_data.Next.to_input next_epoch_data
          ; Public_key.Compressed.to_input block_stake_winner
          ; Public_key.Compressed.to_input block_creator
          ; Public_key.Compressed.to_input coinbase_receiver
          ]

      let var_to_input
          ({ Poly.blockchain_length
           ; epoch_count
           ; min_window_density
           ; sub_window_densities
           ; last_vrf_output
           ; total_currency
           ; curr_global_slot_since_hard_fork
           ; global_slot_since_genesis
           ; staking_epoch_data
           ; next_epoch_data
           ; has_ancestor_in_same_checkpoint_window
           ; block_stake_winner
           ; block_creator
           ; coinbase_receiver
           ; supercharge_coinbase
           } :
            var ) =
        let open Random_oracle.Input.Chunked in
        List.reduce_exn ~f:append
          [ Length.Checked.to_input blockchain_length
          ; Length.Checked.to_input epoch_count
          ; Length.Checked.to_input min_window_density
          ; List.reduce_exn ~f:append
              (List.map ~f:Length.Checked.to_input sub_window_densities)
          ; Vrf.Output.Truncated.var_to_input last_vrf_output
          ; Amount.var_to_input total_currency
          ; Global_slot.Checked.to_input curr_global_slot_since_hard_fork
          ; Mina_numbers.Global_slot_since_genesis.Checked.to_input
              global_slot_since_genesis
          ; packed
              ((has_ancestor_in_same_checkpoint_window :> Tick.Field.Var.t), 1)
          ; packed ((supercharge_coinbase :> Tick.Field.Var.t), 1)
          ; Epoch_data.Staking.var_to_input staking_epoch_data
          ; Epoch_data.Next.var_to_input next_epoch_data
          ; Public_key.Compressed.Checked.to_input block_stake_winner
          ; Public_key.Compressed.Checked.to_input block_creator
          ; Public_key.Compressed.Checked.to_input coinbase_receiver
          ]

      let global_slot { Poly.curr_global_slot_since_hard_fork; _ } =
        curr_global_slot_since_hard_fork

      let checkpoint_window ~(constants : Constants.t) (slot : Global_slot.t) =
        UInt32.Infix.(
          ( Mina_numbers.Global_slot_since_hard_fork.to_uint32
          @@ Global_slot.slot_number slot )
          / constants.checkpoint_window_size_in_slots)

      let same_checkpoint_window_unchecked ~constants slot1 slot2 =
        UInt32.equal
          (checkpoint_window slot1 ~constants)
          (checkpoint_window slot2 ~constants)

      let update ~(constants : Constants.t)
          ~(previous_consensus_state : Value.t)
          ~(consensus_transition : Consensus_transition.t)
          ~(previous_protocol_state_hash : Mina_base.State_hash.t)
          ~(supply_increase : Currency.Amount.Signed.t)
          ~(snarked_ledger_hash : Mina_base.Frozen_ledger_hash.t)
          ~(genesis_ledger_hash : Mina_base.Frozen_ledger_hash.t)
          ~(producer_vrf_result : Random_oracle.Digest.t)
          ~(block_stake_winner : Public_key.Compressed.t)
          ~(block_creator : Public_key.Compressed.t)
          ~(coinbase_receiver : Public_key.Compressed.t)
          ~(supercharge_coinbase : bool) : Value.t Or_error.t =
        let open Or_error.Let_syntax in
        let prev_epoch, prev_slot =
          Global_slot.to_epoch_and_slot
            previous_consensus_state.curr_global_slot_since_hard_fork
        in
        let next_global_slot =
          Global_slot.of_slot_number consensus_transition ~constants
        in
        let next_epoch, next_slot =
          Global_slot.to_epoch_and_slot next_global_slot
        in
        let%bind slot_diff =
          Global_slot.diff_slots next_global_slot
            previous_consensus_state.curr_global_slot_since_hard_fork
          |> Option.value_map
               ~default:
                 (Or_error.errorf
                    !"Next global slot %{sexp: Global_slot.t} smaller than \
                      current global slot %{sexp: Global_slot.t}"
                    next_global_slot
                    previous_consensus_state.curr_global_slot_since_hard_fork )
               ~f:(fun diff -> Ok diff)
        in
        let%map total_currency =
          let total, `Overflow overflow =
            Amount.add_signed_flagged previous_consensus_state.total_currency
              supply_increase
          in
          if overflow then
            Or_error.errorf
              !"New total currency less than zero. supply_increase: %{sexp: \
                Amount.Signed.t} previous total currency: %{sexp: Amount.t}"
              supply_increase previous_consensus_state.total_currency
          else Ok total
        and () =
          if
            Consensus_transition.(
              equal consensus_transition Consensus_transition.genesis)
            || Global_slot.(
                 previous_consensus_state.curr_global_slot_since_hard_fork
                 < next_global_slot)
          then Ok ()
          else
            Or_error.errorf
              !"(epoch, slot) did not increase. prev=%{sexp:Epoch.t * Slot.t}, \
                next=%{sexp:Epoch.t * Slot.t}"
              (prev_epoch, prev_slot) (next_epoch, next_slot)
        in
        let staking_epoch_data, next_epoch_data, epoch_count =
          Epoch_data.update_pair ~constants
            ( previous_consensus_state.staking_epoch_data
            , previous_consensus_state.next_epoch_data )
            previous_consensus_state.epoch_count ~prev_epoch ~next_epoch
            ~next_slot ~prev_protocol_state_hash:previous_protocol_state_hash
            ~producer_vrf_result ~snarked_ledger_hash ~genesis_ledger_hash
            ~total_currency
        in
        let min_window_density, sub_window_densities =
          Min_window_density.update_min_window_density ~constants
            ~incr_window:true
            ~prev_global_slot:
              previous_consensus_state.curr_global_slot_since_hard_fork
            ~next_global_slot
            ~prev_sub_window_densities:
              previous_consensus_state.sub_window_densities
            ~prev_min_window_density:previous_consensus_state.min_window_density
        in
        { Poly.blockchain_length =
            Length.succ previous_consensus_state.blockchain_length
        ; epoch_count
        ; min_window_density
        ; sub_window_densities
        ; last_vrf_output = Vrf.Output.truncate producer_vrf_result
        ; total_currency
        ; curr_global_slot_since_hard_fork = next_global_slot
        ; global_slot_since_genesis =
            Mina_numbers.Global_slot_since_genesis.add
              previous_consensus_state.global_slot_since_genesis slot_diff
        ; staking_epoch_data
        ; next_epoch_data
        ; has_ancestor_in_same_checkpoint_window =
            same_checkpoint_window_unchecked ~constants
              (Global_slot.create ~constants ~epoch:prev_epoch ~slot:prev_slot)
              (Global_slot.create ~constants ~epoch:next_epoch ~slot:next_slot)
        ; block_stake_winner
        ; block_creator
        ; coinbase_receiver
        ; supercharge_coinbase
        }

      let same_checkpoint_window ~(constants : Constants.var)
          ~prev:(slot1 : Global_slot.Checked.t)
          ~next:(slot2 : Global_slot.Checked.t) =
        let module Slot = Mina_numbers.Global_slot_since_hard_fork in
        let slot1 : Slot.Checked.t = Global_slot.slot_number slot1 in
        let checkpoint_window_size_in_slots =
          constants.checkpoint_window_size_in_slots
        in
        let%bind _q1, r1 =
          Slot.Checked.div_mod slot1
            (Slot.Checked.Unsafe.of_field
               (Length.Checked.to_field checkpoint_window_size_in_slots) )
        in
        let next_window_start =
          Run.Field.(
            Slot.Checked.to_field slot1
            - Slot.Checked.to_field r1
            + Length.Checked.to_field checkpoint_window_size_in_slots)
        in
        Slot.Checked.( < )
          (Global_slot.slot_number slot2)
          (Slot.Checked.Unsafe.of_field next_window_start)

      let same_checkpoint_window ~constants ~prev ~next =
        same_checkpoint_window ~constants ~prev ~next

      let negative_one ~genesis_ledger
          ~(genesis_epoch_data : Genesis_epoch_data.t)
          ~(constants : Constants.t)
          ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
        let max_sub_window_density = constants.slots_per_sub_window in
        let max_window_density = constants.slots_per_window in
        let blockchain_length, global_slot_since_genesis =
          match constraint_constants.fork with
          | None ->
              (Length.zero, Mina_numbers.Global_slot_since_genesis.zero)
          | Some { blockchain_length; global_slot_since_genesis; _ } ->
              (*Note: global_slot_since_genesis at fork point is the same as global_slot_since_genesis in the new genesis. This value is used to check transaction validity and existence of locked tokens.
                For reviewers, should this be incremented by 1 because it's technically a new block? we don't really know how many slots passed since the fork point*)
              (blockchain_length, global_slot_since_genesis)
        in
        let default_epoch_data =
          Genesis_epoch_data.Data.
            { ledger = genesis_ledger; seed = Epoch_seed.initial }
        in
        let genesis_epoch_data_staking, genesis_epoch_data_next =
          Option.value_map genesis_epoch_data
            ~default:(default_epoch_data, default_epoch_data) ~f:(fun data ->
              (data.staking, Option.value ~default:data.staking data.next) )
        in
        let genesis_winner_pk = fst Vrf.Precomputed.genesis_winner in
        { Poly.blockchain_length
        ; epoch_count = Length.zero
        ; min_window_density = max_window_density
        ; sub_window_densities =
            Length.zero
            :: List.init
                 (Length.to_int constants.sub_windows_per_window - 1)
                 ~f:(Fn.const max_sub_window_density)
        ; last_vrf_output = Vrf.Output.Truncated.dummy
        ; total_currency = genesis_ledger_total_currency ~ledger:genesis_ledger
        ; curr_global_slot_since_hard_fork = Global_slot.zero ~constants
        ; global_slot_since_genesis
        ; staking_epoch_data =
            Epoch_data.Staking.genesis
              ~genesis_epoch_data:genesis_epoch_data_staking
        ; next_epoch_data =
            Epoch_data.Next.genesis ~genesis_epoch_data:genesis_epoch_data_next
        ; has_ancestor_in_same_checkpoint_window = false
        ; block_stake_winner = genesis_winner_pk
        ; block_creator = genesis_winner_pk
        ; coinbase_receiver = genesis_winner_pk
        ; supercharge_coinbase = true
        }

      let create_genesis_from_transition ~negative_one_protocol_state_hash
          ~consensus_transition ~genesis_ledger
          ~(genesis_epoch_data : Genesis_epoch_data.t) ~constraint_constants
          ~constants : Value.t =
        let staking_seed =
          Option.value_map genesis_epoch_data ~default:Epoch_seed.initial
            ~f:(fun data -> data.staking.seed)
        in
        let producer_vrf_result =
          let _, sk = Vrf.Precomputed.genesis_winner in
          Vrf.eval ~constraint_constants ~private_key:sk
            { Vrf.Message.global_slot = consensus_transition
            ; seed = staking_seed
            ; delegator = 0
            }
        in
        let snarked_ledger_hash =
          Lazy.force genesis_ledger |> Mina_ledger.Ledger.merkle_root
          |> Mina_base.Frozen_ledger_hash.of_ledger_hash
        in
        let genesis_winner_pk = fst Vrf.Precomputed.genesis_winner in
        (* no coinbases for genesis block, so CLI flag for coinbase receiver
           not relevant
        *)
        Or_error.ok_exn
          (update ~constants ~producer_vrf_result
             ~previous_consensus_state:
               (negative_one ~genesis_ledger ~genesis_epoch_data ~constants
                  ~constraint_constants )
             ~previous_protocol_state_hash:negative_one_protocol_state_hash
             ~consensus_transition ~supply_increase:Currency.Amount.Signed.zero
             ~snarked_ledger_hash ~genesis_ledger_hash:snarked_ledger_hash
             ~block_stake_winner:genesis_winner_pk
             ~block_creator:genesis_winner_pk
             ~coinbase_receiver:genesis_winner_pk ~supercharge_coinbase:true )

      let create_genesis ~negative_one_protocol_state_hash ~genesis_ledger
          ~genesis_epoch_data ~constraint_constants ~constants : Value.t =
        create_genesis_from_transition ~negative_one_protocol_state_hash
          ~consensus_transition:Consensus_transition.genesis ~genesis_ledger
          ~genesis_epoch_data ~constraint_constants ~constants

      (* ??? do these mean, genesis-of-all-time, or genesis-at-hard-fork? *)
      (* Check that both epoch and slot are zero. *)
      let is_genesis_state (t : Value.t) =
        Mina_numbers.Global_slot_since_hard_fork.(
          equal zero
            (Global_slot.slot_number t.curr_global_slot_since_hard_fork))

      let is_genesis (global_slot : Global_slot.Checked.t) =
        let open Mina_numbers.Global_slot_since_hard_fork in
        Checked.equal (Checked.constant zero)
          (Global_slot.slot_number global_slot)

      let is_genesis_state_var (t : var) =
        is_genesis t.curr_global_slot_since_hard_fork

      let epoch_count (t : Value.t) = t.epoch_count

      let supercharge_coinbase_var (t : var) = t.supercharge_coinbase

      let supercharge_coinbase (t : Value.t) = t.supercharge_coinbase

      let compute_supercharge_coinbase ~(winner_account : Mina_base.Account.var)
          ~global_slot =
        let open Snark_params.Tick in
        let%map winner_locked =
          Mina_base.Account.Checked.has_locked_tokens ~global_slot
            winner_account
        in
        Boolean.not winner_locked

      let%snarkydef_ update_var (previous_state : var)
          (transition_data : Consensus_transition.var)
          (previous_protocol_state_hash : Mina_base.State_hash.var)
          ~(supply_increase : Currency.Amount.Signed.var)
          ~(previous_blockchain_state_ledger_hash :
             Mina_base.Frozen_ledger_hash.var ) ~genesis_ledger_hash
          ~constraint_constants
          ~(protocol_constants : Mina_base.Protocol_constants_checked.var) =
        let open Snark_params.Tick in
        let%bind constants =
          Constants.Checked.create ~constraint_constants ~protocol_constants
        in
        let { Poly.curr_global_slot_since_hard_fork = prev_global_slot; _ } =
          previous_state
        in
        let next_global_slot =
          Global_slot.Checked.of_slot_number ~constants transition_data
        in
        let%bind slot_diff =
          [%with_label_ "Next global slot is larger than previous global slot"]
            (fun () ->
              Global_slot.Checked.diff_slots next_global_slot prev_global_slot )
        in
        let%bind () =
          let%bind global_slot_increased =
            Global_slot.Checked.(prev_global_slot < next_global_slot)
          in
          let%bind is_genesis = is_genesis next_global_slot in
          Boolean.Assert.any [ global_slot_increased; is_genesis ]
        in
        let%bind next_epoch, next_slot =
          Global_slot.Checked.to_epoch_and_slot next_global_slot
        and prev_epoch, _prev_slot =
          Global_slot.Checked.to_epoch_and_slot prev_global_slot
        in
        let%bind global_slot_since_genesis =
          Mina_numbers.Global_slot_since_genesis.Checked.add
            previous_state.global_slot_since_genesis slot_diff
        in
        let%bind epoch_increased = Epoch.Checked.(prev_epoch < next_epoch) in
        let%bind staking_epoch_data =
          Epoch_data.if_ epoch_increased ~then_:previous_state.next_epoch_data
            ~else_:previous_state.staking_epoch_data
        in
        let next_slot_number = Global_slot.slot_number next_global_slot in
        let%bind block_stake_winner =
          exists Public_key.Compressed.typ
            ~request:As_prover.(return Vrf.Winner_pk)
        in
        let%bind block_creator =
          let%bind.Checked bc_compressed =
            exists Public_key.typ
              ~request:As_prover.(return Vrf.Producer_public_key)
          in
          Public_key.compress_var bc_compressed
        in
        let%bind coinbase_receiver =
          exists Public_key.Compressed.typ
            ~request:As_prover.(return Vrf.Coinbase_receiver_pk)
        in
        let%bind ( threshold_satisfied
                 , vrf_result
                 , truncated_vrf_result
                 , winner_account ) =
          let%bind (module M) = Inner_curve.Checked.Shifted.create () in
          Vrf.Checked.check ~constraint_constants
            (module M)
            ~epoch_ledger:staking_epoch_data.ledger
            ~global_slot:next_slot_number ~block_stake_winner ~block_creator
            ~seed:staking_epoch_data.seed
        in
        let%bind supercharge_coinbase =
          compute_supercharge_coinbase ~winner_account
            ~global_slot:global_slot_since_genesis
        in
        let%bind new_total_currency, `Overflow overflow =
          Currency.Amount.Checked.add_signed_flagged
            previous_state.total_currency supply_increase
        in
        let%bind () =
          [%with_label_ "Total currency is greater than or equal to zero"]
            (fun () -> Boolean.Assert.is_true (Boolean.not overflow))
        in
        let%bind has_ancestor_in_same_checkpoint_window =
          same_checkpoint_window ~constants ~prev:prev_global_slot
            ~next:next_global_slot
        in
        let%bind in_seed_update_range =
          Slot.Checked.in_seed_update_range next_slot ~constants
        in
        let%bind update_next_epoch_ledger =
          (*If snarked ledger hash is still the genesis ledger hash then the epoch ledger should continue to be `next_data.ledger`. This is because the epoch ledgers at genesis can be different from the genesis ledger*)
          let%bind snarked_ledger_is_still_genesis =
            Mina_base.Frozen_ledger_hash.equal_var genesis_ledger_hash
              previous_blockchain_state_ledger_hash
          in
          Boolean.(epoch_increased &&& not snarked_ledger_is_still_genesis)
        in
        let%bind next_epoch_data =
          let%map seed =
            let base = previous_state.next_epoch_data.seed in
            let%bind updated = Epoch_seed.update_var base vrf_result in
            Epoch_seed.if_ in_seed_update_range ~then_:updated ~else_:base
          and epoch_length =
            let open Length.Checked in
            let%bind base =
              if_ epoch_increased ~then_:zero
                ~else_:previous_state.next_epoch_data.epoch_length
            in
            succ base
          and ledger =
            Epoch_ledger.if_ update_next_epoch_ledger
              ~then_:
                { total_currency = new_total_currency
                ; hash = previous_blockchain_state_ledger_hash
                }
              ~else_:previous_state.next_epoch_data.ledger
          and start_checkpoint =
            Mina_base.State_hash.if_ epoch_increased
              ~then_:previous_protocol_state_hash
              ~else_:previous_state.next_epoch_data.start_checkpoint
          (* Want this to be the protocol state hash once we leave the seed
             update range. *)
          and lock_checkpoint =
            let%bind base =
              (* TODO: Should this be zero or some other sentinel value? *)
              Mina_base.State_hash.if_ epoch_increased
                ~then_:Mina_base.State_hash.(var_of_t (of_hash zero))
                ~else_:previous_state.next_epoch_data.lock_checkpoint
            in
            Mina_base.State_hash.if_ in_seed_update_range
              ~then_:previous_protocol_state_hash ~else_:base
          in
          { Epoch_data.Poly.seed
          ; epoch_length
          ; ledger
          ; start_checkpoint
          ; lock_checkpoint
          }
        and blockchain_length =
          Length.Checked.succ previous_state.blockchain_length
        and epoch_count =
          Length.Checked.succ_if previous_state.epoch_count epoch_increased
        and min_window_density, sub_window_densities =
          Min_window_density.Checked.update_min_window_density ~constants
            ~prev_global_slot ~next_global_slot
            ~prev_sub_window_densities:previous_state.sub_window_densities
            ~prev_min_window_density:previous_state.min_window_density
        in
        Checked.return
          ( `Success threshold_satisfied
          , { Poly.blockchain_length
            ; epoch_count
            ; min_window_density
            ; sub_window_densities
            ; last_vrf_output = truncated_vrf_result
            ; curr_global_slot_since_hard_fork = next_global_slot
            ; global_slot_since_genesis
            ; total_currency = new_total_currency
            ; staking_epoch_data
            ; next_epoch_data
            ; has_ancestor_in_same_checkpoint_window
            ; block_stake_winner
            ; block_creator
            ; coinbase_receiver
            ; supercharge_coinbase
            } )

      type display =
        { blockchain_length : int
        ; epoch_count : int
        ; curr_epoch : int
        ; curr_slot : int
        ; global_slot_since_genesis : int
        ; total_currency : int
        }
      [@@deriving yojson]

      let display (t : Value.t) =
        let epoch, slot =
          Global_slot.to_epoch_and_slot t.curr_global_slot_since_hard_fork
        in
        { blockchain_length = Length.to_int t.blockchain_length
        ; epoch_count = Length.to_int t.epoch_count
        ; curr_epoch = Segment_id.to_int epoch
        ; curr_slot = Segment_id.to_int slot
        ; global_slot_since_genesis =
            Mina_numbers.Global_slot_since_genesis.to_int
              t.global_slot_since_genesis
        ; total_currency = Amount.to_nanomina_int t.total_currency
        }

      let curr_global_slot (t : Value.t) = t.curr_global_slot_since_hard_fork

      let curr_ f = Fn.compose f curr_global_slot

      let curr_epoch_and_slot = curr_ Global_slot.to_epoch_and_slot

      let curr_epoch = curr_ Global_slot.epoch

      let curr_slot = curr_ Global_slot.slot

      let blockchain_length_var (t : var) = t.blockchain_length

      let min_window_density_var (t : var) = t.min_window_density

      let total_currency_var (t : var) = t.total_currency

      let staking_epoch_data_var (t : var) : Epoch_data.var =
        t.staking_epoch_data

      let staking_epoch_data (t : Value.t) = t.staking_epoch_data

      let next_epoch_data_var (t : var) : Epoch_data.var = t.next_epoch_data

      let next_epoch_data (t : Value.t) = t.next_epoch_data

      let coinbase_receiver_var (t : var) = t.coinbase_receiver

      let curr_global_slot_var (t : var) =
        Global_slot.slot_number t.curr_global_slot_since_hard_fork

      let curr_global_slot (t : Value.t) =
        Global_slot.slot_number t.curr_global_slot_since_hard_fork

      let consensus_time (t : Value.t) = t.curr_global_slot_since_hard_fork

      let global_slot_since_genesis_var (t : var) = t.global_slot_since_genesis

      [%%define_locally
      Poly.
        ( blockchain_length
        , min_window_density
        , sub_window_densities
        , total_currency
        , global_slot_since_genesis
        , block_stake_winner
        , last_vrf_output
        , block_creator
        , coinbase_receiver
        , has_ancestor_in_same_checkpoint_window )]

      module Unsafe = struct
        (* TODO: very unsafe, do not use unless you know what you are doing *)
        let dummy_advance (t : Value.t) ?(increase_epoch_count = false)
            ~new_global_slot_since_genesis : Value.t =
          let new_epoch_count =
            if increase_epoch_count then Length.succ t.epoch_count
            else t.epoch_count
          in
          let slot_diff =
            Option.value_exn
              (Mina_numbers.Global_slot_since_genesis.diff
                 new_global_slot_since_genesis t.global_slot_since_genesis )
          in
          { t with
            epoch_count = new_epoch_count
          ; curr_global_slot_since_hard_fork =
              Global_slot.add t.curr_global_slot_since_hard_fork slot_diff
          ; global_slot_since_genesis = new_global_slot_since_genesis
          }
      end
    end

    module Prover_state = struct
      include Stake_proof

      let genesis_data = Vrf.Precomputed.genesis_stake_proof

      let precomputed_handler = Vrf.Precomputed.handler

      let handler
          { delegator
          ; delegator_pk
          ; coinbase_receiver_pk
          ; ledger
          ; producer_private_key
          ; producer_public_key
          } ~(constraint_constants : Genesis_constants.Constraint_constants.t)
          ~pending_coinbase:
            { Mina_base.Pending_coinbase_witness.pending_coinbases
            ; is_new_stack
            } : Snark_params.Tick.Handler.t =
        let ledger_handler =
          unstage (Mina_ledger.Sparse_ledger.handler ledger)
        in
        let pending_coinbase_handler =
          unstage
            (Mina_base.Pending_coinbase.handler
               ~depth:constraint_constants.pending_coinbase_depth
               pending_coinbases ~is_new_stack )
        in
        let handlers =
          Snarky_backendless.Request.Handler.(
            push
              (push fail (create_single pending_coinbase_handler))
              (create_single ledger_handler))
        in
        fun (With { request; respond }) ->
          match request with
          | Vrf.Winner_address ->
              respond (Provide delegator)
          | Vrf.Winner_pk ->
              respond (Provide delegator_pk)
          | Vrf.Coinbase_receiver_pk ->
              respond (Provide coinbase_receiver_pk)
          | Vrf.Producer_private_key ->
              respond (Provide producer_private_key)
          | Vrf.Producer_public_key ->
              respond (Provide producer_public_key)
          | _ ->
              respond
                (Provide
                   (Option.value_exn ~message:"unhandled request"
                      (Snarky_backendless.Request.Handler.run handlers request) )
                )

      let ledger_depth { ledger; _ } = ledger.depth
    end
  end

  module Coinbase_receiver = struct
    type t = [ `Producer | `Other of Public_key.Compressed.t ]
    [@@deriving yojson]

    let resolve ~self : t -> Public_key.Compressed.t = function
      | `Producer ->
          self
      | `Other pk ->
          pk
  end

  module Hooks = struct
    open Data

    let is_genesis_epoch ~(constants : Constants.t) time =
      Epoch.(equal (of_time_exn ~constants time) zero)

    (* Select the correct epoch data to use from a consensus state for a given epoch.
     * The rule for selecting the correct epoch data changes based on whether or not
     * the consensus state we are selecting from is in the epoch we want to select.
     * There is also a special case for when the consensus state we are selecting
     * from is in the genesis epoch.
     *)
    let select_epoch_data ~(consensus_state : Consensus_state.Value.t) ~epoch =
      let curr_epoch = Consensus_state.curr_epoch consensus_state in
      (* are we in the same epoch as the consensus state? *)
      let in_same_epoch = Epoch.equal epoch curr_epoch in
      (* are we in the next epoch after the consensus state? *)
      let in_next_epoch = Epoch.equal epoch (Epoch.succ curr_epoch) in
      (* is the consensus state from the genesis epoch? *)
      let from_genesis_epoch =
        Length.equal consensus_state.epoch_count Length.zero
      in
      let in_initial_epoch = Epoch.(equal zero) epoch in
      if in_next_epoch then
        Ok (Epoch_data.next_to_staking consensus_state.next_epoch_data)
      else if in_same_epoch || (from_genesis_epoch && in_initial_epoch) then
        Ok consensus_state.staking_epoch_data
      else Error ()

    let epoch_snapshot_name = function
      | `Genesis ->
          "genesis"
      | `Curr ->
          "curr"
      | `Last ->
          "last"

    (* Select the correct epoch snapshot to use from local state for an epoch.
     * The rule for selecting the correct epoch snapshot is predicated off of
     * whether or not the first transition in the epoch in question has been
     * finalized yet, as the local state epoch snapshot pointers are not
     * updated until the consensus state reaches the root of the transition
     * frontier.This does not apply to the genesis epoch where we should always
     * take the staking epoch snapshot because epoch ledger transition will not
     * happen for genesis epoch.
     * This function does not guarantee that the selected epoch snapshot is valid
     * (i.e. it does not check that the epoch snapshot's ledger hash is the same
     * as the ledger hash specified by the epoch data).
     *)
    let select_epoch_snapshot ~(constants : Constants.t)
        ~(consensus_state : Consensus_state.Value.t) ~local_state ~epoch =
      let open Local_state in
      let open Epoch_data.Poly in
      (* are we in the next epoch after the consensus state? *)
      let in_next_epoch =
        Epoch.equal epoch
          (Epoch.succ (Consensus_state.curr_epoch consensus_state))
      in
      (* has the first transition in the epoch (other than the genesis epoch) reached finalization? *)
      let epoch_is_not_finalized =
        let is_genesis_epoch = Length.equal epoch Length.zero in
        let epoch_is_finalized =
          Length.(consensus_state.next_epoch_data.epoch_length > constants.k)
        in
        (not epoch_is_finalized) && not is_genesis_epoch
      in
      if in_next_epoch || epoch_is_not_finalized then
        (`Curr, !local_state.Data.next_epoch_snapshot)
      else (`Last, !local_state.staking_epoch_snapshot)

    let get_epoch_ledger ~constants ~(consensus_state : Consensus_state.Value.t)
        ~local_state =
      let _, snapshot =
        select_epoch_snapshot ~constants ~consensus_state
          ~epoch:(Data.Consensus_state.curr_epoch consensus_state)
          ~local_state
      in
      Data.Local_state.Snapshot.ledger snapshot

    let get_epoch_ledgers_for_finalized_frontier_block
        ~(root_consensus_state : Consensus_state.Value.t)
        ~(target_consensus_state : Consensus_state.Value.t) ~local_state =
      let root_epoch = Data.Consensus_state.curr_epoch root_consensus_state in
      let target_epoch =
        Data.Consensus_state.curr_epoch target_consensus_state
      in
      if Epoch.equal root_epoch target_epoch then
        (* If we assume that the target state is finalized, then so is the
           frontier's root state that it builds upon.
           Hence, the next epoch snapshot is also finalized, and we can return
           both ledgers.
        *)
        `Both
          ( Data.Local_state.Snapshot.ledger
              !local_state.Local_state.Data.staking_epoch_snapshot
          , Data.Local_state.Snapshot.ledger
              !local_state.Local_state.Data.next_epoch_snapshot )
      else
        (* Next epoch: the caller will need to manually compute the snarked
           ledger for the parent block at the epoch boundary.
        *)
        let num_parents =
          Length.to_int target_consensus_state.next_epoch_data.epoch_length
        in
        `Snarked_ledger
          ( Data.Local_state.Snapshot.ledger !local_state.next_epoch_snapshot
          , num_parents )

    type required_snapshot =
      { snapshot_id : Local_state.snapshot_identifier
      ; expected_root : Mina_base.Frozen_ledger_hash.t
      }
    [@@deriving to_yojson]

    type local_state_sync =
      | One of required_snapshot
      | Both of
          { next : Mina_base.Frozen_ledger_hash.t
          ; staking : Mina_base.Frozen_ledger_hash.t
          }
    [@@deriving to_yojson]

    let local_state_sync_count (s : local_state_sync) =
      match s with One _ -> 1 | Both _ -> 2

    let required_local_state_sync ~constants
        ~(consensus_state : Consensus_state.Value.t) ~local_state =
      let open Mina_base in
      let epoch = Consensus_state.curr_epoch consensus_state in
      let source, _snapshot =
        select_epoch_snapshot ~constants ~consensus_state ~local_state ~epoch
      in
      let required_snapshot_sync snapshot_id expected_root =
        Option.some_if
          (not
             (Ledger_hash.equal
                (Frozen_ledger_hash.to_ledger_hash expected_root)
                (Local_state.Snapshot.Ledger_snapshot.merkle_root
                   (Local_state.get_snapshot local_state snapshot_id).ledger ) ) )
          { snapshot_id; expected_root }
      in
      match source with
      | `Curr ->
          Option.map
            (required_snapshot_sync Next_epoch_snapshot
               consensus_state.staking_epoch_data.ledger.hash ) ~f:(fun s ->
              One s )
      | `Last -> (
          match
            ( required_snapshot_sync Next_epoch_snapshot
                consensus_state.next_epoch_data.ledger.hash
            , required_snapshot_sync Staking_epoch_snapshot
                consensus_state.staking_epoch_data.ledger.hash )
          with
          | None, None ->
              None
          | Some x, None | None, Some x ->
              Some (One x)
          | Some next, Some staking ->
              Some
                (Both
                   { next = next.expected_root
                   ; staking = staking.expected_root
                   } ) )

    let sync_local_state ~context:(module Context : CONTEXT_WITH_LEDGER_SYNC)
        ~trust_system ~local_state ~glue_sync_ledger requested_syncs =
      let open Context in
      let open Local_state in
      let open Snapshot in
      let open Deferred.Let_syntax in
      O1trace.thread "sync_local_state" (fun () ->
          [%log info]
            "Syncing local state; requesting $num_requested snapshots from \
             peers"
            ~metadata:
              [ ("num_requested", `Int (local_state_sync_count requested_syncs))
              ; ("requested_syncs", local_state_sync_to_yojson requested_syncs)
              ; ("local_state", Local_state.to_yojson local_state)
              ] ;
          let sync { snapshot_id; expected_root = target_ledger_hash } =
            (* if requested last epoch ledger is equal to the current epoch ledger
               then we don't need to sync the ledger to the peers. *)
            if
              equal_snapshot_identifier snapshot_id Staking_epoch_snapshot
              && Mina_base.(
                   Ledger_hash.equal
                     (Frozen_ledger_hash.to_ledger_hash target_ledger_hash)
                     (Local_state.Snapshot.Ledger_snapshot.merkle_root
                        !local_state.next_epoch_snapshot.ledger ))
            then (
              Local_state.Snapshot.Ledger_snapshot.remove
                !local_state.staking_epoch_snapshot.ledger
                ~location:(staking_epoch_ledger_location local_state) ;
              match !local_state.next_epoch_snapshot.ledger with
              | Local_state.Snapshot.Ledger_snapshot.Genesis_epoch_ledger _ ->
                  set_snapshot local_state Staking_epoch_snapshot
                    !local_state.next_epoch_snapshot ;
                  Deferred.Or_error.ok_unit
              | Ledger_db next_epoch_ledger ->
                  let ledger =
                    Mina_ledger.Ledger.Db.create_checkpoint next_epoch_ledger
                      ~directory_name:
                        (staking_epoch_ledger_location local_state)
                      ()
                  in
                  set_snapshot local_state Staking_epoch_snapshot
                    { ledger = Ledger_snapshot.Ledger_db ledger
                    ; delegatee_table =
                        !local_state.next_epoch_snapshot.delegatee_table
                    } ;
                  Deferred.Or_error.ok_unit )
            else
              let ledger_hash_json =
                Mina_base.Ledger_hash.to_yojson target_ledger_hash
              in
              [%log info] "Syncing epoch ledger with hash $target_ledger_hash"
                ~metadata:[ ("target_ledger_hash", ledger_hash_json) ] ;
              (* start with an existing epoch ledger, which may be faster
                 than syncing with an empty ledger, since ledgers accumulate
                 new leaves in increasing index order
              *)
              let%bind.Deferred.Or_error db_ledger =
                let db_ledger_of_snapshot snapshot snapshot_location =
                  O1trace.sync_thread "db_ledger_of_snapshot" (fun () ->
                      match snapshot.ledger with
                      | Ledger_snapshot.Ledger_db ledger ->
                          Ok ledger
                      | Ledger_snapshot.Genesis_epoch_ledger ledger ->
                          let module Ledger_transfer =
                            Mina_ledger.Ledger_transfer.Make
                              (Mina_ledger.Ledger)
                              (Mina_ledger.Ledger.Db)
                          in
                          let fresh_db_ledger =
                            Mina_ledger.Ledger.Db.create
                              ~directory_name:snapshot_location
                              ~depth:Context.constraint_constants.ledger_depth
                              ()
                          in
                          Ledger_transfer.transfer_accounts ~src:ledger
                            ~dest:fresh_db_ledger )
                in
                match snapshot_id with
                | Staking_epoch_snapshot ->
                    return
                    @@ db_ledger_of_snapshot !local_state.staking_epoch_snapshot
                         (staking_epoch_ledger_location local_state)
                | Next_epoch_snapshot ->
                    return
                    @@ db_ledger_of_snapshot !local_state.next_epoch_snapshot
                         (next_epoch_ledger_location local_state)
              in
              let sync_ledger =
                Mina_ledger.Sync_ledger.Db.create
                  ~context:(module Context)
                  ~trust_system db_ledger
              in
              let query_reader =
                Mina_ledger.Sync_ledger.Db.query_reader sync_ledger
              in
              let response_writer =
                Mina_ledger.Sync_ledger.Db.answer_writer sync_ledger
              in
              glue_sync_ledger ~preferred:[] query_reader response_writer ;
              match%bind
                Mina_ledger.Sync_ledger.Db.fetch sync_ledger target_ledger_hash
                  ~data:() ~equal:(fun () () -> true)
              with
              | `Ok ledger ->
                  [%log info]
                    "Succeeded in syncing epoch ledger with hash \
                     $target_ledger_hash from peers"
                    ~metadata:[ ("target_ledger_hash", ledger_hash_json) ] ;
                  assert (
                    Mina_base.Ledger_hash.equal target_ledger_hash
                      (Mina_ledger.Ledger.Db.merkle_root ledger) ) ;
                  reset_snapshot local_state snapshot_id ledger ;
                  Deferred.Or_error.ok_unit
              | `Target_changed _ ->
                  [%log error] "Target changed when syncing epoch ledger" ;
                  return (Or_error.error_string "Epoch ledger target changed")
          in
          match requested_syncs with
          | One required_sync ->
              let open Async.Deferred.Let_syntax in
              let start = Core.Time.now () in
              let%map result = sync required_sync in
              let { snapshot_id; _ } = required_sync in
              ( match snapshot_id with
              | Staking_epoch_snapshot ->
                  Mina_metrics.(
                    Counter.inc Bootstrap.staking_epoch_ledger_sync_ms
                      Core.Time.(diff (now ()) start |> Span.to_ms))
              | Next_epoch_snapshot ->
                  Mina_metrics.(
                    Counter.inc Bootstrap.next_epoch_ledger_sync_ms
                      Core.Time.(diff (now ()) start |> Span.to_ms)) ) ;
              result
          | Both { staking; next } ->
              (*Sync staking ledger before syncing the next ledger*)
              let open Deferred.Or_error.Let_syntax in
              let start = Core.Time.now () in
              let%bind () =
                sync
                  { snapshot_id = Staking_epoch_snapshot
                  ; expected_root = staking
                  }
              in
              Mina_metrics.(
                Counter.inc Bootstrap.staking_epoch_ledger_sync_ms
                  Core.Time.(diff (now ()) start |> Span.to_ms)) ;
              let start = Core.Time.now () in
              let%map () =
                sync { snapshot_id = Next_epoch_snapshot; expected_root = next }
              in
              Mina_metrics.(
                Counter.inc Bootstrap.next_epoch_ledger_sync_ms
                  Core.Time.(diff (now ()) start |> Span.to_ms)) )

    let received_within_window ~constants (epoch, slot) ~time_received =
      let open Int64 in
      let ( < ) x y = compare x y < 0 in
      let ( >= ) x y = compare x y >= 0 in
      let time_received =
        Time.(
          of_span_since_epoch
            (Span.of_ms (Mina_stdlib.Unix_timestamp.to_int64 time_received)))
      in
      let slot_diff =
        Epoch.diff_in_slots ~constants
          (Epoch_and_slot.of_time_exn time_received ~constants)
          (epoch, slot)
      in
      if slot_diff < 0L then Error `Too_early
      else if slot_diff >= UInt32.(to_int64 (add constants.delta (of_int 1)))
      then Error (`Too_late (sub slot_diff UInt32.(to_int64 constants.delta)))
      else Ok ()

    let received_at_valid_time ~(constants : Constants.t)
        (consensus_state : Consensus_state.Value.t) ~time_received =
      received_within_window ~constants
        (Consensus_state.curr_epoch_and_slot consensus_state)
        ~time_received

    let is_short_range ~constants =
      let open Consensus_state in
      let is_pred x1 x2 = Epoch.equal (Epoch.succ x1) x2 in
      let pred_case c1 c2 =
        let e1, e2 = (curr_epoch c1, curr_epoch c2) in
        let c1_next_is_finalized =
          not (Slot.in_seed_update_range ~constants (Slot.succ (curr_slot c1)))
        in
        is_pred e1 e2 && c1_next_is_finalized
        && Mina_base.State_hash.equal c1.next_epoch_data.lock_checkpoint
             c2.staking_epoch_data.lock_checkpoint
      in
      fun c1 c2 ->
        if Epoch.equal (curr_epoch c1) (curr_epoch c2) then
          Mina_base.State_hash.equal c1.staking_epoch_data.lock_checkpoint
            c2.staking_epoch_data.lock_checkpoint
        else pred_case c1 c2 || pred_case c2 c1

    type select_status = [ `Keep | `Take ] [@@deriving equal]

    let select ~context:(module Context : CONTEXT) ~existing:existing_with_hash
        ~candidate:candidate_with_hash =
      let open Context in
      let { With_hash.hash =
              { Mina_base.State_hash.State_hashes.state_hash = existing_hash
              ; _
              }
          ; data = existing
          } =
        existing_with_hash
      in
      let { With_hash.hash =
              { Mina_base.State_hash.State_hashes.state_hash = candidate_hash
              ; _
              }
          ; data = candidate
          } =
        candidate_with_hash
      in
      let string_of_choice = function `Take -> "Take" | `Keep -> "Keep" in
      let log_result choice msg =
        [%log debug] "Select result: $choice -- $message"
          ~metadata:
            [ ("choice", `String (string_of_choice choice))
            ; ("message", `String msg)
            ]
      in
      let log_choice ~precondition_msg ~choice_msg choice =
        let choice_msg =
          match choice with
          | `Take ->
              choice_msg
          | `Keep ->
              Printf.sprintf "not (%s)" choice_msg
        in
        let msg = Printf.sprintf "(%s) && (%s)" precondition_msg choice_msg in
        log_result choice msg
      in
      [%log debug] "Selecting best consensus state"
        ~metadata:
          [ ("existing", Consensus_state.Value.to_yojson existing)
          ; ("candidate", Consensus_state.Value.to_yojson candidate)
          ] ;
      (* TODO: add fork_before_checkpoint check *)
      (* Each branch contains a precondition predicate and a choice predicate,
       * which takes the new state when true. Each predicate is also decorated
       * with a string description, used for debugging messages *)
      let less_than_or_equal_when a b ~compare ~condition =
        let c = compare a b in
        c < 0 || (c = 0 && condition)
      in
      let candidate_hash_is_bigger =
        Mina_base.State_hash.(candidate_hash > existing_hash)
      in
      let candidate_vrf_is_bigger =
        let string_of_blake2 =
          Blake2.(Fn.compose to_raw_string digest_string)
        in
        let compare_blake2 a b =
          String.compare (string_of_blake2 a) (string_of_blake2 b)
        in
        less_than_or_equal_when existing.last_vrf_output
          candidate.last_vrf_output ~compare:compare_blake2
          ~condition:candidate_hash_is_bigger
      in
      let blockchain_length_is_longer =
        less_than_or_equal_when existing.blockchain_length
          candidate.blockchain_length ~compare:Length.compare
          ~condition:candidate_vrf_is_bigger
      in
      let long_fork_chain_quality_is_better =
        (* The min window density if we imagine extending to the max slot of the two chains. *)
        (* TODO: You could argue that instead this should be imagine extending to the current consensus time. *)
        let max_slot =
          Global_slot.max candidate.curr_global_slot_since_hard_fork
            existing.curr_global_slot_since_hard_fork
        in
        let virtual_min_window_density (s : Consensus_state.Value.t) =
          if Global_slot.equal s.curr_global_slot_since_hard_fork max_slot then
            s.min_window_density
          else
            Min_window_density.update_min_window_density ~incr_window:false
              ~constants:consensus_constants
              ~prev_global_slot:s.curr_global_slot_since_hard_fork
              ~next_global_slot:max_slot
              ~prev_sub_window_densities:s.sub_window_densities
              ~prev_min_window_density:s.min_window_density
            |> fst
        in
        less_than_or_equal_when
          (virtual_min_window_density existing)
          (virtual_min_window_density candidate)
          ~compare:Length.compare ~condition:blockchain_length_is_longer
      in
      let precondition_msg, choice_msg, should_take =
        if is_short_range existing candidate ~constants:consensus_constants then
          ( "most recent finalized checkpoints are equal"
          , "candidate length is longer than existing length "
          , blockchain_length_is_longer )
        else
          ( "most recent finalized checkpoints are not equal"
          , "candidate virtual min-length is longer than existing virtual \
             min-length"
          , long_fork_chain_quality_is_better )
      in
      let choice = if should_take then `Take else `Keep in
      log_choice ~precondition_msg ~choice_msg choice ;
      choice

    let epoch_end_time = Epoch.end_time

    let get_epoch_data_for_vrf ~(constants : Constants.t) now
        (state : Consensus_state.Value.t) ~local_state ~logger :
        Epoch_data_for_vrf.t * Local_state.Snapshot.Ledger_snapshot.t =
      let curr_epoch, curr_slot =
        Epoch.epoch_and_slot_of_time_exn ~constants
          (Block_time.of_span_since_epoch (Block_time.Span.of_ms now))
      in
      let epoch, slot =
        if
          Epoch.equal curr_epoch (Consensus_state.curr_epoch state)
          && Slot.equal curr_slot (Consensus_state.curr_slot state)
        then Epoch.incr ~constants (curr_epoch, curr_slot)
        else (curr_epoch, curr_slot)
      in
      let global_slot =
        Global_slot.of_epoch_and_slot ~constants (epoch, slot)
        |> Global_slot.slot_number
      in
      [%log debug]
        "Systime: %d, epoch-slot@systime: %08d-%04d, starttime@epoch@systime: \
         %d"
        (Int64.to_int now) (Epoch.to_int epoch) (Slot.to_int slot)
        ( Int64.to_int @@ Time.Span.to_ms @@ Time.to_span_since_epoch
        @@ Epoch.start_time ~constants epoch ) ;
      [%log debug]
        !"Selecting correct epoch data from state -- epoch by time: %d, state \
          epoch: %d, state epoch count: %d"
        (Epoch.to_int epoch)
        (Epoch.to_int (Consensus_state.curr_epoch state))
        (Length.to_int state.epoch_count) ;
      let epoch_data =
        match select_epoch_data ~consensus_state:state ~epoch with
        | Ok epoch_data ->
            epoch_data
        | Error () ->
            [%log fatal]
              "An empty epoch is detected! This could be caused by the \
               following reasons: system time is out of sync with protocol \
               state time; or internet connection is down or unstable If it is \
               the first case, please setup NTP. If it is the second case, \
               please check the internet connection." ;
            exit 99
      in
      let epoch_snapshot =
        let source, snapshot =
          select_epoch_snapshot ~constants ~consensus_state:state ~local_state
            ~epoch
        in
        let snapshot_ledger_hash =
          Local_state.Snapshot.Ledger_snapshot.merkle_root snapshot.ledger
        in
        [%log debug]
          ~metadata:
            [ ( "ledger_hash"
              , Mina_base.Frozen_ledger_hash.to_yojson snapshot_ledger_hash )
            ]
          !"Using %s_epoch_snapshot root hash $ledger_hash"
          (epoch_snapshot_name source) ;
        (*TODO: uncomment after #6956 is resolved*)
        (*assert (
          Mina_base.Frozen_ledger_hash.equal snapshot_ledger_hash
          epoch_data.ledger.hash ) ;*)
        snapshot
      in
      let global_slot_since_genesis =
        let slot_diff =
          match
            Mina_numbers.Global_slot_since_hard_fork.diff global_slot
              (Consensus_state.curr_global_slot state)
          with
          | None ->
              [%log fatal]
                "Checking slot-winner for slot $slot which is older than the \
                 slot in the latest consensus state $state"
                ~metadata:
                  [ ( "slot"
                    , Mina_numbers.Global_slot_since_genesis.to_yojson
                        (Mina_numbers.Global_slot_since_genesis.of_uint32 slot)
                    )
                  ; ("state", Consensus_state.Value.to_yojson state)
                  ] ;
              failwith
                "Checking slot-winner for a slot which is older than the slot \
                 in the latest consensus state. System time might be \
                 out-of-sync"
          | Some diff ->
              diff
        in
        Mina_numbers.Global_slot_since_genesis.add
          (Consensus_state.global_slot_since_genesis state)
          slot_diff
      in
      let delegatee_table = epoch_snapshot.delegatee_table in
      ( Epoch_data_for_vrf.
          { epoch_ledger = epoch_data.ledger
          ; epoch_seed = epoch_data.seed
          ; delegatee_table
          ; epoch
          ; global_slot
          ; global_slot_since_genesis
          }
      , epoch_snapshot.ledger )

    let get_block_data ~(slot_won : Slot_won.t) ~ledger_snapshot
        ~coinbase_receiver =
      let delegator_pk, delegator_idx = slot_won.delegator in
      let producer_public_key = slot_won.producer.public_key in
      let producer_private_key = slot_won.producer.private_key in
      let producer_pk = Public_key.compress producer_public_key in
      { Block_data.stake_proof =
          { producer_private_key
          ; producer_public_key
          ; delegator = delegator_idx
          ; delegator_pk
          ; coinbase_receiver_pk =
              Coinbase_receiver.resolve ~self:producer_pk coinbase_receiver
          ; ledger =
              Local_state.Snapshot.Ledger_snapshot.ledger_subset
                [ Mina_base.(Account_id.create producer_pk Token_id.default)
                ; Mina_base.(Account_id.create delegator_pk Token_id.default)
                ]
                ledger_snapshot
          }
      ; global_slot = slot_won.global_slot
      ; global_slot_since_genesis = slot_won.global_slot_since_genesis
      ; vrf_result = slot_won.vrf_result
      }

    let frontier_root_transition (prev : Consensus_state.Value.t)
        (next : Consensus_state.Value.t) ~(local_state : Local_state.t)
        ~snarked_ledger ~genesis_ledger_hash =
      let snarked_ledger_hash =
        Mina_ledger.Ledger.Db.merkle_root snarked_ledger
      in
      if
        not
          (Epoch.equal
             (Consensus_state.curr_epoch prev)
             (Consensus_state.curr_epoch next) )
      then (
        !local_state.last_epoch_delegatee_table <-
          Some !local_state.staking_epoch_snapshot.delegatee_table ;
        Local_state.Snapshot.Ledger_snapshot.remove
          !local_state.staking_epoch_snapshot.ledger
          ~location:(Local_state.staking_epoch_ledger_location local_state) ;
        !local_state.staking_epoch_snapshot <- !local_state.next_epoch_snapshot ;
        (*If snarked ledger hash is still the genesis ledger hash then the epoch ledger should continue to be `next_data.ledger`. This is because the epoch ledgers at genesis can be different from the genesis ledger*)
        if
          not
            (Mina_base.Frozen_ledger_hash.equal snarked_ledger_hash
               genesis_ledger_hash )
        then (
          let epoch_ledger_uuids =
            Local_state.Data.
              { staking = !local_state.epoch_ledger_uuids.next
              ; next = Uuid_unix.create ()
              ; genesis_state_hash =
                  !local_state.epoch_ledger_uuids.genesis_state_hash
              }
          in
          !local_state.epoch_ledger_uuids <- epoch_ledger_uuids ;
          Yojson.Safe.to_file
            (!local_state.epoch_ledger_location ^ ".json")
            (Local_state.epoch_ledger_uuids_to_yojson epoch_ledger_uuids) ;
          !local_state.next_epoch_snapshot <-
            { ledger =
                Local_state.Snapshot.Ledger_snapshot.Ledger_db
                  (Mina_ledger.Ledger.Db.create_checkpoint snarked_ledger
                     ~directory_name:
                       ( !local_state.epoch_ledger_location
                       ^ Uuid.to_string epoch_ledger_uuids.next )
                     () )
            ; delegatee_table =
                compute_delegatee_table_ledger_db
                  (Local_state.current_block_production_keys local_state)
                  snarked_ledger
            } ) )

    let should_bootstrap_len ~context:(module Context : CONTEXT) ~existing
        ~candidate =
      let open Context in
      let open UInt32.Infix in
      UInt32.compare (candidate - existing)
        ( (UInt32.of_int 2 * consensus_constants.k)
        + (consensus_constants.delta + UInt32.of_int 1) )
      > 0

    let should_bootstrap ~context:(module Context : CONTEXT) ~existing
        ~candidate =
      match select ~context:(module Context) ~existing ~candidate with
      | `Keep ->
          false
      | `Take ->
          should_bootstrap_len
            ~context:(module Context)
            ~existing:
              (Consensus_state.blockchain_length (With_hash.data existing))
            ~candidate:
              (Consensus_state.blockchain_length (With_hash.data candidate))

    let%test "should_bootstrap is sane" =
      let module Context = struct
        let logger = Logger.create ()

        let constraint_constants =
          Genesis_constants.For_unit_tests.Constraint_constants.t

        let consensus_constants = Lazy.force Constants.for_unit_tests
      end in
      (* Even when consensus constants are of prod sizes, candidate should still trigger a bootstrap *)
      should_bootstrap_len
        ~context:(module Context)
        ~existing:Length.zero
        ~candidate:(Length.of_int 100_000_000)

    let to_unix_timestamp recieved_time =
      recieved_time |> Time.to_span_since_epoch |> Time.Span.to_ms
      |> Mina_stdlib.Unix_timestamp.of_int64

    let%test "Receive a valid consensus_state with a bit of delay" =
      let constants = Lazy.force Constants.for_unit_tests in
      let genesis_ledger = Genesis_ledger.(Packed.t for_unit_tests) in
      let genesis_epoch_data = Genesis_epoch_data.for_unit_tests in
      let negative_one =
        Consensus_state.negative_one ~genesis_ledger ~genesis_epoch_data
          ~constants
          ~constraint_constants:
            Genesis_constants.For_unit_tests.Constraint_constants.t
      in
      let curr_epoch, curr_slot =
        Consensus_state.curr_epoch_and_slot negative_one
      in
      let delay = UInt32.(div (add constants.delta (of_int 1)) (of_int 2)) in
      let new_slot = UInt32.Infix.(curr_slot + delay) in
      let time_received =
        Epoch.slot_start_time ~constants curr_epoch new_slot
      in
      received_at_valid_time ~constants negative_one
        ~time_received:(to_unix_timestamp time_received)
      |> Result.is_ok

    let%test "Receive an invalid consensus_state" =
      let epoch = Epoch.of_int 5 in
      let constants = Lazy.force Constants.for_unit_tests in
      let genesis_ledger = Genesis_ledger.(Packed.t for_unit_tests) in
      let genesis_epoch_data = Genesis_epoch_data.for_unit_tests in
      let negative_one =
        Consensus_state.negative_one ~genesis_ledger ~genesis_epoch_data
          ~constants
          ~constraint_constants:
            Genesis_constants.For_unit_tests.Constraint_constants.t
      in
      let start_time = Epoch.start_time ~constants epoch in
      let ((curr_epoch, curr_slot) as curr) =
        Epoch_and_slot.of_time_exn ~constants start_time
      in
      let curr_global_slot_since_hard_fork =
        Global_slot.of_epoch_and_slot ~constants curr
      in
      let consensus_state =
        let global_slot_since_genesis =
          (* for testing, consider slot-since-hard-fork as since-genesis *)
          Global_slot.slot_number curr_global_slot_since_hard_fork
          |> Mina_numbers.Global_slot_since_hard_fork.to_uint32
          |> Mina_numbers.Global_slot_since_genesis.of_uint32
        in
        { negative_one with
          curr_global_slot_since_hard_fork
        ; global_slot_since_genesis
        }
      in
      let too_early =
        (* TODO: Does this make sense? *)
        Epoch.start_time ~constants (Consensus_state.curr_slot negative_one)
      in
      let too_late =
        let delay = UInt32.(mul (add constants.delta (of_int 1)) (of_int 2)) in
        let delayed_slot = UInt32.Infix.(curr_slot + delay) in
        Epoch.slot_start_time ~constants curr_epoch delayed_slot
      in
      let times = [ too_late; too_early ] in
      List.for_all times ~f:(fun time ->
          not
            ( received_at_valid_time ~constants consensus_state
                ~time_received:(to_unix_timestamp time)
            |> Result.is_ok ) )

    module type State_hooks_intf =
      Intf.State_hooks
        with type consensus_state := Consensus_state.Value.t
         and type consensus_state_var := Consensus_state.var
         and type consensus_transition := Consensus_transition.t
         and type block_data := Block_data.t

    module Make_state_hooks
        (Blockchain_state : Intf.Blockchain_state)
        (Protocol_state : Intf.Protocol_state
                            with type blockchain_state :=
                              Blockchain_state.Value.t
                             and type blockchain_state_var :=
                              Blockchain_state.var
                             and type consensus_state := Consensus_state.Value.t
                             and type consensus_state_var := Consensus_state.var)
        (Snark_transition : Intf.Snark_transition
                              with type blockchain_state_var :=
                                Blockchain_state.var
                               and type consensus_transition_var :=
                                Consensus_transition.var) :
      State_hooks_intf
        with type blockchain_state := Blockchain_state.Value.t
         and type protocol_state := Protocol_state.Value.t
         and type protocol_state_var := Protocol_state.var
         and type snark_transition_var := Snark_transition.var = struct
      (* TODO: only track total currency from accounts > 1% of the currency using transactions *)

      let genesis_winner = Vrf.Precomputed.genesis_winner

      let genesis_winner_account =
        Mina_base.Account.create
          (Mina_base.Account_id.create (fst genesis_winner)
             Mina_base.Token_id.default )
          (Currency.Balance.of_nanomina_int_exn 1000)

      let check_block_data ~constants ~logger (block_data : Block_data.t)
          global_slot =
        if
          not
            (Mina_numbers.Global_slot_since_hard_fork.equal
               (Global_slot.slot_number global_slot)
               block_data.global_slot )
        then
          [%log error]
            !"VRF was evaluated at (epoch, slot) %{sexp:Epoch_and_slot.t} but \
              the corresponding block was produced at a time corresponding to \
              %{sexp:Epoch_and_slot.t}. This means that generating the block \
              took more time than expected."
            (Global_slot.to_epoch_and_slot
               (Global_slot.of_slot_number ~constants block_data.global_slot) )
            (Global_slot.to_epoch_and_slot global_slot)

      let generate_transition
          ~(previous_protocol_state : Protocol_state.Value.t) ~blockchain_state
          ~current_time ~(block_data : Block_data.t) ~supercharge_coinbase
          ~snarked_ledger_hash ~genesis_ledger_hash ~supply_increase ~logger
          ~constraint_constants =
        [%log internal] "Generate_transition" ;
        let previous_consensus_state =
          Protocol_state.consensus_state previous_protocol_state
        in
        let constants =
          Constants.create ~constraint_constants
            ~protocol_constants:
              ( Protocol_state.constants previous_protocol_state
              |> Mina_base.Protocol_constants_checked.t_of_value )
        in
        (let actual_global_slot =
           let time = Time.of_span_since_epoch (Time.Span.of_ms current_time) in
           Global_slot.of_epoch_and_slot ~constants
             (Epoch_and_slot.of_time_exn ~constants time)
         in
         check_block_data ~constants ~logger block_data actual_global_slot ) ;
        let consensus_transition = block_data.global_slot in
        let previous_protocol_state_hash =
          Protocol_state.hash previous_protocol_state
        in
        let block_creator =
          block_data.stake_proof.producer_public_key |> Public_key.compress
        in
        [%log internal] "Consensus_state_update" ;
        let consensus_state =
          Or_error.ok_exn
            (Consensus_state.update ~constants ~previous_consensus_state
               ~consensus_transition
               ~producer_vrf_result:block_data.Block_data.vrf_result
               ~previous_protocol_state_hash ~supply_increase
               ~snarked_ledger_hash ~genesis_ledger_hash
               ~block_stake_winner:block_data.stake_proof.delegator_pk
               ~block_creator
               ~coinbase_receiver:block_data.stake_proof.coinbase_receiver_pk
               ~supercharge_coinbase )
        in
        [%log internal] "Consensus_state_update_done" ;
        let genesis_state_hash =
          Protocol_state.genesis_state_hash
            ~state_hash:(Some previous_protocol_state_hash)
            previous_protocol_state
        in
        let protocol_state =
          Protocol_state.create_value ~genesis_state_hash
            ~previous_state_hash:(Protocol_state.hash previous_protocol_state)
            ~blockchain_state ~consensus_state
            ~constants:(Protocol_state.constants previous_protocol_state)
        in
        [%log internal] "Generate_transition_done" ;
        (protocol_state, consensus_transition)

      include struct
        let%snarkydef.Tick next_state_checked ~constraint_constants
            ~(prev_state : Protocol_state.var)
            ~(prev_state_hash : Mina_base.State_hash.var) transition
            supply_increase =
          Consensus_state.update_var ~constraint_constants
            (Protocol_state.consensus_state prev_state)
            (Snark_transition.consensus_transition transition)
            prev_state_hash ~supply_increase
            ~previous_blockchain_state_ledger_hash:
              ( Protocol_state.blockchain_state prev_state
              |> Blockchain_state.snarked_ledger_hash )
            ~genesis_ledger_hash:
              ( Protocol_state.blockchain_state prev_state
              |> Blockchain_state.genesis_ledger_hash )
            ~protocol_constants:(Protocol_state.constants prev_state)
      end

      module For_tests = struct
        let gen_consensus_state
            ~(constraint_constants : Genesis_constants.Constraint_constants.t)
            ~constants ~(slot_advancement : int) :
            (   previous_protocol_state:
                  Protocol_state.Value.t
                  Mina_base.State_hash.With_state_hashes.t
             -> snarked_ledger_hash:Mina_base.Frozen_ledger_hash.t
             -> coinbase_receiver:Public_key.Compressed.t
             -> supercharge_coinbase:bool
             -> Consensus_state.Value.t )
            Quickcheck.Generator.t =
          let open Consensus_state in
          let genesis_ledger_hash =
            let (module L) = Genesis_ledger.for_unit_tests in
            Lazy.force L.t |> Mina_ledger.Ledger.merkle_root
            |> Mina_base.Frozen_ledger_hash.of_ledger_hash
          in
          let open Quickcheck.Let_syntax in
          let%map producer_vrf_result = Vrf.Output.gen in
          fun ~(previous_protocol_state :
                 Protocol_state.Value.t Mina_base.State_hash.With_state_hashes.t
                 ) ~(snarked_ledger_hash : Mina_base.Frozen_ledger_hash.t)
              ~coinbase_receiver ~supercharge_coinbase ->
            let prev =
              Protocol_state.consensus_state
                (With_hash.data previous_protocol_state)
            in
            let blockchain_length = Length.succ prev.blockchain_length in
            let curr_global_slot_since_hard_fork =
              Global_slot.(
                prev.curr_global_slot_since_hard_fork + slot_advancement)
            in
            let global_slot_since_genesis =
              Mina_numbers.Global_slot_since_genesis.add
                prev.global_slot_since_genesis
                (Mina_numbers.Global_slot_span.of_int slot_advancement)
            in
            let curr_epoch, curr_slot =
              Global_slot.to_epoch_and_slot curr_global_slot_since_hard_fork
            in
            let total_currency =
              Option.value_exn
                (Amount.add prev.total_currency
                   constraint_constants.coinbase_amount )
            in
            let prev_epoch, prev_slot =
              Consensus_state.curr_epoch_and_slot prev
            in
            let staking_epoch_data, next_epoch_data, epoch_count =
              Epoch_data.update_pair ~constants
                (prev.staking_epoch_data, prev.next_epoch_data)
                prev.epoch_count ~prev_epoch ~next_epoch:curr_epoch
                ~next_slot:curr_slot
                ~prev_protocol_state_hash:
                  (Mina_base.State_hash.With_state_hashes.state_hash
                     previous_protocol_state )
                ~producer_vrf_result ~snarked_ledger_hash ~genesis_ledger_hash
                ~total_currency
            in
            let min_window_density, sub_window_densities =
              Min_window_density.update_min_window_density ~constants
                ~incr_window:true
                ~prev_global_slot:prev.curr_global_slot_since_hard_fork
                ~next_global_slot:curr_global_slot_since_hard_fork
                ~prev_sub_window_densities:prev.sub_window_densities
                ~prev_min_window_density:prev.min_window_density
            in
            let genesis_winner_pk = fst Vrf.Precomputed.genesis_winner in
            { Poly.blockchain_length
            ; epoch_count
            ; min_window_density
            ; sub_window_densities
            ; last_vrf_output = Vrf.Output.truncate producer_vrf_result
            ; total_currency
            ; curr_global_slot_since_hard_fork
            ; global_slot_since_genesis
            ; staking_epoch_data
            ; next_epoch_data
            ; has_ancestor_in_same_checkpoint_window =
                same_checkpoint_window_unchecked ~constants
                  (Global_slot.create ~constants ~epoch:prev_epoch
                     ~slot:prev_slot )
                  (Global_slot.create ~constants ~epoch:curr_epoch
                     ~slot:curr_slot )
            ; block_stake_winner = genesis_winner_pk
            ; block_creator = genesis_winner_pk
            ; coinbase_receiver
            ; supercharge_coinbase
            }
      end
    end
  end

  let time_hum ~(constants : Constants.t) (now : Block_time.t) =
    let epoch, slot = Epoch.epoch_and_slot_of_time_exn ~constants now in
    Printf.sprintf "epoch=%d, slot=%d" (Epoch.to_int epoch) (Slot.to_int slot)

  let%test_module "Proof of stake tests" =
    ( module struct
      open Mina_base
      open Mina_ledger
      open Data
      open Consensus_state

      let constraint_constants =
        Genesis_constants.For_unit_tests.Constraint_constants.t

      let constants = Lazy.force Constants.for_unit_tests

      let genesis_epoch_data = Genesis_epoch_data.for_unit_tests

      module Genesis_ledger = (val Genesis_ledger.for_unit_tests)

      module Context : CONTEXT = struct
        let logger = Logger.null ()

        let constraint_constants = constraint_constants

        let consensus_constants = constants
      end

      let test_update constraint_constants =
        (* build pieces needed to apply "update" *)
        let snarked_ledger_hash =
          Frozen_ledger_hash.of_ledger_hash
            (Ledger.merkle_root (Lazy.force Genesis_ledger.t))
        in
        let previous_protocol_state_hash = State_hash.(of_hash zero) in
        let previous_consensus_state =
          Consensus_state.create_genesis
            ~negative_one_protocol_state_hash:previous_protocol_state_hash
            ~genesis_ledger:Genesis_ledger.t ~genesis_epoch_data
            ~constraint_constants ~constants
        in
        (*If this is a fork then check blockchain length and global_slot_since_genesis have been set correctly*)
        ( match constraint_constants.fork with
        | None ->
            ()
        | Some fork ->
            assert (
              Mina_numbers.Global_slot_since_genesis.(
                equal fork.global_slot_since_genesis
                  previous_consensus_state.global_slot_since_genesis) ) ;
            assert (
              Mina_numbers.Length.(
                equal
                  (succ fork.blockchain_length)
                  previous_consensus_state.blockchain_length) ) ) ;
        let global_slot =
          Core_kernel.Time.now () |> Time.of_time
          |> Epoch_and_slot.of_time_exn ~constants
          |> Global_slot.of_epoch_and_slot ~constants
        in
        let consensus_transition : Consensus_transition.t =
          Global_slot.slot_number global_slot
        in
        let supply_increase =
          Currency.Amount.(Signed.of_unsigned (of_nanomina_int_exn 42))
        in
        (* setup ledger, needed to compute producer_vrf_result here and handler below *)
        let open Mina_base in
        (* choose largest account as most likely to produce a block *)
        let ledger_data = Lazy.force Genesis_ledger.t in
        let ledger = Ledger.Any_ledger.cast (module Ledger) ledger_data in
        let pending_coinbases =
          Pending_coinbase.create
            ~depth:constraint_constants.pending_coinbase_depth ()
          |> Or_error.ok_exn
        in
        let maybe_sk, account = Genesis_ledger.largest_account_exn () in
        let producer_private_key = Option.value_exn maybe_sk in
        let producer_public_key_compressed = Account.public_key account in
        let account_id =
          Account_id.create producer_public_key_compressed Token_id.default
        in
        let location =
          Ledger.Any_ledger.M.location_of_account ledger account_id
        in
        let delegator =
          Option.value_exn location |> Ledger.Any_ledger.M.Location.to_path_exn
          |> Ledger.Addr.to_int
        in
        let producer_vrf_result =
          let seed =
            let next_epoch, _ = Global_slot.to_epoch_and_slot global_slot in
            let prev_epoch, _ =
              Global_slot.to_epoch_and_slot
                previous_consensus_state.curr_global_slot_since_hard_fork
            in
            if UInt32.compare next_epoch prev_epoch > 0 then
              previous_consensus_state.next_epoch_data.seed
            else previous_consensus_state.staking_epoch_data.seed
          in
          Vrf.eval ~constraint_constants ~private_key:producer_private_key
            { global_slot = Global_slot.slot_number global_slot
            ; seed
            ; delegator
            }
        in
        let next_consensus_state =
          update ~constants ~previous_consensus_state ~consensus_transition
            ~previous_protocol_state_hash ~supply_increase ~snarked_ledger_hash
            ~genesis_ledger_hash:snarked_ledger_hash ~producer_vrf_result
            ~block_stake_winner:producer_public_key_compressed
            ~block_creator:producer_public_key_compressed
            ~coinbase_receiver:producer_public_key_compressed
            ~supercharge_coinbase:true
          |> Or_error.ok_exn
        in
        (*If this is a fork then check blockchain length and global_slot_since_genesis have increased correctly*)
        ( match constraint_constants.fork with
        | None ->
            ()
        | Some fork ->
            let slot_diff =
              Option.value_exn
                (Global_slot.diff_slots global_slot
                   previous_consensus_state.curr_global_slot_since_hard_fork )
            in
            assert (
              Mina_numbers.Global_slot_since_genesis.(
                equal
                  (add fork.global_slot_since_genesis slot_diff)
                  next_consensus_state.global_slot_since_genesis) ) ;
            assert (
              Mina_numbers.Length.(
                equal
                  (succ (succ fork.blockchain_length))
                  next_consensus_state.blockchain_length) ) ) ;
        (* build pieces needed to apply "update_var" *)
        let checked_computation =
          let open Snark_params.Tick in
          (* work in Checked monad *)
          let%bind previous_state =
            exists
              (typ ~constraint_constants)
              ~compute:(As_prover.return previous_consensus_state)
          in
          let%bind transition_data =
            exists Consensus_transition.typ
              ~compute:(As_prover.return consensus_transition)
          in
          let%bind previous_protocol_state_hash =
            exists State_hash.typ
              ~compute:(As_prover.return previous_protocol_state_hash)
          in
          let%bind supply_increase =
            exists Amount.Signed.typ ~compute:(As_prover.return supply_increase)
          in
          let%bind previous_blockchain_state_ledger_hash =
            exists Mina_base.Frozen_ledger_hash.typ
              ~compute:(As_prover.return snarked_ledger_hash)
          in
          let genesis_ledger_hash = previous_blockchain_state_ledger_hash in
          let%bind constants_checked =
            exists Mina_base.Protocol_constants_checked.typ
              ~compute:
                (As_prover.return
                   (Mina_base.Protocol_constants_checked.value_of_t
                      Genesis_constants.For_unit_tests.t.protocol ) )
          in
          let result =
            update_var previous_state transition_data
              previous_protocol_state_hash ~supply_increase
              ~previous_blockchain_state_ledger_hash ~genesis_ledger_hash
              ~constraint_constants ~protocol_constants:constants_checked
          in
          (* setup handler *)
          let indices =
            Ledger.Any_ledger.M.foldi ~init:[] ledger ~f:(fun i accum _acct ->
                Ledger.Any_ledger.M.Addr.to_int i :: accum )
          in
          let sparse_ledger =
            Sparse_ledger.of_ledger_index_subset_exn ledger indices
          in
          let producer_public_key =
            Public_key.decompress_exn producer_public_key_compressed
          in
          let handler =
            Prover_state.handler ~constraint_constants
              { delegator
              ; delegator_pk = producer_public_key_compressed
              ; coinbase_receiver_pk = producer_public_key_compressed
              ; ledger = sparse_ledger
              ; producer_private_key
              ; producer_public_key
              }
              ~pending_coinbase:
                { Pending_coinbase_witness.pending_coinbases
                ; is_new_stack = true
                }
          in
          let%map `Success _, var =
            Snark_params.Tick.handle (fun () -> result) handler
          in
          As_prover.read (typ ~constraint_constants) var
        in
        let checked_value =
          Or_error.ok_exn @@ Snark_params.Tick.run_and_check checked_computation
        in
        let diff =
          Sexp_diff_kernel.Algo.diff
            ~original:(Value.sexp_of_t checked_value)
            ~updated:(Value.sexp_of_t next_consensus_state)
            ()
        in
        if not (Value.equal checked_value next_consensus_state) then (
          eprintf "Different states:\n%s\n%!"
            (Sexp_diff_kernel.Display.display_with_ansi_colors
               (Sexp_diff_kernel.Display.Display_options.create
                  ~collapse_threshold:1000 Two_column )
               diff ) ;
          failwith "Test failed" )

      let%test_unit "update, update_var agree starting from same genesis state"
          =
        test_update constraint_constants

      let%test_unit "update, update_var agree starting from same genesis state \
                     after fork" =
        let constraint_constants_with_fork =
          let fork_constants =
            Some
              { Genesis_constants.Fork_constants.state_hash =
                  Result.ok_or_failwith
                    (State_hash.of_yojson
                       (`String
                         "3NL3bc213VQEFx6XTLbc3HxHqHH9ANbhHxRxSnBcRzXcKgeFA6TY"
                         ) )
              ; blockchain_length = Mina_numbers.Length.of_int 100
              ; global_slot_since_genesis =
                  Mina_numbers.Global_slot_since_genesis.of_int 200
              }
          in
          { constraint_constants with fork = fork_constants }
        in
        test_update constraint_constants_with_fork

      let%test_unit "vrf win rate" =
        let constants = Lazy.force Constants.for_unit_tests in
        let constraint_constants =
          Genesis_constants.For_unit_tests.Constraint_constants.t
        in
        let previous_protocol_state_hash =
          Mina_base.State_hash.(of_hash zero)
        in
        let previous_consensus_state =
          Consensus_state.create_genesis
            ~negative_one_protocol_state_hash:previous_protocol_state_hash
            ~genesis_ledger:Genesis_ledger.t ~genesis_epoch_data
            ~constraint_constants ~constants
        in
        let seed = previous_consensus_state.staking_epoch_data.seed in
        let maybe_sk, account = Genesis_ledger.largest_account_exn () in
        let private_key = Option.value_exn maybe_sk in
        let public_key_compressed = Account.public_key account in
        let total_stake =
          genesis_ledger_total_currency ~ledger:Genesis_ledger.t
        in
        let block_producer_pubkeys =
          Public_key.Compressed.Set.of_list [ public_key_compressed ]
        in
        let ledger = Lazy.force Genesis_ledger.t in
        let delegatee_table =
          compute_delegatee_table_genesis_ledger block_producer_pubkeys ledger
        in
        let epoch_snapshot =
          { Local_state.Snapshot.delegatee_table
          ; ledger = Genesis_epoch_ledger ledger
          }
        in
        let balance = Balance.to_nanomina_int account.balance in
        let total_stake_int = Currency.Amount.to_nanomina_int total_stake in
        let stake_fraction =
          float_of_int balance /. float_of_int total_stake_int
        in
        let expected = stake_fraction *. 0.75 in
        let samples = 1000 in
        let check i =
          let global_slot = Mina_numbers.Global_slot_since_hard_fork.of_int i in
          let%map result =
            Interruptible.force
              (Vrf.check
                 ~context:(module Context)
                 ~global_slot ~seed ~producer_private_key:private_key
                 ~producer_public_key:public_key_compressed ~total_stake
                 ~get_delegators:
                   (Local_state.Snapshot.delegators epoch_snapshot) )
          in
          match Result.ok_exn result with Some _ -> 1 | None -> 0
        in
        let rec loop acc_count i =
          match i < samples with
          | true ->
              let%bind count = check i in
              loop (acc_count + count) (i + 1)
          | false ->
              return acc_count
        in
        let actual =
          Async.Thread_safe.block_on_async_exn (fun () -> loop 0 0)
        in
        let diff =
          Float.abs (float_of_int actual -. (expected *. float_of_int samples))
        in
        let tolerance = 100. in
        (* 100 is a reasonable choice for samples = 1000 and for very low likelihood of failure; this should be recalculated if sample count was to be adjusted *)
        let within_tolerance = Float.(diff < tolerance) in
        if not within_tolerance then
          failwithf "actual vs. expected: %d vs %f" actual expected ()

      (* Consensus selection tests. *)

      let sum_lengths = List.fold ~init:Length.zero ~f:Length.add

      let rec gen_except ~exclude ~gen ~equal =
        let open Quickcheck.Generator.Let_syntax in
        let%bind x = gen in
        if List.mem exclude x ~equal then gen_except ~exclude ~gen ~equal
        else return x

      (* This generator is quadratic, but that should be ok since the max amount we generate with it
       * is 8. *)
      let gen_unique_list amount ~gen ~equal =
        let rec loop n ls =
          let open Quickcheck.Generator.Let_syntax in
          if n <= 0 then return ls
          else
            let%bind x = gen_except ~exclude:ls ~gen ~equal in
            loop (n - 1) (x :: ls)
        in
        loop amount []

      let gen_with_hash gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind data = gen in
        let%map hash = State_hash.gen in
        { With_hash.data
        ; hash =
            { State_hash.State_hashes.state_hash = hash
            ; state_body_hash = None
            }
        }

      let gen_num_blocks_in_slots ~slot_fill_rate ~slot_fill_rate_delta n =
        let open Quickcheck.Generator.Let_syntax in
        let min_blocks =
          Float.to_int
            ( Float.of_int n
            *. Float.max (slot_fill_rate -. slot_fill_rate_delta) 0.0 )
        in
        let max_blocks =
          Float.to_int
            ( Float.of_int n
            *. Float.min (slot_fill_rate +. slot_fill_rate_delta) 1.0 )
        in
        Core.Int.gen_incl min_blocks max_blocks >>| Length.of_int

      let gen_num_blocks_in_epochs ~slot_fill_rate ~slot_fill_rate_delta n =
        gen_num_blocks_in_slots ~slot_fill_rate ~slot_fill_rate_delta
          (n * Length.to_int constants.slots_per_epoch)

      let gen_min_density_windows_from_slot_fill_rate ~slot_fill_rate
          ~slot_fill_rate_delta =
        let open Quickcheck.Generator.Let_syntax in
        let constants = Lazy.force Constants.for_unit_tests in
        let constraint_constants =
          Genesis_constants.For_unit_tests.Constraint_constants.t
        in
        let gen_sub_window_density =
          gen_num_blocks_in_slots ~slot_fill_rate ~slot_fill_rate_delta
            (Length.to_int constants.slots_per_sub_window)
        in
        let%map sub_window_densities =
          Quickcheck.Generator.list_with_length
            constraint_constants.sub_windows_per_window gen_sub_window_density
        in
        let min_window_density =
          List.fold ~init:Length.zero ~f:Length.add
            (List.take sub_window_densities
               (List.length sub_window_densities - 1) )
        in
        (min_window_density, sub_window_densities)

      (* Computes currency at height, assuming every block contains coinbase (ignoring inflation scheduling). *)
      let currency_at_height ~genesis_currency height =
        let constraint_constants =
          Genesis_constants.For_unit_tests.Constraint_constants.t
        in
        Option.value_exn
          Amount.(
            genesis_currency
            + of_nanomina_int_exn
                (height * to_nanomina_int constraint_constants.coinbase_amount))

      (* TODO: Deprecate this in favor of just returning a constant in the monad from the outside. *)
      let opt_gen opt ~gen =
        match opt with Some v -> Quickcheck.Generator.return v | None -> gen

      let gen_epoch_data ~genesis_currency ~starts_at_block_height
          ?start_checkpoint ?lock_checkpoint epoch_length :
          Epoch_data.Value.t Quickcheck.Generator.t =
        let open Quickcheck.Generator.Let_syntax in
        let height_at_end_of_epoch =
          Length.add starts_at_block_height epoch_length
        in
        let%bind ledger_hash = Frozen_ledger_hash.gen in
        let%bind seed = Epoch_seed.gen in
        let%bind start_checkpoint =
          opt_gen start_checkpoint ~gen:State_hash.gen
        in
        let%map lock_checkpoint = opt_gen lock_checkpoint ~gen:State_hash.gen in
        let ledger : Epoch_ledger.Value.t =
          { hash = ledger_hash
          ; total_currency =
              currency_at_height ~genesis_currency
                (Length.to_int height_at_end_of_epoch)
          }
        in
        { Epoch_data.Poly.ledger
        ; seed
        ; start_checkpoint
        ; lock_checkpoint
        ; epoch_length
        }

      let default_slot_fill_rate = 0.65

      let default_slot_fill_rate_delta = 0.15

      (** A root epoch of a block refers the epoch from which we can begin
         *  simulating information for that block. Because we need to simulate
         *  both the staking epoch and the next staking epoch, the root epoch
         *  is the staking epoch. The root epoch position this function generates
         *  is the epoch number of the staking epoch and the block height the
         *  staking epoch starts at (the simulation of all blocks preceeding the
         *  staking epoch).
         *)
      let gen_spot_root_epoch_position ~slot_fill_rate ~slot_fill_rate_delta =
        let open Quickcheck.Generator.Let_syntax in
        let%bind root_epoch_int = Core.Int.gen_incl 0 100 in
        let%map root_block_height =
          gen_num_blocks_in_epochs ~slot_fill_rate ~slot_fill_rate_delta
            root_epoch_int
        in
        (UInt32.of_int root_epoch_int, root_block_height)

      let gen_vrf_output =
        let open Quickcheck.Generator.Let_syntax in
        let%map output = Vrf.Output.gen in
        Vrf.Output.truncate output

      (* TODO: consider shoving this logic directly into Field.gen to avoid non-deterministic cycles *)
      let rec gen_vrf_output_gt target =
        let open Quickcheck.Generator.Let_syntax in
        let string_of_blake2 =
          Blake2.(Fn.compose to_raw_string digest_string)
        in
        let compare_blake2 a b =
          String.compare (string_of_blake2 a) (string_of_blake2 b)
        in
        let%bind output = gen_vrf_output in
        if compare_blake2 target output < 0 then return output
        else gen_vrf_output_gt target

      (** This generator generates blocks "from thin air" by simulating
         *  the properties of a chain up to a point in time. This avoids
         *  the work of computing all prior blocks in order to generate
         *  a block at some point in the chain, hence why it is coined a
         *  "spot generator".
         *
         * TODO:
         *   - special case genesis
         *   - has_ancestor_in_same_checkpoint_window
         * NOTES:
         *   - vrf outputs and ledger hashes are entirely fake
         *   - density windows are computed distinctly from block heights and epoch lengths, so some non-obvious invariants may be broken there
         *)
      let gen_spot ?root_epoch_position
          ?(slot_fill_rate = default_slot_fill_rate)
          ?(slot_fill_rate_delta = default_slot_fill_rate_delta)
          ?(genesis_currency = Currency.Amount.of_nanomina_int_exn 200_000)
          ?gen_staking_epoch_length ?gen_next_epoch_length
          ?gen_curr_epoch_position ?staking_start_checkpoint
          ?staking_lock_checkpoint ?next_start_checkpoint ?next_lock_checkpoint
          ?(gen_vrf_output = gen_vrf_output) () :
          Consensus_state.Value.t Quickcheck.Generator.t =
        let open Quickcheck.Generator.Let_syntax in
        let constants = Lazy.force Constants.for_unit_tests in
        let gen_num_blocks_in_slots =
          gen_num_blocks_in_slots ~slot_fill_rate ~slot_fill_rate_delta
        in
        let gen_num_blocks_in_epochs =
          gen_num_blocks_in_epochs ~slot_fill_rate ~slot_fill_rate_delta
        in
        (* Populate default generators. *)
        let gen_staking_epoch_length =
          Option.value gen_staking_epoch_length
            ~default:(gen_num_blocks_in_epochs 1)
        in
        let gen_next_epoch_length =
          Option.value gen_next_epoch_length
            ~default:(gen_num_blocks_in_epochs 1)
        in
        let gen_curr_epoch_position =
          let default =
            let max_epoch_slot = Length.to_int constants.slots_per_epoch - 1 in
            let%bind curr_epoch_slot =
              Core.Int.gen_incl 0 max_epoch_slot >>| UInt32.of_int
            in
            let%map curr_epoch_length =
              gen_num_blocks_in_slots (Length.to_int curr_epoch_slot)
            in
            (curr_epoch_slot, curr_epoch_length)
          in
          Option.value gen_curr_epoch_position ~default
        in
        let%bind root_epoch, root_block_height =
          match root_epoch_position with
          | Some (root_epoch, root_block_height) ->
              return (root_epoch, root_block_height)
          | None ->
              gen_spot_root_epoch_position ~slot_fill_rate ~slot_fill_rate_delta
        in
        (* Generate blockchain position and epoch lengths. *)
        (* staking_epoch == root_epoch, next_staking_epoch == root_epoch + 1 *)
        let curr_epoch = Length.add root_epoch (Length.of_int 2) in
        let%bind staking_epoch_length = gen_staking_epoch_length in
        let%bind next_staking_epoch_length = gen_next_epoch_length in
        let%bind curr_epoch_slot, curr_epoch_length = gen_curr_epoch_position in
        (* Compute state slot and length. *)
        let curr_global_slot_since_hard_fork =
          Global_slot.of_epoch_and_slot ~constants (curr_epoch, curr_epoch_slot)
        in
        let blockchain_length =
          sum_lengths
            [ root_block_height
            ; staking_epoch_length
            ; next_staking_epoch_length
            ; curr_epoch_length
            ]
        in
        (* Compute total currency for state. *)
        let total_currency =
          currency_at_height ~genesis_currency (Length.to_int blockchain_length)
        in
        (* Generate epoch data for staking and next epochs. *)
        let%bind staking_epoch_data =
          gen_epoch_data ~genesis_currency
            ~starts_at_block_height:root_block_height
            ?start_checkpoint:staking_start_checkpoint
            ?lock_checkpoint:staking_lock_checkpoint staking_epoch_length
        in
        let%bind next_staking_epoch_data =
          gen_epoch_data ~genesis_currency
            ~starts_at_block_height:
              (Length.add root_block_height staking_epoch_length)
            ?start_checkpoint:next_start_checkpoint
            ?lock_checkpoint:next_lock_checkpoint next_staking_epoch_length
        in
        (* Generate chain quality and vrf output. *)
        let%bind min_window_density, sub_window_densities =
          gen_min_density_windows_from_slot_fill_rate ~slot_fill_rate
            ~slot_fill_rate_delta
        in
        let%bind vrf_output = gen_vrf_output in
        (* Generate block reward information (unused in chain selection). *)
        let%map staker_pk = Public_key.Compressed.gen in
        { Consensus_state.Poly.blockchain_length
        ; epoch_count = curr_epoch
        ; min_window_density
        ; sub_window_densities
        ; last_vrf_output = vrf_output
        ; total_currency
        ; curr_global_slot_since_hard_fork
        ; staking_epoch_data
        ; next_epoch_data = next_staking_epoch_data
        ; global_slot_since_genesis =
            (* OK if we're in genesis "hard fork" *)
            Global_slot.slot_number curr_global_slot_since_hard_fork
            |> Mina_numbers.Global_slot_since_hard_fork.to_uint32
            |> Mina_numbers.Global_slot_since_genesis.of_uint32
            (* These values are not used in selection, so we just set them to something. *)
        ; has_ancestor_in_same_checkpoint_window = true
        ; block_stake_winner = staker_pk
        ; block_creator = staker_pk
        ; coinbase_receiver = staker_pk
        ; supercharge_coinbase = false
        }

      (** This generator generates pairs of spot blocks that share common checkpoints.
         *  The overlap of the checkpoints and the root epoch positions of the blocks
         *  that are generated can be configured independently so that this function
         *  can be used in other generators that wish to generates pairs of spot blocks
         *  with specific constraints.
         *)
      let gen_spot_pair_common_checkpoints ?blockchain_length_relativity
          ?vrf_output_relativity ~a_checkpoints ~b_checkpoints
          ?(gen_a_root_epoch_position = Quickcheck.Generator.return)
          ?(gen_b_root_epoch_position = Quickcheck.Generator.return)
          ?(min_a_curr_epoch_slot = 0) () =
        let open Quickcheck.Generator.Let_syntax in
        let slot_fill_rate = default_slot_fill_rate in
        let slot_fill_rate_delta = default_slot_fill_rate_delta in
        (* Both states will share the same root epoch position. *)
        let%bind base_root_epoch_position =
          gen_spot_root_epoch_position ~slot_fill_rate:default_slot_fill_rate
            ~slot_fill_rate_delta:default_slot_fill_rate_delta
        in
        (* Generate unique state hashes. *)
        let%bind hashes =
          gen_unique_list 2 ~gen:State_hash.gen ~equal:State_hash.equal
        in
        let[@warning "-8"] [ hash_a; hash_b ] = hashes in
        (* Generate common checkpoints. *)
        let%bind checkpoints =
          gen_unique_list 2 ~gen:State_hash.gen ~equal:State_hash.equal
        in
        let[@warning "-8"] [ start_checkpoint; lock_checkpoint ] =
          checkpoints
        in
        let%bind a, a_curr_epoch_length =
          (* If we are constraining the second state to have a greater blockchain length than the
           * first, we need to constrain the first blockchain length such that there is some room
           * leftover in the epoch for at least 1 more block to be generated. *)
          let gen_curr_epoch_position =
            let max_epoch_slot =
              match blockchain_length_relativity with
              | Some `Ascending ->
                  Length.to_int constants.slots_per_epoch - 4
              (* -1 to bring into inclusive range, -3 to provide 2 slots of fudge room *)
              | _ ->
                  Length.to_int constants.slots_per_epoch - 1
              (* -1 to bring into inclusive range *)
            in
            let%bind slot =
              Core.Int.gen_incl min_a_curr_epoch_slot max_epoch_slot
            in
            let%map length =
              gen_num_blocks_in_slots ~slot_fill_rate ~slot_fill_rate_delta slot
            in
            (Length.of_int slot, length)
          in
          let ( staking_start_checkpoint
              , staking_lock_checkpoint
              , next_start_checkpoint
              , next_lock_checkpoint ) =
            a_checkpoints start_checkpoint lock_checkpoint
          in
          let%bind root_epoch_position =
            gen_a_root_epoch_position base_root_epoch_position
          in
          let%map a =
            gen_spot ~slot_fill_rate ~slot_fill_rate_delta ~root_epoch_position
              ?staking_start_checkpoint ?staking_lock_checkpoint
              ?next_start_checkpoint ?next_lock_checkpoint
              ~gen_curr_epoch_position ()
          in
          let a_curr_epoch_length =
            let _, root_epoch_length = root_epoch_position in
            let length_till_curr_epoch =
              sum_lengths
                [ root_epoch_length
                ; a.staking_epoch_data.epoch_length
                ; a.next_epoch_data.epoch_length
                ]
            in
            Option.value_exn
              (Length.sub a.blockchain_length length_till_curr_epoch)
          in
          (a, a_curr_epoch_length)
        in
        let%map b =
          (* Handle relativity constriants for second state. *)
          let ( gen_staking_epoch_length
              , gen_next_epoch_length
              , gen_curr_epoch_position ) =
            let a_curr_epoch_slot =
              Global_slot.slot a.curr_global_slot_since_hard_fork
            in
            match blockchain_length_relativity with
            | Some `Equal ->
                ( Some (return a.staking_epoch_data.epoch_length)
                , Some (return a.next_epoch_data.epoch_length)
                , Some (return (a_curr_epoch_slot, a_curr_epoch_length)) )
            | Some `Ascending ->
                (* Generate second state position by extending the first state's position *)
                let gen_greater_position =
                  let max_epoch_slot =
                    Length.to_int constants.slots_per_epoch - 1
                  in
                  (* This invariant needs to be held for the position of `a` *)
                  assert (max_epoch_slot > Length.to_int a_curr_epoch_slot + 2) ;
                  (* To make this easier, we assume there is a next block in the slot directly preceeding the block for `a`. *)
                  let%bind added_slots =
                    Core.Int.gen_incl
                      (Length.to_int a_curr_epoch_slot + 2)
                      max_epoch_slot
                  in
                  let%map added_blocks =
                    gen_num_blocks_in_slots ~slot_fill_rate
                      ~slot_fill_rate_delta added_slots
                  in
                  let b_slot =
                    Length.add
                      (Length.add a_curr_epoch_slot (UInt32.of_int added_slots))
                      UInt32.one
                  in
                  let b_blockchain_length =
                    Length.add
                      (Length.add a_curr_epoch_length added_blocks)
                      UInt32.one
                  in
                  (b_slot, b_blockchain_length)
                in
                ( Some (return a.staking_epoch_data.epoch_length)
                , Some (return a.next_epoch_data.epoch_length)
                , Some gen_greater_position )
            | None ->
                (None, None, None)
          in
          let gen_vrf_output =
            match vrf_output_relativity with
            | Some `Equal ->
                Some (return a.last_vrf_output)
            | Some `Ascending ->
                Some (gen_vrf_output_gt a.last_vrf_output)
            | None ->
                None
          in
          let ( staking_start_checkpoint
              , staking_lock_checkpoint
              , next_start_checkpoint
              , next_lock_checkpoint ) =
            b_checkpoints start_checkpoint lock_checkpoint
          in
          let%bind root_epoch_position =
            gen_b_root_epoch_position base_root_epoch_position
          in
          gen_spot ~slot_fill_rate ~slot_fill_rate_delta ~root_epoch_position
            ?staking_start_checkpoint ?staking_lock_checkpoint
            ?next_start_checkpoint ?next_lock_checkpoint
            ?gen_staking_epoch_length ?gen_next_epoch_length
            ?gen_curr_epoch_position ?gen_vrf_output ()
        in
        ( With_hash.
            { data = a
            ; hash =
                { State_hash.State_hashes.state_hash = hash_a
                ; state_body_hash = None
                }
            }
        , With_hash.
            { data = b
            ; hash =
                { State_hash.State_hashes.state_hash = hash_b
                ; state_body_hash = None
                }
            } )

      let gen_spot_pair_short_aligned ?blockchain_length_relativity
          ?vrf_output_relativity () =
        (* Both states will share their staking epoch checkpoints. *)
        let checkpoints start lock = (Some start, Some lock, None, None) in
        gen_spot_pair_common_checkpoints ?blockchain_length_relativity
          ?vrf_output_relativity ~a_checkpoints:checkpoints
          ~b_checkpoints:checkpoints ()

      let gen_spot_pair_short_misaligned ?blockchain_length_relativity
          ?vrf_output_relativity () =
        let open Quickcheck.Generator.Let_syntax in
        let slot_fill_rate = default_slot_fill_rate in
        let slot_fill_rate_delta = default_slot_fill_rate_delta in
        let a_checkpoints start lock = (None, None, Some start, Some lock) in
        let b_checkpoints start lock = (Some start, Some lock, None, None) in
        let gen_b_root_epoch_position (a_root_epoch, a_root_length) =
          (* Compute the root epoch position of `b`. This needs to be one epoch ahead of a, so we
           * compute it by extending the root epoch position of `a` by a single epoch *)
          let b_root_epoch = UInt32.succ a_root_epoch in
          let%map added_blocks =
            gen_num_blocks_in_epochs ~slot_fill_rate ~slot_fill_rate_delta 1
          in
          let b_root_length = Length.add a_root_length added_blocks in
          (b_root_epoch, b_root_length)
        in
        (* Constrain first state to be within last 1/3rd of its epoch (ensuring it's checkpoints and seed are fixed). *)
        let min_a_curr_epoch_slot =
          (2 * (Length.to_int constants.slots_per_epoch / 3)) + 1
        in
        gen_spot_pair_common_checkpoints ?blockchain_length_relativity
          ?vrf_output_relativity ~a_checkpoints ~b_checkpoints
          ~gen_b_root_epoch_position ~min_a_curr_epoch_slot ()

      let gen_spot_pair_long =
        let open Quickcheck.Generator.Let_syntax in
        let%bind hashes =
          gen_unique_list 2 ~gen:State_hash.gen ~equal:State_hash.equal
        in
        let[@warning "-8"] [ hash_a; hash_b ] = hashes in
        let%bind checkpoints =
          gen_unique_list 8 ~gen:State_hash.gen ~equal:State_hash.equal
        in
        let[@warning "-8"] [ a_staking_start_checkpoint
                           ; a_staking_lock_checkpoint
                           ; a_next_start_checkpoint
                           ; a_next_lock_checkpoint
                           ; b_staking_start_checkpoint
                           ; b_staking_lock_checkpoint
                           ; b_next_start_checkpoint
                           ; b_next_lock_checkpoint
                           ] =
          checkpoints
        in
        let%bind a =
          gen_spot ~staking_start_checkpoint:a_staking_start_checkpoint
            ~staking_lock_checkpoint:a_staking_lock_checkpoint
            ~next_start_checkpoint:a_next_start_checkpoint
            ~next_lock_checkpoint:a_next_lock_checkpoint ()
        in
        let%map b =
          gen_spot ~staking_start_checkpoint:b_staking_start_checkpoint
            ~staking_lock_checkpoint:b_staking_lock_checkpoint
            ~next_start_checkpoint:b_next_start_checkpoint
            ~next_lock_checkpoint:b_next_lock_checkpoint ()
        in
        ( With_hash.
            { data = a
            ; hash =
                { State_hash.State_hashes.state_hash = hash_a
                ; state_body_hash = None
                }
            }
        , With_hash.
            { data = b
            ; hash =
                { State_hash.State_hashes.state_hash = hash_b
                ; state_body_hash = None
                }
            } )

      let gen_spot_pair =
        let open Quickcheck.Generator.Let_syntax in
        let%bind a, b =
          match%bind
            Quickcheck.Generator.of_list
              [ `Short_aligned; `Short_misaligned; `Long ]
          with
          | `Short_aligned ->
              gen_spot_pair_short_aligned ()
          | `Short_misaligned ->
              gen_spot_pair_short_misaligned ()
          | `Long ->
              gen_spot_pair_long
        in
        if%map Quickcheck.Generator.bool then (a, b) else (b, a)

      let assert_consensus_state_set (type t) (set : t) ~project ~assertion ~f =
        (* TODO: make output prettier *)
        if not (f set) then
          let indent_size = 2 in
          let indent = String.init indent_size ~f:(Fn.const ' ') in
          let indented_json state =
            state |> Consensus_state.Value.to_yojson
            |> Yojson.Safe.pretty_to_string |> String.split ~on:'\n'
            |> String.concat ~sep:(indent ^ "\n")
          in
          let message =
            let comparison_sep = Printf.sprintf "\n%svs\n" indent in
            let comparison =
              set |> project |> List.map ~f:indented_json
              |> String.concat ~sep:comparison_sep
            in
            Printf.sprintf "Expected pair of consensus states to be %s:\n%s"
              assertion comparison
          in
          raise (Failure message)

      let assert_consensus_state_pair =
        assert_consensus_state_set ~project:(fun (a, b) -> [ a; b ])

      let assert_hashed_consensus_state_pair =
        assert_consensus_state_set ~project:(fun (a, b) ->
            [ With_hash.data a; With_hash.data b ] )

      let assert_hashed_consensus_state_triple =
        assert_consensus_state_set ~project:(fun (a, b, c) ->
            [ With_hash.data a; With_hash.data b; With_hash.data c ] )

      let is_selected (a, b) =
        Hooks.equal_select_status `Take
          (Hooks.select ~context:(module Context) ~existing:a ~candidate:b)

      let is_not_selected (a, b) =
        Hooks.equal_select_status `Keep
          (Hooks.select ~context:(module Context) ~existing:a ~candidate:b)

      let assert_selected =
        assert_hashed_consensus_state_pair ~assertion:"trigger selection"
          ~f:is_selected

      let assert_not_selected =
        assert_hashed_consensus_state_pair ~assertion:"do not trigger selection"
          ~f:is_not_selected

      let%test_unit "generator sanity check: equal states are always in short \
                     fork range" =
        let constants = Lazy.force Constants.for_unit_tests in
        Quickcheck.test (gen_spot ()) ~f:(fun state ->
            assert_consensus_state_pair (state, state)
              ~assertion:"within long range" ~f:(fun (a, b) ->
                Hooks.is_short_range a b ~constants ) )

      let%test_unit "generator sanity check: gen_spot_pair_short_aligned \
                     always generates pairs of states in short fork range" =
        let constants = Lazy.force Constants.for_unit_tests in
        Quickcheck.test (gen_spot_pair_short_aligned ()) ~f:(fun (a, b) ->
            assert_consensus_state_pair
              (With_hash.data a, With_hash.data b)
              ~assertion:"within short range"
              ~f:(fun (a, b) -> Hooks.is_short_range a b ~constants) )

      let%test_unit "generator sanity check: gen_spot_pair_short_misaligned \
                     always generates pairs of states in short fork range" =
        let constants = Lazy.force Constants.for_unit_tests in
        Quickcheck.test (gen_spot_pair_short_misaligned ()) ~f:(fun (a, b) ->
            assert_consensus_state_pair
              (With_hash.data a, With_hash.data b)
              ~assertion:"within short range"
              ~f:(fun (a, b) -> Hooks.is_short_range a b ~constants) )

      let%test_unit "generator sanity check: gen_spot_pair_long always \
                     generates pairs of states in long fork range" =
        let constants = Lazy.force Constants.for_unit_tests in
        Quickcheck.test gen_spot_pair_long ~f:(fun (a, b) ->
            assert_consensus_state_pair
              (With_hash.data a, With_hash.data b)
              ~assertion:"within long range"
              ~f:(fun (a, b) -> not (Hooks.is_short_range ~constants a b)) )

      let%test_unit "selection case: equal states" =
        Quickcheck.test
          (Quickcheck.Generator.tuple2 State_hash.gen (gen_spot ()))
          ~f:(fun (hash, state) ->
            let hashed_state =
              { With_hash.data = state
              ; hash =
                  { State_hash.State_hashes.state_hash = hash
                  ; state_body_hash = None
                  }
              }
            in
            assert_not_selected (hashed_state, hashed_state) )

      let%test_unit "selection case: aligned checkpoints & different lengths" =
        Quickcheck.test
          (gen_spot_pair_short_aligned ~blockchain_length_relativity:`Ascending
             () )
          ~f:assert_selected

      let%test_unit "selection case: aligned checkpoints & equal lengths & \
                     different vrfs" =
        Quickcheck.test
          (gen_spot_pair_short_aligned ~blockchain_length_relativity:`Equal
             ~vrf_output_relativity:`Ascending () )
          ~f:assert_selected

      let%test_unit "selection case: aligned checkpoints & equal lengths & \
                     equal vrfs & different hashes" =
        Quickcheck.test
          (gen_spot_pair_short_aligned ~blockchain_length_relativity:`Equal
             ~vrf_output_relativity:`Equal () )
          ~f:(fun (a, b) ->
            if
              State_hash.(
                With_state_hashes.state_hash b > With_state_hashes.state_hash a)
            then assert_selected (a, b)
            else assert_selected (b, a) )

      let%test_unit "selection case: misaligned checkpoints & different lengths"
          =
        Quickcheck.test
          (gen_spot_pair_short_misaligned
             ~blockchain_length_relativity:`Ascending () )
          ~f:assert_selected

      (* TODO: This test always succeeds, but this could be a false positive as the blockchain length equality constraint
       * is broken for misaligned short forks.
       *)
      let%test_unit "selection case: misaligned checkpoints & equal lengths & \
                     different vrfs" =
        Quickcheck.test
          (gen_spot_pair_short_misaligned ~blockchain_length_relativity:`Equal
             ~vrf_output_relativity:`Ascending () )
          ~f:assert_selected

      (* TODO: This test fails because the blockchain length equality constraint is broken for misaligned short forks.
         let%test_unit "selection case: misaligned checkpoints & equal lengths & equal vrfs & different hashes" =
         Quickcheck.test
         (gen_spot_pair_short_misaligned ~blockchain_length_relativity:`Equal ~vrf_output_relativity:`Equal ())
         ~f:(fun (a, b) ->
         if State_hash.compare (With_hash.hash a) (With_hash.hash b) > 0 then
         assert_selected (a, b)
         else
         assert_selected (b, a))
      *)

      (* TODO: expand long fork generation to support relativity constraints
         let%test_unit "selection case: distinct checkpoints & different min window densities" =
         failwith "TODO"

         let%test_unit "selection case: distinct checkpoints & equal min window densities & different lengths" =
         failwith "TODO"

         let%test_unit "selection case: distinct checkpoints & equal min window densities & equal lengths & different vrfs" =
         failwith "TODO"

         let%test_unit "selection case: distinct checkpoints & equal min window densities & equal lengths & qequals vrfs & different hashes" =
         failwith "TODO"
      *)

      let%test_unit "selection invariant: candidate selections are not \
                     commutative" =
        let select existing candidate =
          Hooks.select ~context:(module Context) ~existing ~candidate
        in
        Quickcheck.test gen_spot_pair
          ~f:
            (assert_hashed_consensus_state_pair
               ~assertion:"chains do not trigger a selection cycle"
               ~f:(fun (a, b) ->
                 not
                   ([%equal: Hooks.select_status * Hooks.select_status]
                      (select a b, select b a)
                      (`Take, `Take) ) ) )

      (* We define a homogeneous binary relation for consensus states by adapting the binary chain
       * selection rule and extending it to consider equality of chains. From this, we can test
       * that this extended relations forms a non-strict partial order over the set of consensus
       * states.
       *
       * We omit partial order reflexivity and antisymmetry tests as they are merely testing properties
       * of equality related to the partial order we define from binary chain selection. Chain
       * selection, as is written, will always reject equal elements, so the only property we are
       * truly interested in it holding is transitivity (when lifted to a homogeneous binary relation).
       *
       * TODO: Improved quickcheck generator which better explores related states via our spot
       * pair generation rules. Doing this requires re-working our spot pair generators to
       * work by extending an already generated consensus state with some relative constraints.
       *)
      let%test_unit "selection invariant: partial order transitivity" =
        let select existing candidate =
          Hooks.select ~context:(module Context) ~existing ~candidate
        in
        let ( <= ) a b =
          match (select a b, select b a) with
          | `Keep, `Keep ->
              true
          | `Keep, `Take ->
              true
          | `Take, `Keep ->
              false
          | `Take, `Take ->
              assert_hashed_consensus_state_pair (a, b)
                ~assertion:"chains do not trigger a selection cycle"
                ~f:(Fn.const false) ;
              (* unreachable *)
              false
        in
        let chains_hold_transitivity (a, b, c) =
          if a <= b then if b <= c then a <= c else c <= b
          else if b <= c then if c <= a then b <= a else a <= c
          else if c <= a then if a <= b then c <= b else b <= a
          else false
        in
        let gen = gen_with_hash (gen_spot ()) in
        Quickcheck.test
          (Quickcheck.Generator.tuple3 gen gen gen)
          ~f:
            (assert_hashed_consensus_state_triple
               ~assertion:"chains hold partial order transitivity"
               ~f:chains_hold_transitivity )
    end )

  module Exported = struct
    module Global_slot = Global_slot
    module Block_data = Data.Block_data
    module Consensus_state = Data.Consensus_state
  end

  module Body_reference = Body_reference
end

include Wire_types.Make (Make_sig) (Make_str)
