(** A pool of transactions that can be included in future blocks. Combined with
    the Network_pool module, this handles storing and gossiping the correct
    transactions (user commands) and providing them to the block producer code.
*)

(* Only show stdout for failed inline tests.*)
open Inline_test_quiet_logs
open Core
open Async
open Mina_base
open Mina_transaction
open Pipe_lib
open Network_peer

let max_per_15_seconds = 10

(* TEMP HACK UNTIL DEFUNCTORING: transition frontier interface is simplified *)
module type Transition_frontier_intf = sig
  type t

  type staged_ledger

  module Breadcrumb : sig
    type t

    val staged_ledger : t -> staged_ledger
  end

  type best_tip_diff =
    { new_commands : User_command.Valid.t With_status.t list
    ; removed_commands : User_command.Valid.t With_status.t list
    ; reorg_best_tip : bool
    }

  val best_tip : t -> Breadcrumb.t

  val best_tip_diff_pipe : t -> best_tip_diff Broadcast_pipe.Reader.t
end

(* versioned type, outside of functors *)
module Diff_versioned = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = User_command.Stable.V2.t list [@@deriving sexp, yojson, hash]

      let to_latest = Fn.id
    end
  end]

  (* We defer do any checking on signed-commands until the call to
     [add_from_gossip_gossip_exn].

     The real solution would be to have more explicit queueing to make sure things don't happen out of order, factor
     [add_from_gossip_gossip_exn] into [check_from_gossip_exn] (which just does
     the checks) and [set_from_gossip_exn] (which just does the mutating the pool),
     and do the same for snapp commands as well.
  *)
  type t = User_command.t list [@@deriving sexp, yojson]

  module Diff_error = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V2 = struct
        type t =
          | Insufficient_replace_fee
          | Duplicate
          | Invalid_nonce
          | Insufficient_funds
          | Overflow
          | Bad_token
          | Unwanted_fee_token
          | Expired
          | Overloaded
          | Fee_payer_account_not_found
          | Fee_payer_not_permitted_to_send
        [@@deriving sexp, yojson, compare]

        let to_latest = Fn.id
      end
    end]

    (* IMPORTANT! Do not change the names of these errors as to adjust the
     * to_yojson output without updating Rosetta's construction API to handle
     * the changes *)
    type t = Stable.Latest.t =
      | Insufficient_replace_fee
      | Duplicate
      | Invalid_nonce
      | Insufficient_funds
      | Overflow
      | Bad_token
      | Unwanted_fee_token
      | Expired
      | Overloaded
      | Fee_payer_account_not_found
      | Fee_payer_not_permitted_to_send
    [@@deriving sexp, yojson]

    let to_string_name = function
      | Insufficient_replace_fee ->
          "insufficient_replace_fee"
      | Duplicate ->
          "duplicate"
      | Invalid_nonce ->
          "invalid_nonce"
      | Insufficient_funds ->
          "insufficient_funds"
      | Overflow ->
          "overflow"
      | Bad_token ->
          "bad_token"
      | Unwanted_fee_token ->
          "unwanted_fee_token"
      | Expired ->
          "expired"
      | Overloaded ->
          "overloaded"
      | Fee_payer_account_not_found ->
          "fee_payer_account_not_found"
      | Fee_payer_not_permitted_to_send ->
          "fee_payer_not_permitted_to_send"

    let to_string_hum = function
      | Insufficient_replace_fee ->
          "This transaction would have replaced an existing transaction in the \
           pool, but the fee was too low"
      | Duplicate ->
          "This transaction is a duplicate of one already in the pool"
      | Invalid_nonce ->
          "This transaction had an invalid nonce"
      | Insufficient_funds ->
          "There are not enough funds in the fee-payer's account to execute \
           this transaction"
      | Overflow ->
          "Executing this transaction would result in an integer overflow"
      | Bad_token ->
          "This transaction uses non-default tokens where they are not \
           permitted"
      | Unwanted_fee_token ->
          "This transaction pays fees in a non-default token that this pool \
           does not accept"
      | Expired ->
          "This transaction has expired"
      | Overloaded ->
          "The diff containing this transaction was too large"
      | Fee_payer_account_not_found ->
          "Fee payer account was not found in the best tip ledger"
      | Fee_payer_not_permitted_to_send ->
          "Fee payer account permissions don't allow sending funds"
  end

  module Rejected = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V3 = struct
        type t = (User_command.Stable.V2.t * Diff_error.Stable.V2.t) list
        [@@deriving sexp, yojson, compare]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, yojson, compare]
  end

  type rejected = Rejected.t [@@deriving sexp, yojson, compare]

  type verified = Transaction_hash.User_command_with_valid_signature.t list
  [@@deriving sexp, to_yojson]

  let summary t = Printf.sprintf "Transaction diff of length %d" (List.length t)

  let is_empty t = List.is_empty t
end

type Structured_log_events.t +=
  | Rejecting_command_for_reason of
      { command : User_command.t
      ; reason : Diff_versioned.Diff_error.t
      ; error_extra : (string * Yojson.Safe.t) list
      }
  [@@deriving register_event { msg = "Rejecting command because: $reason" }]

module type S = sig
  open Intf

  type transition_frontier

  module Resource_pool : sig
    include
      Transaction_resource_pool_intf
        with type transition_frontier := transition_frontier

    module Diff :
      Transaction_pool_diff_intf
        with type resource_pool := t
         and type Diff_error.t = Diff_versioned.Diff_error.t
         and type Rejected.t = Diff_versioned.Rejected.t
  end

  include
    Network_pool_base_intf
      with type resource_pool := Resource_pool.t
       and type transition_frontier := transition_frontier
       and type resource_pool_diff := Diff_versioned.t
       and type resource_pool_diff_verified := Diff_versioned.verified
       and type config := Resource_pool.Config.t
       and type transition_frontier_diff :=
        Resource_pool.transition_frontier_diff
       and type rejected_diff := Diff_versioned.rejected
end

(* Functor over user command, base ledger and transaction validator for
   mocking. *)
module Make0
    (Base_ledger : Intf.Base_ledger_intf) (Staged_ledger : sig
      type t

      val ledger : t -> Base_ledger.t
    end)
    (Transition_frontier : Transition_frontier_intf
                             with type staged_ledger := Staged_ledger.t) =
struct
  type verification_failure =
    | Command_failure of Diff_versioned.Diff_error.t
    | Invalid_failure of Verifier.invalid
  [@@deriving to_yojson]

  module Breadcrumb = Transition_frontier.Breadcrumb

  module Resource_pool = struct
    type transition_frontier_diff =
      Transition_frontier.best_tip_diff * Base_ledger.t

    let label = "transaction_pool"

    let preload_accounts ledger account_ids =
      let existing_account_ids, existing_account_locs =
        Set.to_list account_ids
        |> Base_ledger.location_of_account_batch ledger
        |> List.filter_map ~f:(function
             | id, Some loc ->
                 Some (id, loc)
             | _, None ->
                 None )
        |> List.unzip
      in
      Base_ledger.get_batch ledger existing_account_locs
      |> List.map ~f:snd
      |> List.zip_exn existing_account_ids
      |> List.fold ~init:Account_id.Map.empty ~f:(fun map (id, maybe_account) ->
             let account =
               Option.value_exn maybe_account
                 ~message:"Somehow a public key has a location but no account"
             in
             Map.add_exn map ~key:id ~data:account )

    module Config = struct
      type t =
        { trust_system : (Trust_system.t[@sexp.opaque])
        ; pool_max_size : int
              (* note this value needs to be mostly the same across gossipping nodes, so
                 nodes with larger pools don't send nodes with smaller pools lots of
                 low fee transactions the smaller-pooled nodes consider useless and get
                 themselves banned.

                 we offer this value separately from the one in genesis_constants, because
                 we may wish a different value for testing
              *)
        ; verifier : (Verifier.t[@sexp.opaque])
        ; genesis_constants : Genesis_constants.t
        }
      [@@deriving sexp_of, make]
    end

    let make_config = Config.make

    module Batcher = Batcher.Transaction_pool

    module Lru_cache = struct
      let max_size = 2048

      module T = struct
        type t = User_command.t list [@@deriving hash]
      end

      module Q = Hash_queue.Make (Int)

      type t = unit Q.t

      let add t h =
        if not (Q.mem t h) then (
          if Q.length t >= max_size then ignore (Q.dequeue_front t : 'a option) ;
          Q.enqueue_back_exn t h () ;
          `Already_mem false )
        else (
          ignore (Q.lookup_and_move_to_back t h : unit option) ;
          `Already_mem true )
    end

    module Mutex = struct
      open Async

      type t = unit Mvar.Read_write.t

      let acquire (t : t) = Mvar.take t

      let release (t : t) =
        assert (Mvar.is_empty t) ;
        don't_wait_for (Mvar.put t ())

      let with_ t ~f =
        let%bind () = acquire t in
        let%map x = f () in
        release t ; x

      let create () =
        let t = Mvar.create () in
        don't_wait_for (Mvar.put t ()) ;
        t
    end

    type t =
      { mutable pool : Indexed_pool.t
      ; recently_seen : (Lru_cache.t[@sexp.opaque])
      ; locally_generated_uncommitted :
          ( Transaction_hash.User_command_with_valid_signature.t
          , Time.t * [ `Batch of int ] )
          Hashtbl.t
            (** Commands generated on this machine, that are not included in the
                current best tip, along with the time they were added. *)
      ; locally_generated_committed :
          ( Transaction_hash.User_command_with_valid_signature.t
          , Time.t * [ `Batch of int ] )
          Hashtbl.t
            (** Ones that are included in the current best tip. *)
      ; mutable current_batch : int
      ; mutable remaining_in_batch : int
      ; config : Config.t
      ; logger : (Logger.t[@sexp.opaque])
      ; batcher : Batcher.t
      ; mutable best_tip_diff_relay : (unit Deferred.t[@sexp.opaque]) Option.t
      ; mutable best_tip_ledger : (Base_ledger.t[@sexp.opaque]) Option.t
      }
    [@@deriving sexp_of]

    let member t x =
      Indexed_pool.member t.pool (Transaction_hash.User_command.of_checked x)

    let transactions t = Indexed_pool.transactions ~logger:t.logger t.pool

    let all_from_account { pool; _ } = Indexed_pool.all_from_account pool

    let get_all { pool; _ } = Indexed_pool.get_all pool

    let find_by_hash x hash = Indexed_pool.find_by_hash x.pool hash

    (** Get the best tip ledger*)
    let get_best_tip_ledger frontier =
      Transition_frontier.best_tip frontier
      |> Breadcrumb.staged_ledger |> Staged_ledger.ledger

    let drop_until_below_max_size :
           pool_max_size:int
        -> Indexed_pool.t
        -> Indexed_pool.t
           * Transaction_hash.User_command_with_valid_signature.t Sequence.t =
     fun ~pool_max_size pool ->
      let rec go pool' dropped =
        if Indexed_pool.size pool' > pool_max_size then (
          let dropped', pool'' = Indexed_pool.remove_lowest_fee pool' in
          assert (not (Sequence.is_empty dropped')) ;
          go pool'' @@ Sequence.append dropped dropped' )
        else (pool', dropped)
      in
      go pool @@ Sequence.empty

    let has_sufficient_fee ~pool_max_size pool cmd : bool =
      match Indexed_pool.min_fee pool with
      | None ->
          true
      | Some min_fee ->
          if Indexed_pool.size pool >= pool_max_size then
            Currency.Fee_rate.(User_command.fee_per_wu cmd > min_fee)
          else true

    let diff_error_of_indexed_pool_error :
        Indexed_pool.Command_error.t -> Diff_versioned.Diff_error.t = function
      | Invalid_nonce _ ->
          Invalid_nonce
      | Insufficient_funds _ ->
          Insufficient_funds
      | Insufficient_replace_fee _ ->
          Insufficient_replace_fee
      | Overflow ->
          Overflow
      | Bad_token ->
          Bad_token
      | Unwanted_fee_token _ ->
          Unwanted_fee_token
      | Expired _ ->
          Expired

    let indexed_pool_error_metadata = function
      | Indexed_pool.Command_error.Invalid_nonce (`Between (low, hi), nonce) ->
          let nonce_json = Account.Nonce.to_yojson in
          [ ( "between"
            , `Assoc [ ("low", nonce_json low); ("hi", nonce_json hi) ] )
          ; ("nonce", nonce_json nonce)
          ]
      | Invalid_nonce (`Expected enonce, nonce) ->
          let nonce_json = Account.Nonce.to_yojson in
          [ ("expected_nonce", nonce_json enonce); ("nonce", nonce_json nonce) ]
      | Insufficient_funds (`Balance bal, amt) ->
          let amt_json = Currency.Amount.to_yojson in

          [ ("balance", amt_json bal); ("amount", amt_json amt) ]
      | Insufficient_replace_fee (`Replace_fee rfee, fee) ->
          let fee_json = Currency.Fee.to_yojson in
          [ ("replace_fee", fee_json rfee); ("fee", fee_json fee) ]
      | Overflow ->
          []
      | Bad_token ->
          []
      | Unwanted_fee_token fee_token ->
          [ ("fee_token", Token_id.to_yojson fee_token) ]
      | Expired
          ( `Valid_until valid_until
          , `Global_slot_since_genesis global_slot_since_genesis ) ->
          [ ("valid_until", Mina_numbers.Global_slot.to_yojson valid_until)
          ; ( "current_global_slot"
            , Mina_numbers.Global_slot.to_yojson global_slot_since_genesis )
          ]
      | Expired
          ( `Timestamp_predicate expiry_ns
          , `Global_slot_since_genesis global_slot_since_genesis ) ->
          [ ("expiry_ns", `String expiry_ns)
          ; ( "current_global_slot"
            , Mina_numbers.Global_slot.to_yojson global_slot_since_genesis )
          ]

    let indexed_pool_error_log_info e =
      ( Diff_versioned.Diff_error.to_string_name
          (diff_error_of_indexed_pool_error e)
      , indexed_pool_error_metadata e )

    let handle_transition_frontier_diff
        ( ({ new_commands; removed_commands; reorg_best_tip = _ } :
            Transition_frontier.best_tip_diff )
        , best_tip_ledger ) t =
      (* This runs whenever the best tip changes. The simple case is when the
         new best tip is an extension of the old one. There, we just remove any
         user commands that were included in it from the transaction pool.
         Dealing with a fork is more intricate. In general we want to remove any
         commands from the pool that are included in the new best tip; and add
         any commands to the pool that were included in the old one but not the
         new one, provided they are still valid against the ledger of the best
         tip. The goal is that transactions are carried from losing forks to
         winning ones as much as possible.

         The locally generated commands need to move from
         locally_generated_uncommitted to locally_generated_committed and vice
         versa so those hashtables remain in sync with reality.
      *)
      let global_slot = Indexed_pool.global_slot_since_genesis t.pool in
      t.best_tip_ledger <- Some best_tip_ledger ;
      let pool_max_size = t.config.pool_max_size in
      let log_indexed_pool_error error_str ~metadata cmd =
        [%log' debug t.logger]
          "Couldn't re-add locally generated command $cmd, not valid against \
           new ledger. Error: $error"
          ~metadata:
            ( [ ( "cmd"
                , Transaction_hash.User_command_with_valid_signature.to_yojson
                    cmd )
              ; ("error", `String error_str)
              ]
            @ metadata )
      in
      [%log' trace t.logger]
        ~metadata:
          [ ( "removed"
            , `List
                (List.map removed_commands
                   ~f:(With_status.to_yojson User_command.Valid.to_yojson) ) )
          ; ( "added"
            , `List
                (List.map new_commands
                   ~f:(With_status.to_yojson User_command.Valid.to_yojson) ) )
          ]
        "Diff: removed: $removed added: $added from best tip" ;
      let pool', dropped_backtrack =
        List.fold (List.rev removed_commands) ~init:(t.pool, Sequence.empty)
          ~f:(fun (pool, dropped_so_far) unhashed_cmd ->
            let cmd =
              Transaction_hash.User_command_with_valid_signature.create
                unhashed_cmd.data
            in
            ( match
                Hashtbl.find_and_remove t.locally_generated_committed cmd
              with
            | None ->
                ()
            | Some time_added ->
                [%log' info t.logger]
                  "Locally generated command $cmd committed in a block!"
                  ~metadata:
                    [ ( "cmd"
                      , With_status.to_yojson User_command.Valid.to_yojson
                          unhashed_cmd )
                    ] ;
                Hashtbl.add_exn t.locally_generated_uncommitted ~key:cmd
                  ~data:time_added ) ;
            let pool', dropped_seq =
              match cmd |> Indexed_pool.add_from_backtrack pool with
              | Error e ->
                  let error_str, metadata = indexed_pool_error_log_info e in
                  log_indexed_pool_error error_str ~metadata cmd ;
                  (pool, Sequence.empty)
              | Ok indexed_pool ->
                  drop_until_below_max_size ~pool_max_size indexed_pool
            in
            (pool', Sequence.append dropped_so_far dropped_seq) )
      in
      (* Track what locally generated commands were removed from the pool
         during backtracking due to the max size constraint. *)
      let locally_generated_dropped =
        Sequence.filter dropped_backtrack
          ~f:(Hashtbl.mem t.locally_generated_uncommitted)
        |> Sequence.to_list_rev
      in
      if not (List.is_empty locally_generated_dropped) then
        [%log' debug t.logger]
          "Dropped locally generated commands $cmds during backtracking to \
           maintain max size. Will attempt to re-add after forwardtracking."
          ~metadata:
            [ ( "cmds"
              , `List
                  (List.map
                     ~f:
                       Transaction_hash.User_command_with_valid_signature
                       .to_yojson locally_generated_dropped ) )
            ] ;
      let pool'', dropped_commands =
        let accounts_to_check =
          List.fold (new_commands @ removed_commands) ~init:Account_id.Set.empty
            ~f:(fun set cmd ->
              let set' =
                With_status.data cmd |> User_command.forget_check
                |> User_command.accounts_accessed |> Account_id.Set.of_list
              in
              Set.union set set' )
        in
        let get_account =
          let account_state (account : Account.t) =
            ( account.nonce
            , Currency.Amount.of_uint64
              @@ Currency.Balance.to_uint64 account.balance )
          in
          let empty_state = (Account.Nonce.zero, Currency.Amount.zero) in
          let existing_account_states_by_id =
            preload_accounts best_tip_ledger accounts_to_check
          in
          fun id ->
            match Map.find existing_account_states_by_id id with
            | Some account ->
                account_state account
            | None ->
                if Set.mem accounts_to_check id then empty_state
                else
                  failwith
                    "did not expect Indexed_pool.revalidate to call \
                     get_account on account not in accounts_to_check"
        in
        Indexed_pool.revalidate pool' ~logger:t.logger
          (`Subset accounts_to_check) get_account
      in
      let committed_commands, dropped_commit_conflicts =
        let command_hashes =
          List.fold_left new_commands ~init:Transaction_hash.Set.empty
            ~f:(fun set cmd ->
              let cmd_hash =
                With_status.data cmd
                |> Transaction_hash.User_command_with_valid_signature.create
                |> Transaction_hash.User_command_with_valid_signature.hash
              in
              Set.add set cmd_hash )
        in
        Sequence.to_list dropped_commands
        |> List.partition_tf ~f:(fun cmd ->
               Set.mem command_hashes
                 (Transaction_hash.User_command_with_valid_signature.hash cmd) )
      in
      List.iter committed_commands ~f:(fun cmd ->
          Hashtbl.find_and_remove t.locally_generated_uncommitted cmd
          |> Option.iter ~f:(fun data ->
                 Hashtbl.add_exn t.locally_generated_committed ~key:cmd ~data ) ) ;
      let commit_conflicts_locally_generated =
        List.filter dropped_commit_conflicts ~f:(fun cmd ->
            Hashtbl.find_and_remove t.locally_generated_uncommitted cmd
            |> Option.is_some )
      in
      if not @@ List.is_empty commit_conflicts_locally_generated then
        [%log' info t.logger]
          "Locally generated commands $cmds dropped because they conflicted \
           with a committed command."
          ~metadata:
            [ ( "cmds"
              , `List
                  (List.map commit_conflicts_locally_generated
                     ~f:
                       Transaction_hash.User_command_with_valid_signature
                       .to_yojson ) )
            ] ;
      [%log' debug t.logger]
        !"Finished handling diff. Old pool size %i, new pool size %i. Dropped \
          %i commands during backtracking to maintain max size."
        (Indexed_pool.size t.pool) (Indexed_pool.size pool'')
        (Sequence.length dropped_backtrack) ;
      Mina_metrics.(
        Gauge.set Transaction_pool.pool_size
          (Float.of_int (Indexed_pool.size pool''))) ;
      t.pool <- pool'' ;
      List.iter locally_generated_dropped ~f:(fun cmd ->
          (* If the dropped transaction was included in the winning chain, it'll
             be in locally_generated_committed. If it wasn't, try re-adding to
             the pool. *)
          let remove_cmd () =
            assert (
              Option.is_some
              @@ Hashtbl.find_and_remove t.locally_generated_uncommitted cmd )
          in
          let log_and_remove ?(metadata = []) error_str =
            log_indexed_pool_error error_str ~metadata cmd ;
            remove_cmd ()
          in
          if not (Hashtbl.mem t.locally_generated_committed cmd) then
            if
              not
                (has_sufficient_fee t.pool
                   (Transaction_hash.User_command_with_valid_signature.command
                      cmd )
                   ~pool_max_size )
            then (
              [%log' info t.logger]
                "Not re-adding locally generated command $cmd to pool, \
                 insufficient fee"
                ~metadata:
                  [ ( "cmd"
                    , Transaction_hash.User_command_with_valid_signature
                      .to_yojson cmd )
                  ] ;
              remove_cmd () )
            else
              let unchecked =
                Transaction_hash.User_command_with_valid_signature.command cmd
              in
              match
                Option.bind
                  (Base_ledger.location_of_account best_tip_ledger
                     (User_command.fee_payer unchecked) )
                  ~f:(Base_ledger.get best_tip_ledger)
              with
              | Some acct -> (
                  match
                    Indexed_pool.add_from_gossip_exn t.pool cmd acct.nonce
                      ( Account.liquid_balance_at_slot ~global_slot acct
                      |> Currency.Balance.to_amount )
                  with
                  | Error e ->
                      let error_str, metadata = indexed_pool_error_log_info e in
                      log_and_remove error_str
                        ~metadata:
                          ( ("user_command", User_command.to_yojson unchecked)
                          :: metadata )
                  | Ok (_, pool''', _) ->
                      [%log' debug t.logger]
                        "re-added locally generated command $cmd to \
                         transaction pool after reorg"
                        ~metadata:
                          [ ( "cmd"
                            , Transaction_hash.User_command_with_valid_signature
                              .to_yojson cmd )
                          ] ;
                      Mina_metrics.(
                        Gauge.set Transaction_pool.pool_size
                          (Float.of_int (Indexed_pool.size pool'''))) ;
                      t.pool <- pool''' )
              | None ->
                  log_and_remove "Fee_payer_account not found"
                    ~metadata:
                      [ ("user_command", User_command.to_yojson unchecked) ] ) ;
      (*Remove any expired user commands*)
      let expired_commands, pool = Indexed_pool.remove_expired t.pool in
      Sequence.iter expired_commands ~f:(fun cmd ->
          [%log' debug t.logger]
            "Dropping expired user command from the pool $cmd"
            ~metadata:
              [ ( "cmd"
                , Transaction_hash.User_command_with_valid_signature.to_yojson
                    cmd )
              ] ;
          ignore
            ( Hashtbl.find_and_remove t.locally_generated_uncommitted cmd
              : (Time.t * [ `Batch of int ]) option ) ) ;
      Mina_metrics.(
        Gauge.set Transaction_pool.pool_size
          (Float.of_int (Indexed_pool.size pool))) ;
      t.pool <- pool ;
      Deferred.unit

    let create ~constraint_constants ~consensus_constants ~time_controller
        ~expiry_ns ~frontier_broadcast_pipe ~config ~logger ~tf_diff_writer =
      let t =
        { pool =
            Indexed_pool.empty ~constraint_constants ~consensus_constants
              ~time_controller ~expiry_ns
        ; locally_generated_uncommitted =
            Hashtbl.create
              ( module Transaction_hash.User_command_with_valid_signature.Stable
                       .Latest )
        ; locally_generated_committed =
            Hashtbl.create
              ( module Transaction_hash.User_command_with_valid_signature.Stable
                       .Latest )
        ; current_batch = 0
        ; remaining_in_batch = max_per_15_seconds
        ; config
        ; logger
        ; batcher = Batcher.create config.verifier
        ; best_tip_diff_relay = None
        ; recently_seen = Lru_cache.Q.create ()
        ; best_tip_ledger = None
        }
      in
      don't_wait_for
        (Broadcast_pipe.Reader.iter frontier_broadcast_pipe
           ~f:(fun frontier_opt ->
             match frontier_opt with
             | None -> (
                 [%log debug] "no frontier" ;
                 t.best_tip_ledger <- None ;
                 (* Sanity check: the view pipe should have been closed before
                    the frontier was destroyed. *)
                 match t.best_tip_diff_relay with
                 | None ->
                     Deferred.unit
                 | Some hdl ->
                     let is_finished = ref false in
                     Deferred.any_unit
                       [ (let%map () = hdl in
                          t.best_tip_diff_relay <- None ;
                          is_finished := true )
                       ; (let%map () = Async.after (Time.Span.of_sec 5.) in
                          if not !is_finished then (
                            [%log fatal]
                              "Transition frontier closed without first \
                               closing best tip view pipe" ;
                            assert false )
                          else () )
                       ] )
             | Some frontier ->
                 [%log debug] "Got frontier!" ;
                 let validation_ledger = get_best_tip_ledger frontier in
                 (* update our cache *)
                 t.best_tip_ledger <- Some validation_ledger ;
                 (* The frontier has changed, so transactions in the pool may
                    not be valid against the current best tip. *)
                 let global_slot =
                   Indexed_pool.global_slot_since_genesis t.pool
                 in
                 let new_pool, dropped =
                   Indexed_pool.revalidate t.pool ~logger:t.logger `Entire_pool
                     (fun sender ->
                       match
                         Base_ledger.location_of_account validation_ledger
                           sender
                       with
                       | None ->
                           (Account.Nonce.zero, Currency.Amount.zero)
                       | Some loc ->
                           let acc =
                             Option.value_exn
                               ~message:
                                 "Somehow a public key has a location but no \
                                  account"
                               (Base_ledger.get validation_ledger loc)
                           in
                           ( acc.nonce
                           , Account.liquid_balance_at_slot ~global_slot acc
                             |> Currency.Balance.to_amount ) )
                 in
                 let dropped_locally_generated =
                   Sequence.filter dropped ~f:(fun cmd ->
                       let find_remove_bool tbl =
                         Hashtbl.find_and_remove tbl cmd |> Option.is_some
                       in
                       let dropped_committed =
                         find_remove_bool t.locally_generated_committed
                       in
                       let dropped_uncommitted =
                         find_remove_bool t.locally_generated_uncommitted
                       in
                       (* Nothing should be in both tables. *)
                       assert (not (dropped_committed && dropped_uncommitted)) ;
                       dropped_committed || dropped_uncommitted )
                 in
                 (* In this situation we don't know whether the commands aren't
                    valid against the new ledger because they were already
                    committed or because they conflict with others,
                    unfortunately. *)
                 if not (Sequence.is_empty dropped_locally_generated) then
                   [%log info]
                     "Dropped locally generated commands $cmds from pool when \
                      transition frontier was recreated."
                     ~metadata:
                       [ ( "cmds"
                         , `List
                             (List.map
                                (Sequence.to_list dropped_locally_generated)
                                ~f:
                                  Transaction_hash
                                  .User_command_with_valid_signature
                                  .to_yojson ) )
                       ] ;
                 [%log debug]
                   !"Re-validated transaction pool after restart: dropped %i \
                     of %i previously in pool"
                   (Sequence.length dropped) (Indexed_pool.size t.pool) ;
                 Mina_metrics.(
                   Gauge.set Transaction_pool.pool_size
                     (Float.of_int (Indexed_pool.size new_pool))) ;
                 t.pool <- new_pool ;
                 t.best_tip_diff_relay <-
                   Some
                     (Broadcast_pipe.Reader.iter
                        (Transition_frontier.best_tip_diff_pipe frontier)
                        ~f:(fun diff ->
                          Strict_pipe.Writer.write tf_diff_writer
                            (diff, get_best_tip_ledger frontier)
                          |> Deferred.don't_wait_for ;
                          Deferred.unit ) ) ;
                 Deferred.unit ) ) ;
      t

    type pool = t

    module Diff = struct
      type t = User_command.t list [@@deriving sexp, yojson]

      type _unused = unit constraint t = Diff_versioned.t

      module Diff_error = struct
        type t = Diff_versioned.Diff_error.t =
          (*Indexed_pool*)
          | Insufficient_replace_fee
          (*apply*)
          | Duplicate
          (*Indexed_pool*)
          | Invalid_nonce
          (*Indexed_pool*)
          | Insufficient_funds
          (*Indexed_pool*)
          | Overflow
          (*Indexed_pool*)
          | Bad_token
          (*Indexed_pool*)
          | Unwanted_fee_token
          (*Indexed_pool*)
          | Expired
          (*Sink*)
          | Overloaded
          (*apply*)
          | Fee_payer_account_not_found
          | Fee_payer_not_permitted_to_send
        [@@deriving sexp, yojson, compare]

        let to_string_hum = Diff_versioned.Diff_error.to_string_hum

        let grounds_for_diff_rejection = function
          | Expired
          | Invalid_nonce
          | Insufficient_funds
          | Insufficient_replace_fee
          | Duplicate
          | Overloaded
          | Fee_payer_account_not_found
          | Fee_payer_not_permitted_to_send ->
              false
          | Overflow | Bad_token | Unwanted_fee_token ->
              true
      end

      module Rejected = struct
        type t = (User_command.t * Diff_error.t) list
        [@@deriving sexp, yojson, compare]

        type _unused = unit constraint t = Diff_versioned.Rejected.t
      end

      type rejected = Rejected.t [@@deriving sexp, yojson, compare]

      type verified = Diff_versioned.verified [@@deriving sexp, to_yojson]

      let reject_overloaded_diff (diff : verified) : rejected =
        List.map diff ~f:(fun cmd ->
            ( Transaction_hash.User_command_with_valid_signature.command cmd
            , Diff_error.Overloaded ) )

      let empty = []

      let size = List.length

      let score x = Int.max 1 (List.length x)

      let max_per_15_seconds = max_per_15_seconds

      let summary t =
        Printf.sprintf "Transaction diff of length %d" (List.length t)

      let is_empty t = List.is_empty t

      let log_and_punish ?(punish = true) t d e =
        let sender = Envelope.Incoming.sender d in
        let trust_record =
          Trust_system.record_envelope_sender t.config.trust_system t.logger
            sender
        in
        let is_local = Envelope.Sender.(equal Local sender) in
        let metadata =
          [ ("error", Error_json.error_to_yojson e)
          ; ("sender", Envelope.Sender.to_yojson sender)
          ]
        in
        [%log' error t.logger] ~metadata
          "Error verifying transaction pool diff from $sender: $error" ;
        if punish && not is_local then
          (* TODO: Make this error more specific (could also be a bad signature). *)
          trust_record
            ( Trust_system.Actions.Sent_invalid_proof
            , Some ("Error verifying transaction pool diff: $error", metadata)
            )
        else Deferred.return ()

      let of_indexed_pool_error e =
        (diff_error_of_indexed_pool_error e, indexed_pool_error_metadata e)

      let report_command_error ~logger ~is_sender_local tx
          (e : Indexed_pool.Command_error.t) =
        let diff_err, error_extra = of_indexed_pool_error e in
        if is_sender_local then
          [%str_log error]
            (Rejecting_command_for_reason
               { command = tx; reason = diff_err; error_extra } ) ;
        let log = if is_sender_local then [%log error] else [%log debug] in
        match e with
        | Insufficient_replace_fee (`Replace_fee rfee, fee) ->
            log
              "rejecting $cmd because of insufficient replace fee ($rfee > \
               $fee)"
              ~metadata:
                [ ("cmd", User_command.to_yojson tx)
                ; ("rfee", Currency.Fee.to_yojson rfee)
                ; ("fee", Currency.Fee.to_yojson fee)
                ]
        | Unwanted_fee_token fee_token ->
            log "rejecting $cmd because we don't accept fees in $token"
              ~metadata:
                [ ("cmd", User_command.to_yojson tx)
                ; ("token", Token_id.to_yojson fee_token)
                ]
        | _ ->
            ()

      let verify (t : pool) (diff : t Envelope.Incoming.t) :
          verified Envelope.Incoming.t Deferred.Or_error.t =
        let open Deferred.Or_error.Let_syntax in
        let ok_if_true cond ~error =
          Deferred.return
            (Result.ok_if_true cond ~error:(Error.of_string error))
        in
        let is_sender_local =
          Envelope.Sender.(equal Local) (Envelope.Incoming.sender diff)
        in
        let%bind () =
          (* TODO: we should probably remove this -- the libp2p gossip cache should cover this already (#11704) *)
          let (`Already_mem already_mem) =
            Lru_cache.add t.recently_seen (Lru_cache.T.hash diff.data)
          in
          ok_if_true
            (not (already_mem && not is_sender_local))
            ~error:"Recently seen"
        in
        let%bind () =
          let cmds_with_insufficient_fees =
            List.filter
              (Envelope.Incoming.data diff)
              ~f:User_command.has_insufficient_fee
          in
          List.iter cmds_with_insufficient_fees ~f:(fun cmd ->
              [%log' debug t.logger]
                "User command $cmd from $sender has insufficient fee."
                ~metadata:
                  [ ("cmd", User_command.to_yojson cmd)
                  ; ( "sender"
                    , Envelope.(Sender.to_yojson (Incoming.sender diff)) )
                  ] ) ;
          let too_big_cmds =
            List.filter (Envelope.Incoming.data diff) ~f:(fun cmd ->
                let size_validity =
                  User_command.valid_size
                    ~genesis_constants:t.config.genesis_constants cmd
                in
                match size_validity with
                | Ok () ->
                    false
                | Error err ->
                    [%log' debug t.logger] "User command is too big"
                      ~metadata:
                        [ ("cmd", User_command.to_yojson cmd)
                        ; ( "sender"
                          , Envelope.(Sender.to_yojson (Incoming.sender diff))
                          )
                        ; ("size_violation", Error_json.error_to_yojson err)
                        ] ;
                    true )
          in
          let sufficient_fees = List.is_empty cmds_with_insufficient_fees in
          let valid_sizes = List.is_empty too_big_cmds in
          match (sufficient_fees, valid_sizes) with
          | true, true ->
              Deferred.Or_error.return ()
          | false, true ->
              Deferred.Or_error.fail
              @@ Error.of_string "Some commands have an insufficient fee"
          | true, false ->
              Deferred.Or_error.fail
              @@ Error.of_string "Some commands are too big"
          | false, false ->
              Deferred.Or_error.fail
              @@ Error.of_string
                   "Some commands have an insufficient fee, and some are too \
                    big"
        in
        (* TODO: batch `to_verifiable` (#11705) *)
        let%bind ledger =
          match t.best_tip_ledger with
          | Some ledger ->
              return ledger
          | None ->
              Deferred.Or_error.error_string
                "We don't have a transition frontier at the moment, so we're \
                 unable to verify any transactions."
        in
        let diff' =
          O1trace.sync_thread "convert_transactions_to_verifiable" (fun () ->
              Envelope.Incoming.map diff
                ~f:
                  (List.map
                     ~f:
                       (User_command.to_verifiable ~ledger ~get:Base_ledger.get
                          ~location_of_account:Base_ledger.location_of_account ) ) )
        in
        match%bind.Deferred
          O1trace.thread "batching_transaction_verification" (fun () ->
              Batcher.verify t.batcher diff' )
        with
        | Error e ->
            [%log' error t.logger] "Transaction verification error: $error"
              ~metadata:[ ("error", `String (Error.to_string_hum e)) ] ;
            [%log' debug t.logger]
              "Failed to batch verify $transaction_pool_diff"
              ~metadata:
                [ ( "transaction_pool_diff"
                  , Diff_versioned.to_yojson (Envelope.Incoming.data diff) )
                ] ;
            Deferred.return (Error (Error.tag e ~tag:"Internal_error"))
        | Ok (Error invalid) ->
            let msg = Verifier.invalid_to_string invalid in
            [%log' error t.logger]
              "Batch verification failed when adding from gossip"
              ~metadata:[ ("error", `String msg) ] ;
            let%map.Deferred () =
              Trust_system.record_envelope_sender t.config.trust_system t.logger
                (Envelope.Incoming.sender diff)
                ( Trust_system.Actions.Sent_useless_gossip
                , Some
                    ( "rejecting command because had invalid signature or proof"
                    , [] ) )
            in
            Error Error.(tag (of_string msg) ~tag:"Verification_failed")
        | Ok (Ok commands) ->
            (* TODO: avoid duplicate hashing (#11706) *)
            O1trace.sync_thread "hashing_transactions_after_verification"
              (fun () ->
                Deferred.return
                  (Ok
                     { diff with
                       data =
                         List.map commands
                           ~f:
                             Transaction_hash.User_command_with_valid_signature
                             .create
                     } ) )

      let register_locally_generated t txn =
        Hashtbl.update t.locally_generated_uncommitted txn ~f:(function
          | Some (_, `Batch batch_num) ->
              (* Use the existing [batch_num] on a re-issue, to avoid splitting
                 existing batches.
              *)
              (Time.now (), `Batch batch_num)
          | None ->
              let batch_num =
                if t.remaining_in_batch > 0 then (
                  t.remaining_in_batch <- t.remaining_in_batch - 1 ;
                  t.current_batch )
                else (
                  t.remaining_in_batch <- max_per_15_seconds - 1 ;
                  t.current_batch <- t.current_batch + 1 ;
                  t.current_batch )
              in
              (Time.now (), `Batch batch_num) )

      let apply t (diff : verified Envelope.Incoming.t) =
        let open Or_error.Let_syntax in
        let is_sender_local =
          Envelope.Sender.(equal Local) (Envelope.Incoming.sender diff)
        in
        let pool_size_before = Indexed_pool.size t.pool in
        (* preload fee payer accounts from the best tip ledger *)
        let%map ledger =
          match t.best_tip_ledger with
          | None ->
              Or_error.error_string
                "Got transaction pool diff when transitin frontier is \
                 unavailable, ignoring."
          | Some ledger ->
              return ledger
        in
        let fee_payer_account_ids =
          List.map (Envelope.Incoming.data diff) ~f:(fun cmd ->
              Transaction_hash.User_command_with_valid_signature.command cmd
              |> User_command.fee_payer )
          |> Account_id.Set.of_list
        in
        let fee_payer_accounts =
          preload_accounts ledger fee_payer_account_ids
        in
        (* add new commands to the pool *)
        let fee_payer =
          Fn.compose User_command.fee_payer
            Transaction_hash.User_command_with_valid_signature.command
        in
        let check_command pool cmd =
          if
            Indexed_pool.member pool
              (Transaction_hash.User_command.of_checked cmd)
          then Error Diff_error.Duplicate
          else
            match Map.find fee_payer_accounts (fee_payer cmd) with
            | None ->
                Error Diff_error.Fee_payer_account_not_found
            | Some account ->
                if not (Account.has_permission ~to_:`Send account) then
                  Error Diff_error.Fee_payer_not_permitted_to_send
                else Ok ()
        in
        let pool, add_results =
          List.fold_map (Envelope.Incoming.data diff) ~init:t.pool
            ~f:(fun pool cmd ->
              let result =
                let%bind.Result () = check_command pool cmd in
                let global_slot =
                  Indexed_pool.global_slot_since_genesis t.pool
                in
                let account = Map.find_exn fee_payer_accounts (fee_payer cmd) in
                match
                  Indexed_pool.add_from_gossip_exn pool cmd account.nonce
                    ( Account.liquid_balance_at_slot ~global_slot account
                    |> Currency.Balance.to_amount )
                with
                | Ok x ->
                    Ok x
                | Error err ->
                    report_command_error ~logger:t.logger ~is_sender_local
                      (Transaction_hash.User_command_with_valid_signature
                       .command cmd )
                      err ;
                    Error (diff_error_of_indexed_pool_error err)
              in
              match result with
              | Ok (cmd', pool', dropped) ->
                  (pool', Ok (cmd', dropped))
              | Error err ->
                  (pool, Error (cmd, err)) )
        in
        let dropped_for_add =
          List.filter_map add_results ~f:(function
            | Ok (_, dropped) ->
                Some (Sequence.to_list dropped)
            | Error _ ->
                None )
          |> List.concat
        in
        (* drop commands from the pool to retain max size *)
        let pool, dropped_for_size =
          let pool, dropped =
            drop_until_below_max_size pool ~pool_max_size:t.config.pool_max_size
          in
          (pool, Sequence.to_list dropped)
        in
        (* handle drops of locally generated commands *)
        let all_dropped_cmds = dropped_for_add @ dropped_for_size in
        let all_dropped_cmd_hashes =
          List.map all_dropped_cmds
            ~f:Transaction_hash.User_command_with_valid_signature.hash
          |> Transaction_hash.Set.of_list
        in
        [%log' debug t.logger]
          "Dropping $num_for_add commands from pool while adding new commands, \
           and $num_for_size commands due to pool size"
          ~metadata:
            [ ("num_for_add", `Int (List.length dropped_for_add))
            ; ("num_for_size", `Int (List.length dropped_for_size))
            ] ;
        let locally_generated_dropped =
          List.filter all_dropped_cmds ~f:(fun cmd ->
              Hashtbl.find_and_remove t.locally_generated_uncommitted cmd
              |> Option.is_some )
        in
        if not (List.is_empty locally_generated_dropped) then
          [%log' info t.logger]
            "Dropped locally generated commands $cmds from transaction pool \
             due to replacement or max size"
            ~metadata:
              [ ( "cmds"
                , `List
                    (List.map
                       ~f:
                         Transaction_hash.User_command_with_valid_signature
                         .to_yojson locally_generated_dropped ) )
              ] ;
        (* register locally generated commands *)
        if is_sender_local then
          List.iter add_results ~f:(function
            | Ok (cmd, _dropped) ->
                if
                  not
                    (Set.mem all_dropped_cmd_hashes
                       (Transaction_hash.User_command_with_valid_signature.hash
                          cmd ) )
                then register_locally_generated t cmd
            | Error _ ->
                () ) ;
        (* finalize the update to the pool *)
        t.pool <- pool ;
        let pool_size_after = Indexed_pool.size pool in
        Mina_metrics.(
          Gauge.set Transaction_pool.pool_size (Float.of_int pool_size_after) ;
          List.iter
            (List.init (max 0 (pool_size_after - pool_size_before)) ~f:Fn.id)
            ~f:(fun _ ->
              Counter.inc_one Transaction_pool.transactions_added_to_pool )) ;
        (* partition the results *)
        let accepted, rejected =
          List.partition_map add_results ~f:(function
            | Ok (cmd, _dropped) ->
                Either.First cmd
            | Error (cmd, error) ->
                Either.Second (cmd, error) )
        in
        (* determine if we should re-broadcast this diff *)
        let decision =
          if
            List.exists rejected ~f:(fun (_, error) ->
                Diff_error.grounds_for_diff_rejection error )
          then `Reject
          else `Accept
        in
        (decision, accepted, rejected)

      let unsafe_apply' (t : pool) (diff : verified Envelope.Incoming.t) :
          ([ `Accept | `Reject ] * t * rejected, _) Result.t =
        match apply t diff with
        | Ok (decision, accepted, rejected) ->
            ( if not (List.is_empty accepted) then
              Mina_metrics.(
                Gauge.set Transaction_pool.useful_transactions_received_time_sec
                  (let x =
                     Time.(now () |> to_span_since_epoch |> Span.to_sec)
                   in
                   x -. Mina_metrics.time_offset_sec )) ) ;
            let forget_cmd =
              Transaction_hash.User_command_with_valid_signature.command
            in
            Ok
              ( decision
              , List.map ~f:forget_cmd accepted
              , List.map ~f:(Tuple2.map_fst ~f:forget_cmd) rejected )
        | Error e ->
            Error (`Other e)

      let unsafe_apply t diff = Deferred.return (unsafe_apply' t diff)

      type Structured_log_events.t +=
        | Transactions_received of { txns : t; sender : Envelope.Sender.t }
        [@@deriving
          register_event
            { msg = "Received transaction-pool diff $txns from $sender" }]

      let update_metrics envelope valid_cb gossip_heard_logger_option =
        Mina_metrics.(Counter.inc_one Network.gossip_messages_received) ;
        Mina_metrics.(Gauge.inc_one Network.transaction_pool_diff_received) ;
        let diff = Envelope.Incoming.data envelope in
        Option.iter gossip_heard_logger_option ~f:(fun logger ->
            [%str_log debug]
              (Transactions_received
                 { txns = diff; sender = Envelope.Incoming.sender envelope } ) ) ;
        Mina_net2.Validation_callback.set_message_type valid_cb `Transaction ;
        Mina_metrics.(Counter.inc_one Network.Transaction.received)
    end

    let get_rebroadcastable (t : t) ~has_timed_out =
      let metadata ~key ~time =
        [ ( "cmd"
          , Transaction_hash.User_command_with_valid_signature.to_yojson key )
        ; ("time", `String (Time.to_string_abs ~zone:Time.Zone.utc time))
        ]
      in
      let added_str =
        "it was added at $time and its rebroadcast period is now expired."
      in
      let logger = t.logger in
      Hashtbl.filteri_inplace t.locally_generated_uncommitted
        ~f:(fun ~key ~data:(time, `Batch _) ->
          match has_timed_out time with
          | `Timed_out ->
              [%log info]
                "No longer rebroadcasting uncommitted command $cmd, %s"
                added_str ~metadata:(metadata ~key ~time) ;
              false
          | `Ok ->
              true ) ;
      Hashtbl.filteri_inplace t.locally_generated_committed
        ~f:(fun ~key ~data:(time, `Batch _) ->
          match has_timed_out time with
          | `Timed_out ->
              [%log debug]
                "Removing committed locally generated command $cmd from \
                 possible rebroadcast pool, %s"
                added_str ~metadata:(metadata ~key ~time) ;
              false
          | `Ok ->
              true ) ;
      (* Important to maintain ordering here *)
      let rebroadcastable_txs =
        Hashtbl.to_alist t.locally_generated_uncommitted
        |> List.sort
             ~compare:(fun (txn1, (_, `Batch batch1)) (txn2, (_, `Batch batch2))
                      ->
               let cmp = compare batch1 batch2 in
               let get_hash =
                 Transaction_hash.User_command_with_valid_signature.hash
               in
               let get_nonce txn =
                 Transaction_hash.User_command_with_valid_signature.command txn
                 |> User_command.applicable_at_nonce
               in
               if cmp <> 0 then cmp
               else
                 let cmp =
                   Mina_numbers.Account_nonce.compare (get_nonce txn1)
                     (get_nonce txn2)
                 in
                 if cmp <> 0 then cmp
                 else Transaction_hash.compare (get_hash txn1) (get_hash txn2) )
        |> List.group
             ~break:(fun (_, (_, `Batch batch1)) (_, (_, `Batch batch2)) ->
               batch1 <> batch2 )
        |> List.map
             ~f:
               (List.map ~f:(fun (txn, _) ->
                    Transaction_hash.User_command_with_valid_signature.command
                      txn ) )
      in
      rebroadcastable_txs
  end

  include Network_pool_base.Make (Transition_frontier) (Resource_pool)
end

(* Use this one in downstream consumers *)
module Make (Staged_ledger : sig
  type t

  val ledger : t -> Mina_ledger.Ledger.t
end)
(Transition_frontier : Transition_frontier_intf
                         with type staged_ledger := Staged_ledger.t) :
  S with type transition_frontier := Transition_frontier.t =
  Make0 (Mina_ledger.Ledger) (Staged_ledger) (Transition_frontier)

(* TODO: defunctor or remove monkey patching (#3731) *)
include
  Make
    (Staged_ledger)
    (struct
      include Transition_frontier

      type best_tip_diff = Extensions.Best_tip_diff.view =
        { new_commands : User_command.Valid.t With_status.t list
        ; removed_commands : User_command.Valid.t With_status.t list
        ; reorg_best_tip : bool
        }

      let best_tip_diff_pipe t =
        Extensions.(get_view_pipe (extensions t) Best_tip_diff)
    end)

let%test_module _ =
  ( module struct
    open Signature_lib
    module Mock_base_ledger = Mocks.Base_ledger
    module Mock_staged_ledger = Mocks.Staged_ledger

    let () =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let num_test_keys = 10

    (* keys for accounts in the ledger *)
    let test_keys =
      Array.init num_test_keys ~f:(fun _ -> Signature_lib.Keypair.create ())

    let num_extra_keys = 30

    (* keys that can be used when generating new accounts *)
    let extra_keys =
      Array.init num_extra_keys ~f:(fun _ -> Signature_lib.Keypair.create ())

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let constraint_constants = precomputed_values.constraint_constants

    let consensus_constants = precomputed_values.consensus_constants

    let proof_level = precomputed_values.proof_level

    let minimum_fee =
      Currency.Fee.to_int Mina_compile_config.minimum_user_command_fee

    let logger = Logger.create ()

    let time_controller = Block_time.Controller.basic ~logger

    let expiry_ns =
      Time_ns.Span.of_hr
        (Float.of_int precomputed_values.genesis_constants.transaction_expiry_hr)

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ()) )

    let `VK vk, `Prover prover =
      Transaction_snark.For_tests.create_trivial_snapp ~constraint_constants ()

    let dummy_state_view =
      let state_body =
        let consensus_constants =
          let genesis_constants = Genesis_constants.for_unit_tests in
          Consensus.Constants.create ~constraint_constants
            ~protocol_constants:genesis_constants.protocol
        in
        let compile_time_genesis =
          (*not using Precomputed_values.for_unit_test because of dependency cycle*)
          Mina_state.Genesis_protocol_state.t
            ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
            ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
            ~constraint_constants ~consensus_constants
            ~genesis_body_reference:Staged_ledger_diff.genesis_body_reference
        in
        compile_time_genesis.data |> Mina_state.Protocol_state.body
      in
      { (Mina_state.Protocol_state.Body.view state_body) with
        global_slot_since_genesis = Mina_numbers.Global_slot.zero
      }

    module Mock_transition_frontier = struct
      module Breadcrumb = struct
        type t = Mock_staged_ledger.t

        let staged_ledger = Fn.id
      end

      type best_tip_diff =
        { new_commands : User_command.Valid.t With_status.t list
        ; removed_commands : User_command.Valid.t With_status.t list
        ; reorg_best_tip : bool
        }

      type t = best_tip_diff Broadcast_pipe.Reader.t * Breadcrumb.t ref

      let create : unit -> t * best_tip_diff Broadcast_pipe.Writer.t =
       fun () ->
        let zkappify_account (account : Account.t) : Account.t =
          let zkapp =
            Some { Zkapp_account.default with verification_key = Some vk }
          in
          { account with zkapp }
        in
        let pipe_r, pipe_w =
          Broadcast_pipe.create
            { new_commands = []; removed_commands = []; reorg_best_tip = false }
        in
        let initial_balance =
          Currency.Balance.of_formatted_string "900000000.0"
        in
        let ledger = Mina_ledger.Ledger.create_ephemeral ~depth:10 () in
        Array.iteri test_keys ~f:(fun i kp ->
            let account_id =
              Account_id.create
                (Public_key.compress kp.public_key)
                Token_id.default
            in
            let _tag, account, loc =
              Or_error.ok_exn
              @@ Mina_ledger.Ledger.Ledger_inner.get_or_create ledger account_id
            in
            (* set the account balance *)
            let account = { account with balance = initial_balance } in
            (* zkappify every other account *)
            let account =
              if i mod 2 = 0 then account else zkappify_account account
            in
            Mina_ledger.Ledger.Ledger_inner.set ledger loc account ) ;
        ((pipe_r, ref ledger), pipe_w)

      let best_tip (_, best_tip) = !best_tip

      let best_tip_diff_pipe (pipe, _) = pipe
    end

    module Test =
      Make0 (Mock_base_ledger) (Mock_staged_ledger) (Mock_transition_frontier)

    type test =
      { txn_pool : Test.Resource_pool.t
      ; best_tip_diff_w :
          Mock_transition_frontier.best_tip_diff Broadcast_pipe.Writer.t
      ; best_tip_ref : Mina_ledger.Ledger.t ref
      ; frontier_pipe_w :
          Mock_transition_frontier.t option Broadcast_pipe.Writer.t
      }

    let pool_max_size = 25

    let assert_user_command_sets_equal cs1 cs2 =
      let index cs =
        let decompose c =
          ( Transaction_hash.User_command.hash c
          , Transaction_hash.User_command.command c )
        in
        List.map cs ~f:decompose |> Transaction_hash.Map.of_alist_exn
      in
      let index1 = index cs1 in
      let index2 = index cs2 in
      let set1 = Transaction_hash.Set.of_list @@ Map.keys index1 in
      let set2 = Transaction_hash.Set.of_list @@ Map.keys index2 in
      if not (Set.equal set1 set2) then (
        let additional1, additional2 =
          Set.symmetric_diff set1 set2
          |> Sequence.map
               ~f:
                 (Either.map ~first:(Map.find_exn index1)
                    ~second:(Map.find_exn index2) )
          |> Sequence.to_list
          |> List.partition_map ~f:Fn.id
        in
        assert (List.length additional1 + List.length additional2 > 0) ;
        let report_additional commands a b =
          Core.Printf.printf "%s user commands not in %s:\n" a b ;
          List.iter commands ~f:(fun c ->
              Core.Printf.printf !"  %{Sexp}\n" (User_command.sexp_of_t c) )
        in
        if List.length additional1 > 0 then
          report_additional additional1 "actual" "expected" ;
        if List.length additional2 > 0 then
          report_additional additional2 "expected" "actual" ) ;
      [%test_eq: Transaction_hash.Set.t] set1 set2

    let replace_valid_zkapp_command_authorizations ~keymap ~ledger valid_cmds :
        User_command.Valid.t list Deferred.t =
      Deferred.List.map
        (valid_cmds : User_command.Valid.t list)
        ~f:(function
          | Zkapp_command zkapp_command_dummy_auths ->
              let%map zkapp_command =
                Zkapp_command_builder.replace_authorizations ~keymap ~prover
                  (Zkapp_command.Valid.forget zkapp_command_dummy_auths)
              in
              let valid_zkapp_command =
                let open Mina_ledger.Ledger in
                match
                  Zkapp_command.Valid.to_valid ~ledger ~get ~location_of_account
                    zkapp_command
                with
                | Some ps ->
                    ps
                | None ->
                    failwith "Could not create Zkapp_command.Valid.t"
              in
              User_command.Zkapp_command valid_zkapp_command
          | Signed_command _ ->
              failwith "Expected Zkapp_command valid user command" )

    (** Assert the invariants of the locally generated command tracking system. *)
    let assert_locally_generated (pool : Test.Resource_pool.t) =
      ignore
        ( Hashtbl.merge pool.locally_generated_committed
            pool.locally_generated_uncommitted ~f:(fun ~key -> function
            | `Both ((committed, _), (uncommitted, _)) ->
                failwithf
                  !"Command \
                    %{sexp:Transaction_hash.User_command_with_valid_signature.t} \
                    in both locally generated committed and uncommitted with \
                    times %s and %s"
                  key (Time.to_string committed)
                  (Time.to_string uncommitted)
                  ()
            | `Left cmd ->
                Some cmd
            | `Right cmd ->
                (* Locally generated uncommitted transactions should be in the
                   pool, so long as we're not in the middle of updating it. *)
                assert (
                  Indexed_pool.member pool.pool
                    (Transaction_hash.User_command.of_checked key) ) ;
                Some cmd )
          : ( Transaction_hash.User_command_with_valid_signature.t
            , Time.t * [ `Batch of int ] )
            Hashtbl.t )

    let assert_fee_wu_ordering (pool : Test.Resource_pool.t) =
      let txns = Test.Resource_pool.transactions pool |> Sequence.to_list in
      let compare txn1 txn2 =
        let open Transaction_hash.User_command_with_valid_signature in
        let cmd1 = command txn1 in
        let cmd2 = command txn2 in
        (* ascending order of nonces, if same fee payer *)
        if
          Account_id.equal
            (User_command.fee_payer cmd1)
            (User_command.fee_payer cmd2)
        then
          Account.Nonce.compare
            (User_command.applicable_at_nonce cmd1)
            (User_command.applicable_at_nonce cmd2)
        else
          let get_fee_wu cmd = User_command.fee_per_wu cmd in
          (* descending order of fee/weight *)
          Currency.Fee_rate.compare (get_fee_wu cmd2) (get_fee_wu cmd1)
      in
      assert (List.is_sorted txns ~compare)

    let assert_pool_txs test txs =
      Indexed_pool.For_tests.assert_invariants test.txn_pool.pool ;
      assert_locally_generated test.txn_pool ;
      assert_fee_wu_ordering test.txn_pool ;
      assert_user_command_sets_equal
        ( Sequence.to_list
        @@ Sequence.map ~f:Transaction_hash.User_command.of_checked
        @@ Test.Resource_pool.transactions test.txn_pool )
        (List.map
           ~f:
             (Fn.compose Transaction_hash.User_command.create
                User_command.forget_check )
           txs )

    let setup_test ?expiry () =
      let frontier, best_tip_diff_w = Mock_transition_frontier.create () in
      let _, best_tip_ref = frontier in
      let frontier_pipe_r, frontier_pipe_w =
        Broadcast_pipe.create @@ Some frontier
      in
      let trust_system = Trust_system.null () in
      let config =
        Test.Resource_pool.make_config ~trust_system ~pool_max_size ~verifier
          ~genesis_constants:Genesis_constants.compiled
      in
      let expiry_ns = match expiry with None -> expiry_ns | Some t -> t in
      let pool_, _, _ =
        Test.create ~config ~logger ~constraint_constants ~consensus_constants
          ~time_controller ~expiry_ns ~frontier_broadcast_pipe:frontier_pipe_r
          ~log_gossip_heard:false ~on_remote_push:(Fn.const Deferred.unit)
      in
      let txn_pool = Test.resource_pool pool_ in
      let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
      { txn_pool; best_tip_diff_w; best_tip_ref; frontier_pipe_w }

    let independent_cmds : User_command.Valid.t list =
      let rec go n cmds =
        let open Quickcheck.Generator.Let_syntax in
        if n < Array.length test_keys then
          let%bind cmd =
            let sender = test_keys.(n) in
            User_command.Valid.Gen.payment ~sign_type:`Real
              ~key_gen:
                (Quickcheck.Generator.tuple2 (return sender)
                   (Quickcheck_lib.of_array test_keys) )
              ~max_amount:1_000_000_000 ~fee_range:1_000_000_000 ()
          in
          go (n + 1) (cmd :: cmds)
        else Quickcheck.Generator.return @@ List.rev cmds
      in
      Quickcheck.random_value ~seed:(`Deterministic "constant") (go 0 [])

    let mk_payment' ?valid_until ~sender_idx ~receiver_idx ~fee ~nonce ~amount
        () =
      let get_pk idx = Public_key.compress test_keys.(idx).public_key in
      Signed_command.sign test_keys.(sender_idx)
        (Signed_command_payload.create ~fee:(Currency.Fee.of_int fee)
           ~fee_payer_pk:(get_pk sender_idx) ~valid_until
           ~nonce:(Account.Nonce.of_int nonce)
           ~memo:(Signed_command_memo.create_by_digesting_string_exn "foo")
           ~body:
             (Signed_command_payload.Body.Payment
                { source_pk = get_pk sender_idx
                ; receiver_pk = get_pk receiver_idx
                ; amount = Currency.Amount.of_int amount
                } ) )

    let mk_transfer_zkapp_command ?valid_period ?fee_payer_idx ~sender_idx
        ~receiver_idx ~fee ~nonce ~amount () =
      let sender_kp = test_keys.(sender_idx) in
      let sender_nonce = Account.Nonce.of_int nonce in
      let sender = (sender_kp, sender_nonce) in
      let amount = Currency.Amount.of_int amount in
      let receiver_kp = test_keys.(receiver_idx) in
      let receiver =
        receiver_kp.public_key |> Signature_lib.Public_key.compress
      in
      let fee_payer =
        match fee_payer_idx with
        | None ->
            None
        | Some (idx, nonce) ->
            let fee_payer_kp = test_keys.(idx) in
            let fee_payer_nonce = Account.Nonce.of_int nonce in
            Some (fee_payer_kp, fee_payer_nonce)
      in
      let fee = Currency.Fee.of_int fee in
      let protocol_state_precondition =
        match valid_period with
        | None ->
            Zkapp_precondition.Protocol_state.accept
        | Some time ->
            Zkapp_precondition.Protocol_state.valid_until time
      in
      let test_spec : Transaction_snark.For_tests.Multiple_transfers_spec.t =
        { sender
        ; fee_payer
        ; fee
        ; receivers = [ (receiver, amount) ]
        ; amount
        ; zkapp_account_keypairs = []
        ; memo = Signed_command_memo.create_from_string_exn "expiry tests"
        ; new_zkapp_account = false
        ; snapp_update = Account_update.Update.dummy
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions =
            Some
              { Account_update.Preconditions.network =
                  protocol_state_precondition
              ; account =
                  Account_update.Account_precondition.Nonce
                    ( if Option.is_none fee_payer then
                      Account.Nonce.succ sender_nonce
                    else sender_nonce )
              }
        }
      in
      let zkapp_command =
        Transaction_snark.For_tests.multiple_transfers test_spec
      in
      let zkapp_command =
        Option.value_exn
          (Zkapp_command.Valid.to_valid ~ledger:()
             ~get:(fun _ _ -> failwith "Not expecting proof zkapp_command")
             ~location_of_account:(fun _ _ ->
               failwith "Not expecting proof zkapp_command" )
             zkapp_command )
      in
      User_command.Zkapp_command zkapp_command

    let mk_payment ?valid_until ~sender_idx ~receiver_idx ~fee ~nonce ~amount ()
        =
      User_command.Signed_command
        (mk_payment' ?valid_until ~sender_idx ~fee ~nonce ~receiver_idx ~amount
           () )

    let mk_zkapp_command_cmds (pool : Test.Resource_pool.t) :
        User_command.Valid.t list Deferred.t =
      let num_cmds = 7 in
      assert (num_cmds < Array.length test_keys - 1) ;
      let best_tip_ledger = Option.value_exn pool.best_tip_ledger in
      let keymap =
        Array.fold (Array.append test_keys extra_keys)
          ~init:Public_key.Compressed.Map.empty
          ~f:(fun map { public_key; private_key } ->
            let key = Public_key.compress public_key in
            Public_key.Compressed.Map.add_exn map ~key ~data:private_key )
      in
      let account_state_tbl =
        List.take (Array.to_list test_keys) num_cmds
        |> List.map ~f:(fun kp ->
               let id =
                 Account_id.create
                   (Public_key.compress kp.public_key)
                   Token_id.default
               in
               let state =
                 Option.value_exn
                   (let%bind.Option loc =
                      Mina_ledger.Ledger.location_of_account best_tip_ledger id
                    in
                    Mina_ledger.Ledger.get best_tip_ledger loc )
               in
               (id, (state, `Fee_payer)) )
        |> Account_id.Table.of_alist_exn
      in
      let rec go n cmds =
        let open Quickcheck.Generator.Let_syntax in
        if n < num_cmds then
          let%bind cmd =
            let fee_payer_keypair = test_keys.(n) in
            let%map (zkapp_command : Zkapp_command.t) =
              Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
                ~keymap ~account_state_tbl ~fee_payer_keypair
                ~ledger:best_tip_ledger ()
            in
            let zkapp_command =
              { zkapp_command with
                account_updates =
                  Zkapp_command.Call_forest.map zkapp_command.account_updates
                    ~f:(fun (p : Account_update.t) ->
                      { p with
                        body =
                          { p.body with
                            preconditions =
                              { p.body.preconditions with
                                account =
                                  ( match p.body.preconditions.account with
                                  | Account_update.Account_precondition.Full
                                      { nonce =
                                          Zkapp_basic.Or_ignore.Check n as c
                                      ; _
                                      }
                                    when Zkapp_precondition.Numeric.(
                                           is_constant Tc.nonce c) ->
                                      Account_update.Account_precondition.Nonce
                                        n.lower
                                  | Account_update.Account_precondition.Full _
                                    ->
                                      Account_update.Account_precondition.Accept
                                  | pre ->
                                      pre )
                              }
                          }
                      } )
              }
            in
            let zkapp_command =
              Option.value_exn
                (Zkapp_command.Valid.to_valid ~ledger:best_tip_ledger
                   ~get:Mina_ledger.Ledger.get
                   ~location_of_account:Mina_ledger.Ledger.location_of_account
                   zkapp_command )
            in
            User_command.Zkapp_command zkapp_command
          in
          go (n + 1) (cmd :: cmds)
        else Quickcheck.Generator.return @@ List.rev cmds
      in
      let result =
        Quickcheck.random_value ~seed:(`Deterministic "zkapp_command") (go 0 [])
      in
      replace_valid_zkapp_command_authorizations ~keymap ~ledger:best_tip_ledger
        result

    type pool_apply = (User_command.t list, [ `Other of Error.t ]) Result.t
    [@@deriving sexp, compare]

    let canonicalize t =
      Result.map t ~f:(List.sort ~compare:User_command.compare)

    let compare_pool_apply (t1 : pool_apply) (t2 : pool_apply) =
      compare_pool_apply (canonicalize t1) (canonicalize t2)

    let assert_pool_apply expected_commands result =
      let accepted_commands =
        Result.map result ~f:(fun (_, accepted, _) -> accepted)
      in
      [%test_eq: pool_apply] accepted_commands
        (Ok (List.map ~f:User_command.forget_check expected_commands))

    let mk_with_status (cmd : User_command.Valid.t) =
      { With_status.data = cmd; status = Applied }

    let add_commands ?(local = true) test cs =
      let sender =
        if local then Envelope.Sender.Local
        else
          Envelope.Sender.Remote
            (Peer.create
               (Unix.Inet_addr.of_string "1.2.3.4")
               ~peer_id:
                 (Peer.Id.unsafe_of_string "contents should be irrelevant")
               ~libp2p_port:8302 )
      in
      let tm0 = Time.now () in
      let%bind verified =
        Test.Resource_pool.Diff.verify test.txn_pool
          (Envelope.Incoming.wrap
             ~data:(List.map ~f:User_command.forget_check cs)
             ~sender )
        >>| Or_error.ok_exn
      in
      let%map result =
        Test.Resource_pool.Diff.unsafe_apply test.txn_pool verified
      in
      let tm1 = Time.now () in
      [%log' info test.txn_pool.logger] "Time for add_commands: %0.04f sec"
        (Time.diff tm1 tm0 |> Time.Span.to_sec) ;
      ( match result with
      | Ok (`Accept, _, rejects) ->
          List.iter rejects ~f:(fun (cmd, err) ->
              Core.Printf.printf
                !"command was rejected because %s: %{Yojson.Safe}\n%!"
                (Diff_versioned.Diff_error.to_string_name err)
                (User_command.to_yojson cmd) )
      | Ok (`Reject, _, _) ->
          failwith "diff was rejected during application"
      | Error (`Other err) ->
          Core.Printf.printf
            !"failed to apply diff to pool: %s\n%!"
            (Error.to_string_hum err) ) ;
      result

    let add_commands' ?local test cs =
      add_commands ?local test cs >>| assert_pool_apply cs

    let reorg ?(reorg_best_tip = false) test new_commands removed_commands =
      let%bind () =
        Broadcast_pipe.Writer.write test.best_tip_diff_w
          { Mock_transition_frontier.new_commands =
              List.map ~f:mk_with_status new_commands
          ; removed_commands = List.map ~f:mk_with_status removed_commands
          ; reorg_best_tip
          }
      in
      Async.Scheduler.yield_until_no_jobs_remain ()

    let commit_commands test cs =
      let ledger = Option.value_exn test.txn_pool.best_tip_ledger in
      List.iter cs ~f:(fun c ->
          match User_command.forget_check c with
          | User_command.Signed_command c -> (
              let (`If_this_is_used_it_should_have_a_comment_justifying_it valid)
                  =
                Signed_command.to_valid_unsafe c
              in
              let applied =
                Or_error.ok_exn
                @@ Mina_ledger.Ledger.apply_user_command ~constraint_constants
                     ~txn_global_slot:Mina_numbers.Global_slot.zero ledger valid
              in
              match applied.body with
              | Failed ->
                  failwith "failed to apply user command to ledger"
              | _ ->
                  () )
          | User_command.Zkapp_command p -> (
              let applied, _ =
                Or_error.ok_exn
                @@ Mina_ledger.Ledger.apply_zkapp_command_unchecked
                     ~constraint_constants ~state_view:dummy_state_view ledger p
              in
              match With_status.status applied.command with
              | Failed failures ->
                  failwithf
                    "failed to apply zkapp_command transaction to ledger: [%s]"
                    ( String.concat ~sep:", "
                    @@ List.bind
                         ~f:(List.map ~f:Transaction_status.Failure.to_string)
                         failures )
                    ()
              | Applied ->
                  () ) )

    let commit_commands' test cs =
      let open Mina_ledger in
      let ledger = Option.value_exn test.txn_pool.best_tip_ledger in
      test.best_tip_ref :=
        Ledger.Maskable.register_mask
          (Ledger.Any_ledger.cast (module Mina_ledger.Ledger) ledger)
          (Ledger.Mask.create ~depth:(Ledger.depth ledger) ()) ;
      let%map () = reorg test [] [] in
      commit_commands test cs ; ledger

    let advance_chain test cs = commit_commands test cs ; reorg test cs []

    (* TODO: remove this (all of these test should be expressed by committing txns to the ledger, not mutating accounts *)
    let modify_ledger ledger ~idx ~balance ~nonce =
      let id =
        Account_id.create
          (Signature_lib.Public_key.compress test_keys.(idx).public_key)
          Token_id.default
      in
      let loc =
        Option.value_exn @@ Mina_ledger.Ledger.location_of_account ledger id
      in
      let account = Option.value_exn @@ Mina_ledger.Ledger.get ledger loc in
      Mina_ledger.Ledger.set ledger loc
        { account with
          balance = Currency.Balance.of_int balance
        ; nonce = Account.Nonce.of_int nonce
        }

    let mk_linear_case_test t cmds =
      assert_pool_txs t [] ;
      let%bind () = add_commands' t cmds in
      let%bind () = advance_chain t (List.take independent_cmds 1) in
      assert_pool_txs t (List.drop cmds 1) ;
      let%bind () =
        advance_chain t (List.take (List.drop independent_cmds 1) 2)
      in
      assert_pool_txs t (List.drop cmds 3) ;
      Deferred.unit

    let%test_unit "transactions are removed in linear case (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_linear_case_test test independent_cmds )

    let%test_unit "transactions are removed in linear case (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_command_cmds test.txn_pool >>= mk_linear_case_test test )

    let mk_remove_and_add_test t cmds =
      assert_pool_txs t [] ;
      (* omit the 1st (0-based) command *)
      let%bind () = add_commands' t (List.hd_exn cmds :: List.drop cmds 2) in
      commit_commands t (List.take cmds 1) ;
      let%bind () = reorg t (List.take cmds 1) (List.slice cmds 1 2) in
      assert_pool_txs t (List.tl_exn cmds) ;
      Deferred.unit

    let%test_unit "Transactions are removed and added back in fork changes \
                   (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_remove_and_add_test test independent_cmds )

    let%test_unit "Transactions are removed and added back in fork changes \
                   (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_command_cmds test.txn_pool >>= mk_remove_and_add_test test )

    let mk_invalid_test t cmds =
      assert_pool_txs t [] ;
      let%bind () = advance_chain t (List.take cmds 2) in
      let%bind () =
        add_commands t cmds >>| assert_pool_apply (List.drop cmds 2)
      in
      assert_pool_txs t (List.drop cmds 2) ;
      Deferred.unit

    let%test_unit "invalid transactions are not accepted (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_invalid_test test independent_cmds )

    let%test_unit "invalid transactions are not accepted (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_command_cmds test.txn_pool >>= mk_invalid_test test )

    let current_global_slot () =
      let current_time = Block_time.now time_controller in
      Consensus.Data.Consensus_time.(
        of_time_exn ~constants:consensus_constants current_time
        |> to_global_slot)

    let mk_now_invalid_test t _cmds ~mk_command =
      let cmd1 =
        mk_command ~sender_idx:0 ~receiver_idx:5 ~fee:minimum_fee ~nonce:0
          ~amount:99_999_999_999 ()
      in
      let cmd2 =
        mk_command ~sender_idx:0 ~receiver_idx:5 ~fee:minimum_fee ~nonce:0
          ~amount:999_000_000_000 ()
      in
      assert_pool_txs t [] ;
      let%bind () = add_commands' t [ cmd1 ] in
      assert_pool_txs t [ cmd1 ] ;
      let%bind () = advance_chain t [ cmd2 ] in
      assert_pool_txs t [] ; Deferred.unit

    let%test_unit "Now-invalid transactions are removed from the pool on fork \
                   changes (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_now_invalid_test test independent_cmds
            ~mk_command:(mk_payment ?valid_until:None) )

    let%test_unit "Now-invalid transactions are removed from the pool on fork \
                   changes (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_command_cmds test.txn_pool
          >>= mk_now_invalid_test test
                ~mk_command:
                  (mk_transfer_zkapp_command ?valid_period:None
                     ?fee_payer_idx:None ) )

    let mk_expired_not_accepted_test t ~padding cmds =
      assert_pool_txs t [] ;
      let%bind () =
        let current_time = Block_time.now time_controller in
        let slot_end =
          Consensus.Data.Consensus_time.(
            of_time_exn ~constants:consensus_constants current_time
            |> end_time ~constants:consensus_constants)
        in
        at (Block_time.to_time_exn slot_end)
      in
      let curr_slot = current_global_slot () in
      let slot_padding = Mina_numbers.Global_slot.of_int padding in
      let curr_slot_plus_padding =
        Mina_numbers.Global_slot.add curr_slot slot_padding
      in
      let valid_command =
        mk_payment ~valid_until:curr_slot_plus_padding ~sender_idx:1
          ~fee:minimum_fee ~nonce:1 ~receiver_idx:7 ~amount:1_000_000_000 ()
      in
      let expired_commands =
        [ mk_payment ~valid_until:curr_slot ~sender_idx:0 ~fee:minimum_fee
            ~nonce:1 ~receiver_idx:9 ~amount:1_000_000_000 ()
        ; mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:2 ~receiver_idx:9
            ~amount:1_000_000_000 ()
        ]
      in
      (* Wait till global slot increases by 1 which invalidates
         the commands with valid_until = curr_slot
      *)
      let%bind () =
        after
          (Block_time.Span.to_time_span
             consensus_constants.block_window_duration_ms )
      in
      let all_valid_commands = cmds @ [ valid_command ] in
      let%bind () =
        add_commands t (all_valid_commands @ expired_commands)
        >>| assert_pool_apply all_valid_commands
      in
      assert_pool_txs t all_valid_commands ;
      Deferred.unit

    let%test_unit "expired transactions are not accepted (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_expired_not_accepted_test test ~padding:10 independent_cmds )

    let%test_unit "expired transactions are not accepted (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_command_cmds test.txn_pool
          >>= mk_expired_not_accepted_test test ~padding:55 )

    let%test_unit "Expired transactions that are already in the pool are \
                   removed from the pool when best tip changes (user commands)"
        =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind t = setup_test () in
          assert_pool_txs t [] ;
          let curr_slot = current_global_slot () in
          let curr_slot_plus_three =
            Mina_numbers.Global_slot.(add curr_slot (of_int 3))
          in
          let curr_slot_plus_seven =
            Mina_numbers.Global_slot.(add curr_slot (of_int 7))
          in
          let few_now =
            List.take independent_cmds (List.length independent_cmds / 2)
          in
          let expires_later1 =
            mk_payment ~valid_until:curr_slot_plus_three ~sender_idx:0
              ~fee:minimum_fee ~nonce:1 ~receiver_idx:9 ~amount:10_000_000_000
              ()
          in
          let expires_later2 =
            mk_payment ~valid_until:curr_slot_plus_seven ~sender_idx:0
              ~fee:minimum_fee ~nonce:2 ~receiver_idx:9 ~amount:10_000_000_000
              ()
          in
          let valid_commands = few_now @ [ expires_later1; expires_later2 ] in
          let%bind () = add_commands' t valid_commands in
          assert_pool_txs t valid_commands ;
          (* new commands from best tip diff should be removed from the pool *)
          (* update the nonce to be consistent with the commands in the block *)
          modify_ledger !(t.best_tip_ref) ~idx:0 ~balance:1_000_000_000_000_000
            ~nonce:2 ;
          let%bind () = reorg t [ List.nth_exn few_now 0; expires_later1 ] [] in
          let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
          assert_pool_txs t (expires_later2 :: List.drop few_now 1) ;
          (* Add new commands, remove old commands some of which are now expired *)
          let expired_command =
            mk_payment ~valid_until:curr_slot ~sender_idx:9 ~fee:minimum_fee
              ~nonce:0 ~receiver_idx:5 ~amount:1_000_000_000 ()
          in
          let unexpired_command =
            mk_payment ~valid_until:curr_slot_plus_seven ~sender_idx:8
              ~fee:minimum_fee ~nonce:0 ~receiver_idx:9 ~amount:1_000_000_000 ()
          in
          let valid_forever = List.nth_exn few_now 0 in
          let removed_commands =
            [ valid_forever
            ; expires_later1
            ; expired_command
            ; unexpired_command
            ]
          in
          let n_block_times n =
            Int64.(
              Block_time.Span.to_ms consensus_constants.block_window_duration_ms
              * n)
            |> Block_time.Span.of_ms
          in
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 3L))
          in
          modify_ledger !(t.best_tip_ref) ~idx:0 ~balance:1_000_000_000_000_000
            ~nonce:1 ;
          let%bind _ = reorg t [ valid_forever ] removed_commands in
          (* expired_command should not be in the pool because they are expired
             and (List.nth few_now 0) because it was committed in a block
          *)
          assert_pool_txs t
            ( expires_later1 :: expires_later2 :: unexpired_command
            :: List.drop few_now 1 ) ;
          (* after 5 block times there should be no expired transactions *)
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 5L))
          in
          let%bind _ = reorg t [] [] in
          assert_pool_txs t (List.drop few_now 1) ;
          Deferred.unit )

    let%test_unit "Expired transactions that are already in the pool are \
                   removed from the pool when best tip changes (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let eight_block_time =
            Int64.(
              Block_time.Span.to_ms consensus_constants.block_window_duration_ms
              * 8L)
            |> Int64.to_int |> Option.value_exn |> Time_ns.Span.of_int_ms
          in
          (* Since expiration for zkapp and transaction_pool uses the same constant, so I use the duration_of_the_test which is 8_slot + 1 sec as the expiration, so that the transaction won't be expired before the test is over. *)
          let expiry = Time_ns.Span.(eight_block_time + of_sec 1.) in
          let eight_block =
            Block_time.Span.of_time_span
            @@ Time_ns.Span.to_span_float_round_nearest eight_block_time
          in
          let%bind t = setup_test ~expiry () in
          assert_pool_txs t [] ;
          let curr_time =
            Block_time.sub (Block_time.of_time (Time.now ())) eight_block
          in
          let n_block_times n =
            Int64.(
              Block_time.Span.to_ms consensus_constants.block_window_duration_ms
              * n)
            |> Block_time.Span.of_ms
          in
          let three_slot = n_block_times 3L in
          let seven_slot = n_block_times 7L in
          let curr_time_plus_three = Block_time.add curr_time three_slot in
          let curr_time_plus_seven = Block_time.add curr_time seven_slot in
          let few_now =
            List.take independent_cmds (List.length independent_cmds / 2)
          in
          let expires_later1 =
            mk_transfer_zkapp_command
              ~valid_period:{ lower = curr_time; upper = curr_time_plus_three }
              ~fee_payer_idx:(0, 1) ~sender_idx:1 ~receiver_idx:9
              ~fee:minimum_fee ~amount:10_000_000_000 ~nonce:1 ()
          in
          let expires_later2 =
            mk_transfer_zkapp_command
              ~valid_period:{ lower = curr_time; upper = curr_time_plus_seven }
              ~fee_payer_idx:(0, 2) ~sender_idx:1 ~receiver_idx:9
              ~fee:minimum_fee ~amount:10_000_000_000 ~nonce:2 ()
          in
          let valid_commands = few_now @ [ expires_later1; expires_later2 ] in
          let%bind () = add_commands' t valid_commands in
          assert_pool_txs t valid_commands ;
          (* new commands from best tip diff should be removed from the pool *)
          (* update the nonce to be consistent with the commands in the block *)
          modify_ledger !(t.best_tip_ref) ~idx:0 ~balance:1_000_000_000_000_000
            ~nonce:2 ;
          modify_ledger !(t.best_tip_ref) ~idx:1 ~balance:1_000_000_000_000_000
            ~nonce:2 ;
          let%bind () = reorg t (List.take few_now 2 @ [ expires_later1 ]) [] in
          assert_pool_txs t (expires_later2 :: List.drop few_now 2) ;
          (* Add new commands, remove old commands some of which are now expired *)
          let expired_zkapp =
            mk_transfer_zkapp_command
              ~valid_period:{ lower = curr_time; upper = curr_time }
              ~fee_payer_idx:(9, 0) ~sender_idx:1 ~fee:minimum_fee ~nonce:3
              ~receiver_idx:5 ~amount:1_000_000_000 ()
          in
          let unexpired_zkapp =
            mk_transfer_zkapp_command
              ~valid_period:{ lower = curr_time; upper = curr_time_plus_seven }
              ~fee_payer_idx:(8, 0) ~sender_idx:1 ~fee:minimum_fee ~nonce:4
              ~receiver_idx:9 ~amount:1_000_000_000 ()
          in
          let valid_forever = List.nth_exn few_now 0 in
          let removed_commands =
            [ valid_forever; expires_later1; expired_zkapp; unexpired_zkapp ]
          in
          let n_block_times n =
            Int64.(
              Block_time.Span.to_ms consensus_constants.block_window_duration_ms
              * n)
            |> Block_time.Span.of_ms
          in
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 3L))
          in
          modify_ledger !(t.best_tip_ref) ~idx:0 ~balance:1_000_000_000_000_000
            ~nonce:1 ;
          modify_ledger !(t.best_tip_ref) ~idx:1 ~balance:1_000_000_000_000_000
            ~nonce:1 ;
          let%bind () = reorg t [ valid_forever ] removed_commands in
          (* expired_command should not be in the pool because they are expired
             and (List.nth few_now 0) because it was committed in a block
          *)
          assert_pool_txs t
            ( expires_later1 :: expires_later2 :: unexpired_zkapp
            :: List.drop few_now 2 ) ;
          (* after 5 block times there should be no expired transactions *)
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 5L))
          in
          let%bind () = reorg t [] [] in
          assert_pool_txs t (List.drop few_now 2) ;
          Deferred.unit )

    let%test_unit "Aged-based expiry (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let expiry = Time_ns.Span.of_sec 1. in
          let%bind t = setup_test ~expiry () in
          assert_pool_txs t [] ;
          let account_update_transfer =
            mk_transfer_zkapp_command ~fee_payer_idx:(0, 0) ~sender_idx:1
              ~receiver_idx:9 ~fee:minimum_fee ~amount:10_000_000_000 ~nonce:0
              ()
          in
          let valid_commands = [ account_update_transfer ] in
          let%bind () = add_commands' t valid_commands in
          assert_pool_txs t valid_commands ;
          let%bind () = after (Time.Span.of_sec 2.) in
          let%bind () = reorg t [] [] in
          assert_pool_txs t [] ; Deferred.unit )

    let%test_unit "Now-invalid transactions are removed from the pool when the \
                   transition frontier is recreated (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          (* Set up initial frontier *)
          let%bind t = setup_test () in
          assert_pool_txs t [] ;
          let%bind _ = add_commands t independent_cmds in
          assert_pool_txs t independent_cmds ;
          (* Destroy initial frontier *)
          Broadcast_pipe.Writer.close t.best_tip_diff_w ;
          let%bind _ = Broadcast_pipe.Writer.write t.frontier_pipe_w None in
          (* Set up second frontier *)
          let ((_, ledger_ref2) as frontier2), _best_tip_diff_w2 =
            Mock_transition_frontier.create ()
          in
          modify_ledger !ledger_ref2 ~idx:0 ~balance:20_000_000_000_000 ~nonce:5 ;
          modify_ledger !ledger_ref2 ~idx:1 ~balance:0 ~nonce:0 ;
          modify_ledger !ledger_ref2 ~idx:2 ~balance:0 ~nonce:1 ;
          let%bind _ =
            Broadcast_pipe.Writer.write t.frontier_pipe_w (Some frontier2)
          in
          assert_pool_txs t (List.drop independent_cmds 3) ;
          Deferred.unit )

    let%test_unit "transaction replacement works" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind t = setup_test () in
      let set_sender idx (tx : Signed_command.t) =
        let sender_kp = test_keys.(idx) in
        let sender_pk = Public_key.compress sender_kp.public_key in
        let payload : Signed_command.Payload.t =
          match tx.payload with
          | { common; body = Payment payload } ->
              { common = { common with fee_payer_pk = sender_pk }
              ; body = Payment { payload with source_pk = sender_pk }
              }
          | { common; body = Stake_delegation (Set_delegate payload) } ->
              { common = { common with fee_payer_pk = sender_pk }
              ; body =
                  Stake_delegation
                    (Set_delegate { payload with delegator = sender_pk })
              }
        in
        User_command.Signed_command (Signed_command.sign sender_kp payload)
      in
      let txs0 =
        [ mk_payment' ~sender_idx:0 ~fee:minimum_fee ~nonce:0 ~receiver_idx:9
            ~amount:20_000_000_000 ()
        ; mk_payment' ~sender_idx:0 ~fee:minimum_fee ~nonce:1 ~receiver_idx:9
            ~amount:12_000_000_000 ()
        ; mk_payment' ~sender_idx:0 ~fee:minimum_fee ~nonce:2 ~receiver_idx:9
            ~amount:500_000_000_000 ()
        ]
      in
      let txs0' = List.map txs0 ~f:Signed_command.forget_check in
      let txs1 = List.map ~f:(set_sender 1) txs0' in
      let txs2 = List.map ~f:(set_sender 2) txs0' in
      let txs3 = List.map ~f:(set_sender 3) txs0' in
      let txs_all =
        List.map ~f:(fun x -> User_command.Signed_command x) txs0
        @ txs1 @ txs2 @ txs3
      in
      Core.Printf.printf !"PHASE 1\n%!" ;
      let%bind () = add_commands' t txs_all in
      assert_pool_txs t txs_all ;
      let replace_txs =
        [ (* sufficient fee *)
          mk_payment ~sender_idx:0
            ~fee:(minimum_fee + Currency.Fee.to_int Indexed_pool.replace_fee)
            ~nonce:0 ~receiver_idx:1 ~amount:440_000_000_000 ()
        ; (* insufficient fee *)
          mk_payment ~sender_idx:1 ~fee:minimum_fee ~nonce:0 ~receiver_idx:1
            ~amount:788_000_000_000 ()
        ; (* sufficient *)
          mk_payment ~sender_idx:2
            ~fee:(minimum_fee + Currency.Fee.to_int Indexed_pool.replace_fee)
            ~nonce:1 ~receiver_idx:4 ~amount:721_000_000_000 ()
        ; (* insufficient *)
          (let amount = 927_000_000_000 in
           let fee =
             let ledger = !(t.best_tip_ref) in
             let sender_kp = test_keys.(3) in
             let sender_pk = Public_key.compress sender_kp.public_key in
             let sender_aid = Account_id.create sender_pk Token_id.default in
             let location =
               Mock_base_ledger.location_of_account ledger sender_aid
               |> Option.value_exn
             in
             (* Spend all of the tokens in the account. Should fail because the
                command with nonce=0 will already have spent some.
             *)
             let account =
               Mock_base_ledger.get ledger location |> Option.value_exn
             in
             Currency.Balance.to_int account.balance - amount
           in
           mk_payment ~sender_idx:3 ~fee ~nonce:1 ~receiver_idx:4 ~amount () )
        ]
      in
      Core.Printf.printf !"PHASE 2\n%!" ;
      add_commands t replace_txs
      >>| assert_pool_apply
            [ List.nth_exn replace_txs 0; List.nth_exn replace_txs 2 ]

    let%test_unit "it drops queued transactions if a committed one makes there \
                   be insufficient funds" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind t = setup_test () in
      let txs =
        [ mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:0 ~receiver_idx:9
            ~amount:20_000_000_000 ()
        ; mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:1 ~receiver_idx:5
            ~amount:77_000_000_000 ()
        ; mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:2 ~receiver_idx:3
            ~amount:891_000_000_000 ()
        ]
      in
      let committed_tx =
        mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:0 ~receiver_idx:2
          ~amount:25_000_000_000 ()
      in
      let%bind () = add_commands' t txs in
      assert_pool_txs t txs ;
      modify_ledger !(t.best_tip_ref) ~idx:0 ~balance:970_000_000_000 ~nonce:1 ;
      let%bind () = reorg t [ committed_tx ] [] in
      assert_pool_txs t [ List.nth_exn txs 1 ] ;
      Deferred.unit

    let%test_unit "max size is maintained" =
      Quickcheck.test ~trials:500
        (let open Quickcheck.Generator.Let_syntax in
        let%bind init_ledger_state =
          Mina_ledger.Ledger.gen_initial_ledger_state
        in
        let%bind cmds_count = Int.gen_incl pool_max_size (pool_max_size * 2) in
        let%bind cmds =
          User_command.Valid.Gen.sequence ~sign_type:`Real ~length:cmds_count
            init_ledger_state
        in
        return (init_ledger_state, cmds))
        ~f:(fun (init_ledger_state, cmds) ->
          Thread_safe.block_on_async_exn (fun () ->
              let%bind t = setup_test () in
              let new_ledger =
                Mina_ledger.Ledger.create_ephemeral
                  ~depth:(Mina_ledger.Ledger.depth !(t.best_tip_ref))
                  ()
              in
              Mina_ledger.Ledger.apply_initial_ledger_state new_ledger
                init_ledger_state ;
              t.best_tip_ref := new_ledger ;
              let%bind () = reorg ~reorg_best_tip:true t [] [] in
              let cmds1, cmds2 = List.split_n cmds pool_max_size in
              let%bind apply_res1 = add_commands t cmds1 in
              assert (Result.is_ok apply_res1) ;
              [%test_eq: int] pool_max_size (Indexed_pool.size t.txn_pool.pool) ;
              let%map _apply_res2 = add_commands t cmds2 in
              (* N.B. Adding a transaction when the pool is full may drop > 1
                 command, so the size now is not necessarily the maximum.
                 Applying the diff may also return an error if none of the new
                 commands have higher fee than the lowest one already in the
                 pool.
              *)
              assert (Indexed_pool.size t.txn_pool.pool <= pool_max_size) ) )

    let assert_rebroadcastable test cmds =
      let expected =
        if List.is_empty cmds then []
        else
          [ List.map cmds
              ~f:
                (Fn.compose Transaction_hash.User_command.create
                   User_command.forget_check )
          ]
      in
      let actual =
        Test.Resource_pool.get_rebroadcastable test.txn_pool
          ~has_timed_out:(Fn.const `Ok)
        |> List.map ~f:(List.map ~f:Transaction_hash.User_command.create)
      in
      if List.length actual > 1 then
        failwith "unexpected number of rebroadcastable diffs" ;

      List.iter (List.zip_exn actual expected) ~f:(fun (a, b) ->
          assert_user_command_sets_equal a b )

    let mk_rebroadcastable_test t cmds =
      assert_pool_txs t [] ;
      assert_rebroadcastable t [] ;
      (* Locally generated transactions are rebroadcastable *)
      let%bind () = add_commands' ~local:true t (List.take cmds 2) in
      assert_pool_txs t (List.take cmds 2) ;
      assert_rebroadcastable t (List.take cmds 2) ;
      (* Adding non-locally-generated transactions doesn't affect
         rebroadcastable pool *)
      let%bind () = add_commands' ~local:false t (List.slice cmds 2 5) in
      assert_pool_txs t (List.take cmds 5) ;
      assert_rebroadcastable t (List.take cmds 2) ;
      (* When locally generated transactions are committed they are no
         longer rebroadcastable *)
      let%bind () = add_commands' ~local:true t (List.slice cmds 5 7) in
      let%bind checkpoint_1 = commit_commands' t (List.take cmds 1) in
      let%bind checkpoint_2 = commit_commands' t (List.slice cmds 1 5) in
      let%bind () = reorg t (List.take cmds 5) [] in
      assert_pool_txs t (List.slice cmds 5 7) ;
      assert_rebroadcastable t (List.slice cmds 5 7) ;
      (* Reorgs put locally generated transactions back into the
         rebroadcastable pool, if they were removed and not re-added *)
      (* restore up to after the application of the first command *)
      t.best_tip_ref := checkpoint_2 ;
      (* reorge both removes and re-adds the first command (which is local) *)
      let%bind () = reorg t (List.take cmds 1) (List.take cmds 5) in
      assert_pool_txs t (List.slice cmds 1 7) ;
      assert_rebroadcastable t (List.nth_exn cmds 1 :: List.slice cmds 5 7) ;
      (* Committing them again removes them from the pool again. *)
      commit_commands t (List.slice cmds 1 7) ;
      let%bind () = reorg t (List.slice cmds 1 7) [] in
      assert_pool_txs t [] ;
      assert_rebroadcastable t [] ;
      (* When transactions expire from rebroadcast pool they are gone. This
         doesn't affect the main pool.
      *)
      t.best_tip_ref := checkpoint_1 ;
      let%bind () = reorg t [] (List.take cmds 7) in
      assert_pool_txs t (List.take cmds 7) ;
      assert_rebroadcastable t (List.take cmds 2 @ List.slice cmds 5 7) ;
      ignore
        ( Test.Resource_pool.get_rebroadcastable t.txn_pool
            ~has_timed_out:(Fn.const `Timed_out)
          : User_command.t list list ) ;
      assert_rebroadcastable t [] ;
      Deferred.unit

    let%test_unit "rebroadcastable transaction behavior (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_rebroadcastable_test test independent_cmds )

    let%test_unit "rebroadcastable transaction behavior (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_command_cmds test.txn_pool >>= mk_rebroadcastable_test test )

    let%test_unit "apply user cmds and zkapps" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind t = setup_test () in
          let num_cmds = Array.length test_keys in
          (* the user cmds and snapp cmds are taken from the same list of keys,
             so splitting by the order from that list makes sure that they
             don't share fee payer keys
             therefore, the original nonces in the accounts are valid
          *)
          let take_len = num_cmds / 2 in
          let%bind snapp_cmds =
            let%map cmds = mk_zkapp_command_cmds t.txn_pool in
            List.take cmds take_len
          in
          let user_cmds = List.drop independent_cmds take_len in
          let all_cmds = snapp_cmds @ user_cmds in
          assert_pool_txs t [] ;
          let%bind () = add_commands' t all_cmds in
          assert_pool_txs t all_cmds ; Deferred.unit )
  end )
