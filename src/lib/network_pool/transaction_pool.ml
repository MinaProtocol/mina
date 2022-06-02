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
open Signature_lib
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
          | Verification_failed
          | Duplicate
          | Sender_account_does_not_exist
          | Invalid_nonce
          | Insufficient_funds
          | Insufficient_fee
          | Overflow
          | Bad_token
          | Unwanted_fee_token
          | Expired
          | Overloaded
          | Fee_payer_account_not_found
        [@@deriving sexp, yojson, compare]

        let to_latest = Fn.id
      end
    end]

    (* IMPORTANT! Do not change the names of these errors as to adjust the
     * to_yojson output without updating Rosetta's construction API to handle
     * the changes *)
    type t = Stable.Latest.t =
      | Insufficient_replace_fee
      | Verification_failed
      | Duplicate
      | Sender_account_does_not_exist
      | Invalid_nonce
      | Insufficient_funds
      | Insufficient_fee
      | Overflow
      | Bad_token
      | Unwanted_fee_token
      | Expired
      | Overloaded
      | Fee_payer_account_not_found
    [@@deriving sexp, yojson]

    let to_string_name = function
      | Insufficient_replace_fee ->
          "insufficient_replace_fee"
      | Verification_failed ->
          "verification_failed"
      | Duplicate ->
          "duplicate"
      | Sender_account_does_not_exist ->
          "sender_account_does_not_exist"
      | Invalid_nonce ->
          "invalid_nonce"
      | Insufficient_funds ->
          "insufficient_funds"
      | Insufficient_fee ->
          "insufficient_fee"
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

    let to_string_hum = function
      | Insufficient_replace_fee ->
          "This transaction would have replaced an existing transaction in the \
           pool, but the fee was too low"
      | Verification_failed ->
          "This transaction had an invalid proof/signature"
      | Duplicate ->
          "This transaction is a duplicate of one already in the pool"
      | Sender_account_does_not_exist ->
          "The fee-payer's account for this transaction could not be found in \
           the ledger"
      | Invalid_nonce ->
          "This transaction had an invalid nonce"
      | Insufficient_funds ->
          "There are not enough funds in the fee-payer's account to execute \
           this transaction"
      | Insufficient_fee ->
          "The fee for this transaction is too low"
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

  type verified =
    { accepted :
        ( ( Transaction_hash.User_command_with_valid_signature.t
          * Transaction_hash.User_command_with_valid_signature.t list )
          list
        * Indexed_pool.Sender_local_state.t
        * Indexed_pool.Update.t )
        list
    ; rejected : Rejected.t
    }
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

    module Config = struct
      type t =
        { trust_system : (Trust_system.t[@sexp.opaque])
        ; pool_max_size : int
              (* note this value needs to be mostly the same across gossipping nodes, so
                 nodes with larger pools don't send nodes with smaller pools lots of
                 low fee transactions the smaller-pooled nodes consider useless and get
                 themselves banned.
              *)
        ; verifier : (Verifier.t[@sexp.opaque])
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
      ; sender_mutex : (Mutex.t Account_id.Table.t[@sexp.opaque])
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

    let transactions' ~logger p =
      Sequence.unfold ~init:p ~f:(fun pool ->
          match Indexed_pool.get_highest_fee pool with
          | Some cmd -> (
              match
                Indexed_pool.handle_committed_txn pool
                  cmd
                  (* we have the invariant that the transactions currently
                     in the pool are always valid against the best tip, so
                     no need to check balances here *)
                  ~fee_payer_balance:Currency.Amount.max_int
                  ~fee_payer_nonce:
                    ( Transaction_hash.User_command_with_valid_signature.command
                        cmd
                    |> User_command.nonce_exn )
              with
              | Ok (t, _) ->
                  Some (cmd, t)
              | Error (`Queued_txns_by_sender (error_str, queued_cmds)) ->
                  [%log error]
                    "Error handling committed transaction $cmd: $error "
                    ~metadata:
                      [ ( "cmd"
                        , Transaction_hash.User_command_with_valid_signature
                          .to_yojson cmd )
                      ; ("error", `String error_str)
                      ; ( "queue"
                        , `List
                            (List.map (Sequence.to_list queued_cmds)
                               ~f:(fun c ->
                                 Transaction_hash
                                 .User_command_with_valid_signature
                                 .to_yojson c ) ) )
                      ] ;
                  failwith error_str )
          | None ->
              None )

    let transactions ~logger t = transactions' ~logger t.pool

    let all_from_account { pool; _ } = Indexed_pool.all_from_account pool

    let get_all { pool; _ } = Indexed_pool.get_all pool

    let find_by_hash { pool; _ } hash = Indexed_pool.find_by_hash pool hash

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
      | Verification_failed ->
          Verification_failed
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
      | Verification_failed ->
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

    let balance_of_account ~global_slot (account : Account.t) =
      match account.timing with
      | Untimed ->
          account.balance
      | Timed
          { initial_minimum_balance
          ; cliff_time
          ; cliff_amount
          ; vesting_period
          ; vesting_increment
          } ->
          Currency.Balance.sub_amount account.balance
            (Currency.Balance.to_amount
               (Account.min_balance_at_slot ~global_slot ~cliff_time
                  ~cliff_amount ~vesting_period ~vesting_increment
                  ~initial_minimum_balance ) )
          |> Option.value ~default:Currency.Balance.zero

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
        Sequence.fold
          ( removed_commands |> List.rev |> Sequence.of_list
          |> Sequence.map ~f:(fun unchecked ->
                 unchecked.data
                 |> Transaction_hash.User_command_with_valid_signature.create )
          )
          ~init:(t.pool, Sequence.empty)
          ~f:(fun (pool, dropped_so_far) cmd ->
            ( match
                Hashtbl.find_and_remove t.locally_generated_committed cmd
              with
            | None ->
                ()
            | Some time_added ->
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
      let pool'', dropped_commit_conflicts =
        List.fold new_commands ~init:(pool', Sequence.empty)
          ~f:(fun (p, dropped_so_far) cmd ->
            let balance account_id =
              match
                Base_ledger.location_of_account best_tip_ledger account_id
              with
              | None ->
                  (Currency.Amount.zero, Mina_base.Account.Nonce.zero)
              | Some loc ->
                  let acc =
                    Option.value_exn
                      ~message:"public key has location but no account"
                      (Base_ledger.get best_tip_ledger loc)
                  in
                  ( Currency.Balance.to_amount
                      (balance_of_account ~global_slot acc)
                  , acc.nonce )
            in
            let fee_payer = User_command.(fee_payer (forget_check cmd.data)) in
            let fee_payer_balance, fee_payer_nonce = balance fee_payer in
            let cmd' =
              Transaction_hash.User_command_with_valid_signature.create cmd.data
            in
            ( match
                Hashtbl.find_and_remove t.locally_generated_uncommitted cmd'
              with
            | None ->
                ()
            | Some time_added ->
                [%log' info t.logger]
                  "Locally generated command $cmd committed in a block!"
                  ~metadata:
                    [ ( "cmd"
                      , With_status.to_yojson User_command.Valid.to_yojson cmd
                      )
                    ] ;
                Hashtbl.add_exn t.locally_generated_committed ~key:cmd'
                  ~data:time_added ) ;
            let p', dropped =
              match
                Indexed_pool.handle_committed_txn p cmd' ~fee_payer_balance
                  ~fee_payer_nonce
              with
              | Ok res ->
                  res
              | Error (`Queued_txns_by_sender (error_str, queued_cmds)) ->
                  [%log' error t.logger]
                    "Error handling committed transaction $cmd: $error "
                    ~metadata:
                      [ ( "cmd"
                        , With_status.to_yojson User_command.Valid.to_yojson cmd
                        )
                      ; ("error", `String error_str)
                      ; ( "queue"
                        , `List
                            (List.map (Sequence.to_list queued_cmds)
                               ~f:(fun c ->
                                 Transaction_hash
                                 .User_command_with_valid_signature
                                 .to_yojson c ) ) )
                      ] ;
                  failwith error_str
            in
            (p', Sequence.append dropped_so_far dropped) )
      in
      let commit_conflicts_locally_generated =
        Sequence.filter dropped_commit_conflicts ~f:(fun cmd ->
            Hashtbl.find_and_remove t.locally_generated_uncommitted cmd
            |> Option.is_some )
      in
      if not @@ Sequence.is_empty commit_conflicts_locally_generated then
        [%log' info t.logger]
          "Locally generated commands $cmds dropped because they conflicted \
           with a committed command."
          ~metadata:
            [ ( "cmds"
              , `List
                  (Sequence.to_list
                     (Sequence.map commit_conflicts_locally_generated
                        ~f:
                          Transaction_hash.User_command_with_valid_signature
                          .to_yojson ) ) )
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
                    Indexed_pool.add_from_gossip_exn t.pool (`Checked cmd)
                      acct.nonce
                      ~verify:(fun _ -> assert false)
                      ( balance_of_account ~global_slot acct
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
        ; sender_mutex = Account_id.Table.create ()
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
                   Indexed_pool.revalidate t.pool (fun sender ->
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
                           , balance_of_account ~global_slot acc
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
          | Insufficient_replace_fee
          | Verification_failed
          | Duplicate
          | Sender_account_does_not_exist
          | Invalid_nonce
          | Insufficient_funds
          | Insufficient_fee
          | Overflow
          | Bad_token
          | Unwanted_fee_token
          | Expired
          | Overloaded
          | Fee_payer_account_not_found
        [@@deriving sexp, yojson, compare]

        let to_string_hum = Diff_versioned.Diff_error.to_string_hum
      end

      module Rejected = struct
        type t = (User_command.t * Diff_error.t) list
        [@@deriving sexp, yojson, compare]

        type _unused = unit constraint t = Diff_versioned.Rejected.t
      end

      type rejected = Rejected.t [@@deriving sexp, yojson, compare]

      type verified = Diff_versioned.verified =
        { accepted :
            ( ( Transaction_hash.User_command_with_valid_signature.t
              * Transaction_hash.User_command_with_valid_signature.t list )
              list
            * Indexed_pool.Sender_local_state.t
            * Indexed_pool.Update.t )
            list
        ; rejected : Rejected.t
        }
      [@@deriving sexp, to_yojson]

      let reject_overloaded_diff (diffs : verified) : rejected =
        diffs.rejected
        @ List.concat_map diffs.accepted ~f:(fun (cmds, _, _) ->
              List.map cmds ~f:(fun (c, _) ->
                  ( Transaction_hash.User_command_with_valid_signature.command c
                  , Diff_error.Overloaded ) ) )

      let verified_accepted ({ accepted; _ } : verified) =
        List.concat_map accepted ~f:(fun (cs, _, _) ->
            List.map cs ~f:(fun (c, _) ->
                Transaction_hash.User_command_with_valid_signature.command c ) )

      let verified_rejected ({ rejected; _ } : verified) : rejected = rejected

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
          (* TODO: Make this error more specific (could also be a bad signature. *)
          trust_record
            ( Trust_system.Actions.Sent_invalid_proof
            , Some ("Error verifying transaction pool diff: $error", metadata)
            )
        else Deferred.return ()

      let of_indexed_pool_error e =
        (diff_error_of_indexed_pool_error e, indexed_pool_error_metadata e)

      let handle_command_error t ~trust_record ~is_sender_local tx
          (e : Indexed_pool.Command_error.t) =
        let yojson_fail_reason =
          Fn.compose
            (fun s -> `String s)
            (function
              | Indexed_pool.Command_error.Invalid_nonce _ ->
                  "invalid nonce"
              | Insufficient_funds _ ->
                  "insufficient funds"
              | Verification_failed ->
                  "transaction had bad proof/signature or was malformed"
              | Insufficient_replace_fee _ ->
                  "insufficient replace fee"
              | Overflow ->
                  "overflow"
              | Bad_token ->
                  "bad token"
              | Unwanted_fee_token _ ->
                  "unwanted fee token"
              | Expired _ ->
                  "expired" )
        in
        let open Async in
        let%map () =
          match e with
          | Insufficient_replace_fee (`Replace_fee rfee, fee) ->
              (* We can't punish peers for this, since an
                  attacker can simultaneously send different
                  transactions at the same nonce to different
                  nodes, which will then naturally gossip them.
              *)
              let f_log =
                if is_sender_local then [%log' error t.logger]
                else [%log' debug t.logger]
              in
              f_log
                "rejecting $cmd because of insufficient replace fee ($rfee > \
                 $fee)"
                ~metadata:
                  [ ("cmd", User_command.to_yojson tx)
                  ; ("rfee", Currency.Fee.to_yojson rfee)
                  ; ("fee", Currency.Fee.to_yojson fee)
                  ] ;
              Deferred.unit
          | Unwanted_fee_token fee_token ->
              (* We can't punish peers for this, since these
                    are our specific preferences.
              *)
              let f_log =
                if is_sender_local then [%log' error t.logger]
                else [%log' debug t.logger]
              in
              f_log "rejecting $cmd because we don't accept fees in $token"
                ~metadata:
                  [ ("cmd", User_command.to_yojson tx)
                  ; ("token", Token_id.to_yojson fee_token)
                  ] ;
              Deferred.unit
          | Verification_failed ->
              trust_record
                ( Trust_system.Actions.Sent_useless_gossip
                , Some
                    ( "rejecting command because had invalid signature or was \
                       malformed"
                    , [] ) )
          | err ->
              let diff_err, error_extra = of_indexed_pool_error err in
              if is_sender_local then
                [%str_log' error t.logger]
                  (Rejecting_command_for_reason
                     { command = tx; reason = diff_err; error_extra } ) ;
              trust_record
                ( Trust_system.Actions.Sent_useless_gossip
                , Some
                    ( "rejecting $cmd because of $reason. ($error_extra)"
                    , [ ("cmd", User_command.to_yojson tx)
                      ; ("reason", yojson_fail_reason err)
                      ; ("error_extra", `Assoc error_extra)
                      ] ) )
        in
        if Indexed_pool.Command_error.grounds_for_diff_rejection e then `Reject
        else `Ignore

      let verify' ~allow_failures_for_tests (t : pool)
          (diffs : t Envelope.Incoming.t) :
          verified Envelope.Incoming.t Deferred.Or_error.t =
        let open Deferred.Let_syntax in
        let trust_record =
          Trust_system.record_envelope_sender t.config.trust_system t.logger
            diffs.sender
        in
        let config = Indexed_pool.config t.pool in
        let global_slot = Indexed_pool.global_slot_since_genesis t.pool in
        let pool_max_size = t.config.pool_max_size in
        let sender = Envelope.Incoming.sender diffs in
        let is_sender_local = Envelope.Sender.(equal sender Local) in
        let diffs_are_valid () =
          List.for_all (Envelope.Incoming.data diffs) ~f:(fun cmd ->
              let is_valid = not (User_command.has_insufficient_fee cmd) in
              if not is_valid then
                [%log' debug t.logger]
                  "Filtering user command with insufficient fee from \
                   transaction-pool diff $cmd from $sender"
                  ~metadata:
                    [ ("cmd", User_command.to_yojson cmd)
                    ; ( "sender"
                      , Envelope.(Sender.to_yojson (Incoming.sender diffs)) )
                    ] ;
              is_valid )
        in
        let h = Lru_cache.T.hash diffs.data in
        let (`Already_mem already_mem) = Lru_cache.add t.recently_seen h in
        if (not allow_failures_for_tests) && already_mem && not is_sender_local
        then
          (* We only reject here if the command was from the network: the user
             may want to re-issue a transaction if it is no longer being
             rebroadcast but also never made it into a block for some reason.
          *)
          Deferred.Or_error.error_string "already saw this"
        else if (not allow_failures_for_tests) && not (diffs_are_valid ()) then
          Deferred.Or_error.error_string
            "at least one user command had an insufficient fee"
        else
          match t.best_tip_ledger with
          | None ->
              Deferred.Or_error.error_string
                "We don't have a transition frontier at the moment, so we're \
                 unable to verify any transactions."
          | Some ledger -> (
              let data' =
                List.map diffs.data
                  ~f:
                    (User_command.to_verifiable ~ledger ~get:Base_ledger.get
                       ~location_of_account:Base_ledger.location_of_account )
              in
              let by_sender =
                List.fold data' ~init:Account_id.Map.empty
                  ~f:(fun by_sender c ->
                    Map.add_multi by_sender
                      ~key:(User_command.Verifiable.fee_payer c)
                      ~data:c )
                |> Map.map ~f:List.rev |> Map.to_alist
              in
              let failures = ref (Ok ()) in
              let add_failure err =
                match !failures with
                | Ok () ->
                    failures := Error [ err ]
                | Error errs ->
                    failures := Error (err :: errs)
              in
              let%map diffs' =
                Deferred.List.map by_sender ~how:`Parallel
                  ~f:(fun (signer, cs) ->
                    let account =
                      Option.bind
                        (Base_ledger.location_of_account ledger signer)
                        ~f:(Base_ledger.get ledger)
                    in
                    match account with
                    | None ->
                        let%map _ =
                          trust_record
                            ( Trust_system.Actions.Sent_useless_gossip
                            , Some
                                ( "account does not exist for id: $account_id"
                                , [ ("account_id", Account_id.to_yojson signer)
                                  ] ) )
                        in
                        add_failure
                          (Command_failure
                             Diff_error.Fee_payer_account_not_found ) ;
                        Error `Invalid_command
                    | Some account ->
                        let signer_lock =
                          Hashtbl.find_or_add t.sender_mutex signer
                            ~default:Mutex.create
                        in
                        (*This lock is released in apply function unless
                          there's an error that causes all the transactions from
                          this signer to be discarded*)
                        let%bind () = Mutex.acquire signer_lock in
                        let rec go sender_local_state u_acc acc
                            (rejected : Rejected.t) = function
                          | [] ->
                              (* We keep the signer lock until this verified diff is applied. *)
                              return
                                (Ok
                                   ( List.rev acc
                                   , List.rev rejected
                                   , sender_local_state
                                   , u_acc ) )
                          | c :: cs ->
                              let uc = User_command.of_verifiable c in
                              if Result.is_error !failures then (
                                Mutex.release signer_lock ;
                                return (Error `Other_command_failed) )
                              else
                                let tx' =
                                  Transaction_hash.User_command.create uc
                                in
                                if Indexed_pool.member t.pool tx' then
                                  if is_sender_local then (
                                    [%log' info t.logger]
                                      "Received local $cmd already present in \
                                       the pool"
                                      ~metadata:
                                        [ ("cmd", User_command.to_yojson uc) ] ;
                                    match
                                      Indexed_pool.find_by_hash t.pool
                                        (Transaction_hash.User_command.hash tx')
                                    with
                                    | Some validated_uc ->
                                        go sender_local_state
                                          Indexed_pool.Update.empty
                                          ((validated_uc, []) :: acc)
                                          rejected cs
                                    | None ->
                                        (*We just checked for membership, fail?*)
                                        go sender_local_state u_acc acc
                                          ( ( uc
                                            , Diff_versioned.Diff_error
                                              .Duplicate )
                                          :: rejected )
                                          cs )
                                  else
                                    let%bind _ =
                                      trust_record
                                        ( Trust_system.Actions.Sent_old_gossip
                                        , None )
                                    in
                                    go sender_local_state u_acc acc
                                      ( (uc, Diff_versioned.Diff_error.Duplicate)
                                      :: rejected )
                                      cs
                                else if
                                  has_sufficient_fee t.pool ~pool_max_size uc
                                then
                                  match%bind
                                    Indexed_pool.add_from_gossip_exn_async
                                      ~config ~sender_local_state
                                      ~verify:(fun c ->
                                        match%map
                                          Batcher.verify t.batcher
                                            { diffs with data = [ c ] }
                                        with
                                        | Error e ->
                                            [%log' error t.logger]
                                              "Transaction verification error: \
                                               $error"
                                              ~metadata:
                                                [ ( "error"
                                                  , `String
                                                      (Error.to_string_hum e) )
                                                ] ;
                                            None
                                        | Ok (Error invalid) ->
                                            [%log' error t.logger]
                                              "Batch verification failed when \
                                               adding from gossip"
                                              ~metadata:
                                                [ ( "error"
                                                  , `String
                                                      (Verifier
                                                       .invalid_to_string
                                                         invalid ) )
                                                ] ;
                                            add_failure (Invalid_failure invalid) ;
                                            None
                                        | Ok (Ok [ c ]) ->
                                            Some c
                                        | Ok (Ok _) ->
                                            assert false )
                                      (`Unchecked
                                        ( Transaction_hash.User_command.create uc
                                        , c ) )
                                      account.nonce
                                      (Currency.Balance.to_amount
                                         (balance_of_account ~global_slot
                                            account ) )
                                  with
                                  | Error e -> (
                                      match%bind
                                        handle_command_error t ~trust_record
                                          ~is_sender_local uc e
                                      with
                                      | `Reject ->
                                          add_failure
                                            (Command_failure
                                               (diff_error_of_indexed_pool_error
                                                  e ) ) ;
                                          Mutex.release signer_lock ;
                                          return (Error `Invalid_command)
                                      | `Ignore ->
                                          go sender_local_state u_acc acc
                                            ( ( uc
                                              , diff_error_of_indexed_pool_error
                                                  e )
                                            :: rejected )
                                            cs )
                                  | Ok (res, sender_local_state, u) ->
                                      let%bind _ =
                                        trust_record
                                          ( Trust_system.Actions
                                            .Sent_useful_gossip
                                          , Some
                                              ( "$cmd"
                                              , [ ( "cmd"
                                                  , User_command.to_yojson uc )
                                                ] ) )
                                      in
                                      go sender_local_state
                                        (Indexed_pool.Update.merge u_acc u)
                                        (res :: acc) rejected cs
                                else
                                  let%bind () =
                                    trust_record
                                      ( Trust_system.Actions.Sent_useless_gossip
                                      , Some
                                          ( sprintf
                                              "rejecting command $cmd due to \
                                               insufficient fee."
                                          , [ ("cmd", User_command.to_yojson uc)
                                            ] ) )
                                  in
                                  go sender_local_state u_acc acc
                                    ((uc, Insufficient_fee) :: rejected)
                                    cs
                        in
                        go
                          (Indexed_pool.get_sender_local_state t.pool signer)
                          Indexed_pool.Update.empty [] [] cs )
              in
              match !failures with
              | Error errs when not allow_failures_for_tests ->
                  let errs_string =
                    List.map errs ~f:(fun err ->
                        match err with
                        | Command_failure cmd_err ->
                            Yojson.Safe.to_string (Diff_error.to_yojson cmd_err)
                        | Invalid_failure invalid ->
                            Verifier.invalid_to_string invalid )
                    |> String.concat ~sep:", "
                  in
                  Or_error.errorf "Diff failed with verification failure(s): %s"
                    errs_string
              | Error _ | Ok () ->
                  let data =
                    List.filter_map diffs' ~f:(function
                      | Error (`Invalid_command | `Other_command_failed) ->
                          (* `Invalid_command should be handled in the Error
                             case above and `Other_command_failed should be
                             triggered only if there's an `Invalid_command*)
                          assert false
                      | Error `Account_not_found ->
                          (* We can just skip this set of commands *)
                          None
                      | Ok t ->
                          Some t )
                  in
                  let data : verified =
                    { accepted =
                        List.map data ~f:(fun (cs, _rej, local_state, u) ->
                            (cs, local_state, u) )
                    ; rejected =
                        List.concat_map data ~f:(fun (_, rej, _, _) -> rej)
                    }
                  in
                  Ok { diffs with data } )

      (** The function checks proofs and signatures in the diffs and applies
      valid diffs to the local sender state (sequence of transactions from the
      pool) for each sender/fee-payer. The local sender state is then included
      in the verified diff returned by this function which will be committed to
      the transaction pool in the apply function*)
      let verify (t : pool) (diffs : t Envelope.Incoming.t) :
          verified Envelope.Incoming.t Deferred.Or_error.t =
        verify' ~allow_failures_for_tests:false t diffs

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

      let apply t (env : verified Envelope.Incoming.t) =
        let module Cs = struct
          type t = Transaction_hash.User_command_with_valid_signature.t list
          [@@deriving to_yojson]
        end in
        let sender = Envelope.Incoming.sender env in
        let is_sender_local = Envelope.Sender.(equal sender Local) in
        let pool_max_size = t.config.pool_max_size in
        let check_dropped dropped =
          let locally_generated_dropped =
            Sequence.filter dropped ~f:(fun tx_dropped ->
                Hashtbl.find_and_remove t.locally_generated_uncommitted
                  tx_dropped
                |> Option.is_some )
            |> Sequence.to_list
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
                ]
        in
        let pool, add_results =
          let open Indexed_pool in
          List.fold_map ~init:t.pool env.data.accepted
            ~f:(fun acc (cs, local_state, u) ->
              let sender = Sender_local_state.sender local_state in
              Option.iter (Hashtbl.find t.sender_mutex sender) ~f:Mutex.release ;
              if Sender_local_state.is_remove local_state then
                Hashtbl.remove t.sender_mutex sender ;
              (set_sender_local_state acc local_state |> Update.apply u, cs) )
        in
        let add_results = List.concat add_results in
        let pool, dropped_for_size =
          drop_until_below_max_size pool ~pool_max_size
        in
        if not (Sequence.is_empty dropped_for_size) then
          [%log' debug t.logger] "dropped commands to maintain max size: $cmds"
            ~metadata:
              [ ("cmds", Cs.to_yojson (Sequence.to_list dropped_for_size)) ] ;
        check_dropped dropped_for_size ;
        t.pool <- pool ;
        Mina_metrics.(
          Gauge.set Transaction_pool.pool_size
            (Float.of_int (Indexed_pool.size pool)) ;
          Counter.inc_one Transaction_pool.transactions_added_to_pool) ;
        let trust_record =
          Trust_system.record_envelope_sender t.config.trust_system t.logger
            sender
        in
        let rec go txs =
          let open Interruptible.Deferred_let_syntax in
          match txs with
          | [] ->
              Interruptible.Or_error.return ()
          | (verified, dropped) :: txs ->
              let tx =
                Transaction_hash.User_command_with_valid_signature.command
                  verified
              in
              let tx' = Transaction_hash.User_command.of_checked verified in
              if Indexed_pool.member t.pool tx' then
                if is_sender_local then (
                  [%log' info t.logger]
                    "Rebroadcasting $cmd already present in the pool"
                    ~metadata:[ ("cmd", User_command.to_yojson tx) ] ;
                  register_locally_generated t verified ;
                  go txs )
                else
                  let%bind _ =
                    trust_record (Trust_system.Actions.Sent_old_gossip, None)
                  in
                  go txs
              else (
                if is_sender_local then register_locally_generated t verified ;
                if not (List.is_empty dropped) then
                  [%log' debug t.logger]
                    "dropped commands due to transaction replacement: $dropped"
                    ~metadata:[ ("dropped", Cs.to_yojson dropped) ] ;
                check_dropped (Sequence.of_list dropped) ;
                go txs )
        in
        match t.best_tip_ledger with
        | None ->
            Deferred.Or_error.error_string
              "Got transaction pool diff when transition frontier is \
               unavailable, ignoring."
        | Some ledger -> (
            match%map
              Interruptible.force
              @@
              let open Interruptible.Let_syntax in
              let signal =
                Deferred.map (Base_ledger.detached_signal ledger) ~f:(fun () ->
                    Error.createf "Ledger was detached"
                    |> Error.tag ~tag:"Transaction_pool.apply" )
              in
              let%bind () = Interruptible.lift Deferred.unit signal in
              go add_results
            with
            | Ok res ->
                res
            | Error err ->
                Error err )

      let unsafe_apply (t : pool) (diff : verified Envelope.Incoming.t) :
          (t * rejected, _) Deferred.Result.t =
        match%map apply t diff with
        | Ok () ->
            let accepted = verified_accepted diff.data in
            let rejected = verified_rejected diff.data in
            ( if not (List.is_empty accepted) then
              Mina_metrics.(
                Gauge.set Transaction_pool.useful_transactions_received_time_sec
                  (let x =
                     Time.(now () |> to_span_since_epoch |> Span.to_sec)
                   in
                   x -. Mina_metrics.time_offset_sec )) ) ;
            Ok (accepted, rejected)
        | Error e ->
            Error (`Other e)

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
                 |> User_command.nonce_exn
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
    module Mock_base_ledger = Mocks.Base_ledger
    module Mock_staged_ledger = Mocks.Staged_ledger

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

    let logger = Logger.null ()

    let time_controller = Block_time.Controller.basic ~logger

    let expiry_ns =
      Time_ns.Span.of_hr
        (Float.of_int precomputed_values.genesis_constants.transaction_expiry_hr)

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ()) )

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
        let pipe_r, pipe_w =
          Broadcast_pipe.create
            { new_commands = []; removed_commands = []; reorg_best_tip = false }
        in
        let accounts =
          List.map (Array.to_list test_keys) ~f:(fun kp ->
              let compressed = Public_key.compress kp.public_key in
              let account_id = Account_id.create compressed Token_id.default in
              ( account_id
              , Account.create account_id
                @@ Currency.Balance.of_int 1_000_000_000_000 ) )
        in
        let ledger = Account_id.Table.of_alist_exn accounts in
        ((pipe_r, ref ledger), pipe_w)

      let best_tip (_, best_tip_ref) = !best_tip_ref

      let best_tip_diff_pipe (pipe, _) = pipe
    end

    module Test =
      Make0 (Mock_base_ledger) (Mock_staged_ledger) (Mock_transition_frontier)

    let pool_max_size = 25

    let () =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    (** Assert the invariants of the locally generated command tracking system.
    *)
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
      let txns =
        Test.Resource_pool.transactions pool ~logger |> Sequence.to_list
      in
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
            (User_command.nonce_exn cmd1)
            (User_command.nonce_exn cmd2)
        else
          let get_fee_wu cmd = User_command.fee_per_wu cmd in
          (* descending order of fee/weight *)
          Currency.Fee_rate.compare (get_fee_wu cmd2) (get_fee_wu cmd1)
      in
      assert (List.is_sorted txns ~compare)

    let setup_test ?expiry () =
      let tf, best_tip_diff_w = Mock_transition_frontier.create () in
      let tf_pipe_r, _tf_pipe_w = Broadcast_pipe.create @@ Some tf in
      let trust_system = Trust_system.null () in
      let config =
        Test.Resource_pool.make_config ~trust_system ~pool_max_size ~verifier
      in
      let expiry_ns = match expiry with None -> expiry_ns | Some t -> t in
      let pool_, _, _ =
        Test.create ~config ~logger ~constraint_constants ~consensus_constants
          ~time_controller ~expiry_ns ~frontier_broadcast_pipe:tf_pipe_r
          ~log_gossip_heard:false ~on_remote_push:(Fn.const Deferred.unit)
      in
      let pool = Test.resource_pool pool_ in
      let%map () = Async.Scheduler.yield () in
      ( (fun txs ->
          Indexed_pool.For_tests.assert_invariants pool.pool ;
          assert_locally_generated pool ;
          assert_fee_wu_ordering pool ;
          [%test_eq: User_command.t List.t]
            ( Test.Resource_pool.transactions ~logger pool
            |> Sequence.map
                 ~f:Transaction_hash.User_command_with_valid_signature.command
            |> Sequence.to_list
            |> List.sort ~compare:User_command.compare )
            (List.sort ~compare:User_command.compare txs) )
      , pool
      , best_tip_diff_w
      , tf )

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
              ~max_amount:100_000_000_000 ~fee_range:10_000_000_000 ()
          in
          go (n + 1) (cmd :: cmds)
        else Quickcheck.Generator.return @@ List.rev cmds
      in
      Quickcheck.random_value ~seed:(`Deterministic "constant") (go 0 [])

    let independent_cmds' : User_command.t list =
      List.map independent_cmds ~f:User_command.forget_check

    let mk_parties_cmds (pool : Test.Resource_pool.t) :
        User_command.Valid.t list =
      let best_tip_ledger = Option.value_exn pool.best_tip_ledger in
      let mk_ledger () =
        (* the Snapp generators want a Ledger.t, these tests have Base_ledger.t map, so
           we build the Ledger.t from the map
        *)
        let ledger =
          Mina_ledger.Ledger.create
            ~depth:precomputed_values.constraint_constants.ledger_depth ()
        in
        Account_id.Table.iteri best_tip_ledger
          ~f:(fun ~key:acct_id ~data:acct ->
            match
              Mina_ledger.Ledger.get_or_create_account ledger acct_id acct
            with
            | Error err ->
                failwithf
                  "mk_parties_cmds: error adding account for account id: %s, \
                   error: %s@."
                  (Account_id.to_yojson acct_id |> Yojson.Safe.to_string)
                  (Error.to_string_hum err) ()
            | Ok (`Existed, _) ->
                failwithf
                  "mk_parties_cmds: account for account id already exists: %s@."
                  (Account_id.to_yojson acct_id |> Yojson.Safe.to_string)
                  ()
            | Ok (`Added, _) ->
                () ) ;
        ledger
      in
      let keymap =
        Array.fold (Array.append test_keys extra_keys)
          ~init:Public_key.Compressed.Map.empty
          ~f:(fun map { public_key; private_key } ->
            let key = Public_key.compress public_key in
            Public_key.Compressed.Map.add_exn map ~key ~data:private_key )
      in
      (* ledger that gets updated by the Snapp generators *)
      let ledger = mk_ledger () in
      let rec go n cmds =
        let open Quickcheck.Generator.Let_syntax in
        if n < Array.length test_keys then
          let%bind cmd =
            let fee_payer_keypair = test_keys.(n) in
            let%map (parties : Parties.t) =
              Mina_generators.Parties_generators.gen_parties_from ~keymap
                ~fee_payer_keypair ~ledger ()
            in
            User_command.Parties parties
          in
          go (n + 1) (cmd :: cmds)
        else Quickcheck.Generator.return @@ List.rev cmds
      in
      let result =
        Quickcheck.random_value ~seed:(`Deterministic "parties") (go 0 [])
      in
      (* add new accounts to best tip ledger *)
      let ledger_accounts =
        Mina_ledger.Ledger.to_list ledger
        |> List.filter ~f:(fun acct -> Option.is_some acct.zkapp)
      in
      List.iter ledger_accounts ~f:(fun account ->
          let account_id =
            Account_id.create account.public_key account.token_id
          in
          ignore
            ( Mock_base_ledger.add best_tip_ledger ~account_id ~account
              : [ `Duplicate | `Ok ] ) ) ;
      result

    let mk_parties_cmds' (pool : Test.Resource_pool.t) : User_command.t list =
      List.map (mk_parties_cmds pool) ~f:User_command.forget_check

    type pool_apply = (User_command.t list, [ `Other of Error.t ]) Result.t
    [@@deriving sexp, compare]

    let canonicalize t =
      Result.map t ~f:(List.sort ~compare:User_command.compare)

    let compare_pool_apply (t1 : pool_apply) (t2 : pool_apply) =
      compare_pool_apply (canonicalize t1) (canonicalize t2)

    let accepted_commands = Result.map ~f:fst

    let mk_with_status (cmd : User_command.Valid.t) =
      { With_status.data = cmd; status = Applied }

    let verify_and_apply (pool : Test.Resource_pool.t) cs =
      let tm0 = Time.now () in
      let%bind verified =
        Test.Resource_pool.Diff.verify' ~allow_failures_for_tests:true pool
          (Envelope.Incoming.local cs)
        >>| Or_error.ok_exn
      in
      let result = Test.Resource_pool.Diff.unsafe_apply pool verified in
      let tm1 = Time.now () in
      [%log' info pool.logger] "Time for verify_and_apply: %0.04f sec"
        (Time.diff tm1 tm0 |> Time.Span.to_sec) ;
      result

    let mk_linear_case_test assert_pool_txs pool best_tip_diff_w cmds =
      assert_pool_txs [] ;
      let%bind apply_res = verify_and_apply pool cmds in
      [%test_eq: pool_apply] (accepted_commands apply_res) (Ok cmds) ;
      assert_pool_txs cmds ;
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands = [ mk_with_status (List.hd_exn independent_cmds) ]
            ; removed_commands = []
            ; reorg_best_tip = false
            }
            : Mock_transition_frontier.best_tip_diff )
      in
      let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
      assert_pool_txs (List.tl_exn cmds) ;
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          { new_commands =
              List.map ~f:mk_with_status
                (List.take (List.tl_exn independent_cmds) 2)
          ; removed_commands = []
          ; reorg_best_tip = false
          }
      in
      let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
      assert_pool_txs (List.drop cmds 3) ;
      Deferred.unit

    let%test_unit "transactions are removed in linear case (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, _frontier =
            setup_test ()
          in
          mk_linear_case_test assert_pool_txs pool best_tip_diff_w
            independent_cmds' )

    let%test_unit "transactions are removed in linear case (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, _frontier =
            setup_test ()
          in
          mk_linear_case_test assert_pool_txs pool best_tip_diff_w
            (mk_parties_cmds' pool) )

    let map_set_multi map pairs =
      let rec go pairs =
        match pairs with
        | (k, v) :: pairs' ->
            let pk = Public_key.compress test_keys.(k).public_key in
            let key = Account_id.create pk Token_id.default in
            Account_id.Table.set map ~key ~data:v ;
            go pairs'
        | [] ->
            ()
      in
      go pairs

    let mk_account ~idx ~balance ~nonce =
      let public_key = Public_key.compress @@ test_keys.(idx).public_key in
      ( idx
      , { Account.Poly.Stable.Latest.public_key
        ; token_id = Token_id.default
        ; token_permissions =
            Token_permissions.Not_owned { account_disabled = false }
        ; token_symbol = Account.Token_symbol.default
        ; balance = Currency.Balance.of_int balance
        ; nonce = Account.Nonce.of_int nonce
        ; receipt_chain_hash = Receipt.Chain_hash.empty
        ; delegate = Some public_key
        ; voting_for =
            Quickcheck.random_value ~seed:(`Deterministic "constant")
              State_hash.gen
        ; timing = Account.Timing.Untimed
        ; permissions = Permissions.user_default
        ; zkapp = None
        ; zkapp_uri = ""
        } )

    let mk_remove_and_add_test assert_pool_txs pool best_tip_diff_w best_tip_ref
        valid_cmds =
      let cmds' = List.map valid_cmds ~f:User_command.forget_check in
      assert_pool_txs [] ;
      (* omit the 1st (0-based) command *)
      let cmds_to_apply = List.hd_exn cmds' :: List.drop cmds' 2 in
      let%bind apply_res = verify_and_apply pool cmds_to_apply in
      [%test_eq: pool_apply] (accepted_commands apply_res) (Ok cmds_to_apply) ;
      map_set_multi !best_tip_ref
        [ mk_account ~idx:1 ~balance:1_000_000_000_000 ~nonce:1 ] ;
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands = List.map ~f:mk_with_status @@ List.take valid_cmds 1
            ; removed_commands =
                List.map ~f:mk_with_status @@ [ List.nth_exn valid_cmds 1 ]
            ; reorg_best_tip = true
            }
            : Mock_transition_frontier.best_tip_diff )
      in
      assert_pool_txs (List.tl_exn cmds') ;
      Deferred.unit

    let%test_unit "Transactions are removed and added back in fork changes \
                   (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          mk_remove_and_add_test assert_pool_txs pool best_tip_diff_w
            best_tip_ref independent_cmds )

    let%test_unit "Transactions are removed and added back in fork changes \
                   (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          mk_remove_and_add_test assert_pool_txs pool best_tip_diff_w
            best_tip_ref (mk_parties_cmds pool) )

    let mk_invalid_test assert_pool_txs pool best_tip_diff_w best_tip_ref cmds'
        =
      assert_pool_txs [] ;
      map_set_multi !best_tip_ref
        [ mk_account ~idx:0 ~balance:0 ~nonce:0
        ; mk_account ~idx:1 ~balance:1_000_000_000_000 ~nonce:1
        ] ;
      (* need a best tip diff so the ref is actually read *)
      let%bind _ =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands = []; removed_commands = []; reorg_best_tip = false }
            : Mock_transition_frontier.best_tip_diff )
      in
      let%bind apply_res = verify_and_apply pool cmds' in
      [%test_eq: pool_apply]
        (Ok (List.drop cmds' 2))
        (accepted_commands apply_res) ;
      assert_pool_txs (List.drop cmds' 2) ;
      Deferred.unit

    let%test_unit "invalid transactions are not accepted (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          mk_invalid_test assert_pool_txs pool best_tip_diff_w best_tip_ref
            independent_cmds' )

    let%test_unit "invalid transactions are not accepted (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          mk_invalid_test assert_pool_txs pool best_tip_diff_w best_tip_ref
            (mk_parties_cmds' pool) )

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

    let mk_parties ?valid_period ?fee_payer_idx ~sender_idx ~receiver_idx ~fee
        ~nonce ~amount () =
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
      let test_spec : Transaction_snark.For_tests.Spec.t =
        { sender
        ; fee_payer
        ; fee
        ; receivers = [ (receiver, amount) ]
        ; amount
        ; zkapp_account_keypairs = []
        ; memo = Signed_command_memo.create_from_string_exn "expiry tests"
        ; new_zkapp_account = false
        ; snapp_update = Party.Update.dummy
        ; current_auth = Permissions.Auth_required.Signature
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions =
            Some
              { Party.Preconditions.network = protocol_state_precondition
              ; account = Party.Account_precondition.Accept
              }
        }
      in
      let parties = Transaction_snark.For_tests.multiple_transfers test_spec in
      User_command.Parties parties

    let mk_payment ?valid_until ~sender_idx ~receiver_idx ~fee ~nonce ~amount ()
        =
      User_command.Signed_command
        (mk_payment' ?valid_until ~sender_idx ~fee ~nonce ~receiver_idx ~amount
           () )

    let current_global_slot () =
      let current_time = Block_time.now time_controller in
      Consensus.Data.Consensus_time.(
        of_time_exn ~constants:consensus_constants current_time
        |> to_global_slot)

    let mk_now_invalid_test assert_pool_txs pool best_tip_diff_w best_tip_ref
        cmds =
      let cmds' = List.map cmds ~f:User_command.forget_check in
      assert_pool_txs [] ;
      map_set_multi !best_tip_ref
        [ mk_account ~idx:0 ~balance:1_000_000_000_000 ~nonce:1 ] ;
      let%bind _ =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands = List.map ~f:mk_with_status @@ List.take cmds 2
            ; removed_commands = []
            ; reorg_best_tip = false
            }
            : Mock_transition_frontier.best_tip_diff )
      in
      assert_pool_txs [] ;
      let cmd1 =
        let sender = test_keys.(0) in
        Quickcheck.random_value
          (User_command.Valid.Gen.payment ~sign_type:`Real
             ~key_gen:
               Quickcheck.Generator.(
                 tuple2 (return sender) (Quickcheck_lib.of_array test_keys))
             ~nonce:(Account.Nonce.of_int 1) ~max_amount:100_000_000_000
             ~fee_range:10_000_000_000 () )
      in
      let%bind apply_res =
        verify_and_apply pool [ User_command.forget_check cmd1 ]
      in
      [%test_eq: pool_apply]
        (accepted_commands apply_res)
        (Ok [ User_command.forget_check cmd1 ]) ;
      assert_pool_txs [ User_command.forget_check cmd1 ] ;
      let cmd2 =
        mk_payment ~sender_idx:0 ~fee:1_000_000_000 ~nonce:0 ~receiver_idx:5
          ~amount:999_000_000_000 ()
      in
      map_set_multi !best_tip_ref [ mk_account ~idx:0 ~balance:0 ~nonce:1 ] ;
      let%bind _ =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands =
                List.map ~f:mk_with_status @@ (cmd2 :: List.drop cmds 2)
            ; removed_commands = List.map ~f:mk_with_status @@ List.take cmds 2
            ; reorg_best_tip = true
            }
            : Mock_transition_frontier.best_tip_diff )
      in
      (* first cmd from removed_commands gets replaced by cmd2 (same sender), cmd1 is invalid because of insufficient balance,
         and so only the second cmd from removed_commands is expected to be in the pool
      *)
      assert_pool_txs [ List.nth_exn cmds' 1 ] ;
      Deferred.unit

    let%test_unit "Now-invalid transactions are removed from the pool on fork \
                   changes (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          mk_now_invalid_test assert_pool_txs pool best_tip_diff_w best_tip_ref
            independent_cmds )

    let%test_unit "Now-invalid transactions are removed from the pool on fork \
                   changes (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          mk_now_invalid_test assert_pool_txs pool best_tip_diff_w best_tip_ref
            (mk_parties_cmds pool) )

    let mk_expired_not_accepted_test assert_pool_txs pool ~padding cmds =
      assert_pool_txs [] ;
      let curr_slot = current_global_slot () in
      let slot_padding = Mina_numbers.Global_slot.of_int padding in
      let curr_slot_plus_padding =
        Mina_numbers.Global_slot.add curr_slot slot_padding
      in
      let valid_command =
        mk_payment ~valid_until:curr_slot_plus_padding ~sender_idx:1
          ~fee:1_000_000_000 ~nonce:1 ~receiver_idx:9 ~amount:1_000_000_000 ()
      in
      let expired_commands =
        [ mk_payment ~valid_until:curr_slot ~sender_idx:0 ~fee:1_000_000_000
            ~nonce:1 ~receiver_idx:9 ~amount:1_000_000_000 ()
        ; mk_payment ~sender_idx:0 ~fee:1_000_000_000 ~nonce:2 ~receiver_idx:9
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
      let%bind apply_res =
        verify_and_apply pool
          (List.map
             (all_valid_commands @ expired_commands)
             ~f:User_command.forget_check )
      in
      let cmds_wo_check =
        List.map all_valid_commands ~f:User_command.forget_check
      in
      [%test_eq: pool_apply] (Ok cmds_wo_check) (accepted_commands apply_res) ;
      assert_pool_txs cmds_wo_check ;
      Deferred.unit

    let%test_unit "expired transactions are not accepted (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, _best_tip_diff_w, (_, _best_tip_ref) =
            setup_test ()
          in
          mk_expired_not_accepted_test assert_pool_txs pool ~padding:10
            independent_cmds )

    let%test_unit "expired transactions are not accepted (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, _best_tip_diff_w, (_, _best_tip_ref) =
            setup_test ()
          in
          mk_expired_not_accepted_test assert_pool_txs pool ~padding:25
            (mk_parties_cmds pool) )

    let%test_unit "Expired transactions that are already in the pool are \
                   removed from the pool when best tip changes (user commands)"
        =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          assert_pool_txs [] ;
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
              ~fee:1_000_000_000 ~nonce:1 ~receiver_idx:9 ~amount:10_000_000_000
              ()
          in
          let expires_later2 =
            mk_payment ~valid_until:curr_slot_plus_seven ~sender_idx:0
              ~fee:1_000_000_000 ~nonce:2 ~receiver_idx:9 ~amount:10_000_000_000
              ()
          in
          let valid_commands = few_now @ [ expires_later1; expires_later2 ] in
          let cmds_wo_check =
            List.map valid_commands ~f:User_command.forget_check
          in
          let%bind apply_res = verify_and_apply pool cmds_wo_check in
          [%test_eq: pool_apply] (accepted_commands apply_res) (Ok cmds_wo_check) ;
          assert_pool_txs cmds_wo_check ;
          (* new commands from best tip diff should be removed from the pool *)
          (* update the nonce to be consistent with the commands in the block *)
          map_set_multi !best_tip_ref
            [ mk_account ~idx:0 ~balance:1_000_000_000_000_000 ~nonce:2 ] ;
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              ( { new_commands =
                    List.map ~f:mk_with_status
                      [ List.nth_exn few_now 0; expires_later1 ]
                ; removed_commands = []
                ; reorg_best_tip = false
                }
                : Mock_transition_frontier.best_tip_diff )
          in
          let cmds_wo_check =
            List.map ~f:User_command.forget_check
              (expires_later2 :: List.drop few_now 1)
          in
          let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
          assert_pool_txs cmds_wo_check ;
          (* Add new commands, remove old commands some of which are now expired *)
          let expired_command =
            mk_payment ~valid_until:curr_slot ~sender_idx:9 ~fee:1_000_000_000
              ~nonce:0 ~receiver_idx:5 ~amount:1_000_000_000 ()
          in
          let unexpired_command =
            mk_payment ~valid_until:curr_slot_plus_seven ~sender_idx:8
              ~fee:1_000_000_000 ~nonce:0 ~receiver_idx:9 ~amount:1_000_000_000
              ()
          in
          let valid_forever = List.nth_exn few_now 0 in
          let removed_commands =
            [ valid_forever
            ; expires_later1
            ; expired_command
            ; unexpired_command
            ]
            |> List.map ~f:mk_with_status
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
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              ( { new_commands = [ mk_with_status valid_forever ]
                ; removed_commands
                ; reorg_best_tip = true
                }
                : Mock_transition_frontier.best_tip_diff )
          in
          (* expired_command should not be in the pool because they are expired
             and (List.nth few_now 0) because it was committed in a block
          *)
          let cmds_wo_check =
            List.map ~f:User_command.forget_check
              ( expires_later1 :: expires_later2 :: unexpired_command
              :: List.drop few_now 1 )
          in
          let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
          assert_pool_txs cmds_wo_check ;
          (* after 5 block times there should be no expired transactions *)
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 5L))
          in
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              ( { new_commands = []
                ; removed_commands = []
                ; reorg_best_tip = false
                }
                : Mock_transition_frontier.best_tip_diff )
          in
          let cmds_wo_check =
            List.map ~f:User_command.forget_check (List.drop few_now 1)
          in
          let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
          assert_pool_txs cmds_wo_check ;
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
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ~expiry ()
          in
          assert_pool_txs [] ;
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
            mk_parties
              ~valid_period:{ lower = curr_time; upper = curr_time_plus_three }
              ~fee_payer_idx:(0, 1) ~sender_idx:1 ~receiver_idx:9
              ~fee:1_000_000_000 ~amount:10_000_000_000 ~nonce:1 ()
          in
          let expires_later2 =
            mk_parties
              ~valid_period:{ lower = curr_time; upper = curr_time_plus_seven }
              ~fee_payer_idx:(0, 2) ~sender_idx:1 ~receiver_idx:9
              ~fee:1_000_000_000 ~amount:10_000_000_000 ~nonce:2 ()
          in
          let valid_commands = few_now @ [ expires_later1; expires_later2 ] in
          let cmds_wo_check =
            List.map valid_commands ~f:User_command.forget_check
          in
          let%bind apply_res = verify_and_apply pool cmds_wo_check in
          [%test_eq: pool_apply] (accepted_commands apply_res) (Ok cmds_wo_check) ;
          assert_pool_txs cmds_wo_check ;
          (* new commands from best tip diff should be removed from the pool *)
          (* update the nonce to be consistent with the commands in the block *)
          map_set_multi !best_tip_ref
            [ mk_account ~idx:0 ~balance:1_000_000_000_000_000 ~nonce:2
            ; mk_account ~idx:1 ~balance:1_000_000_000_000_000 ~nonce:2
            ] ;
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              ( { new_commands =
                    List.map ~f:mk_with_status
                      [ List.nth_exn few_now 0; expires_later1 ]
                ; removed_commands = []
                ; reorg_best_tip = false
                }
                : Mock_transition_frontier.best_tip_diff )
          in
          let cmds_wo_check =
            List.map ~f:User_command.forget_check
              (expires_later2 :: List.drop few_now 1)
          in
          let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
          assert_pool_txs cmds_wo_check ;
          (* Add new commands, remove old commands some of which are now expired *)
          let expired_zkapp =
            mk_parties
              ~valid_period:{ lower = curr_time; upper = curr_time }
              ~fee_payer_idx:(9, 0) ~sender_idx:1 ~fee:1_000_000_000 ~nonce:3
              ~receiver_idx:5 ~amount:1_000_000_000 ()
          in
          let unexpired_zkapp =
            mk_parties
              ~valid_period:{ lower = curr_time; upper = curr_time_plus_seven }
              ~fee_payer_idx:(8, 0) ~sender_idx:1 ~fee:1_000_000_000 ~nonce:4
              ~receiver_idx:9 ~amount:1_000_000_000 ()
          in
          let valid_forever = List.nth_exn few_now 0 in
          let removed_commands =
            [ valid_forever; expires_later1; expired_zkapp; unexpired_zkapp ]
            |> List.map ~f:mk_with_status
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
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              ( { new_commands = [ mk_with_status valid_forever ]
                ; removed_commands
                ; reorg_best_tip = true
                }
                : Mock_transition_frontier.best_tip_diff )
          in
          (* expired_command should not be in the pool because they are expired
             and (List.nth few_now 0) because it was committed in a block
          *)
          let cmds_wo_check =
            List.map ~f:User_command.forget_check
              ( expires_later1 :: expires_later2 :: unexpired_zkapp
              :: List.drop few_now 1 )
          in
          let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
          assert_pool_txs cmds_wo_check ;
          (* after 5 block times there should be no expired transactions *)
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 5L))
          in
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              ( { new_commands = []
                ; removed_commands = []
                ; reorg_best_tip = false
                }
                : Mock_transition_frontier.best_tip_diff )
          in
          let cmds_wo_check =
            List.map ~f:User_command.forget_check (List.drop few_now 1)
          in
          let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
          assert_pool_txs cmds_wo_check ;
          Deferred.unit )

    let%test_unit "Aged-based expiry (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let expiry = Time_ns.Span.of_sec 1. in
          let%bind assert_pool_txs, pool, best_tip_diff_w, _ =
            setup_test ~expiry ()
          in
          assert_pool_txs [] ;
          let party_transfer =
            mk_parties ~fee_payer_idx:(0, 0) ~sender_idx:1 ~receiver_idx:9
              ~fee:1_000_000_000 ~amount:10_000_000_000 ~nonce:0 ()
          in
          let valid_commands = [ party_transfer ] in
          let cmds_wo_check =
            List.map valid_commands ~f:User_command.forget_check
          in
          let%bind apply_res = verify_and_apply pool cmds_wo_check in
          [%test_eq: pool_apply] (accepted_commands apply_res) (Ok cmds_wo_check) ;
          assert_pool_txs cmds_wo_check ;
          let%bind () = after (Time.Span.of_sec 2.) in
          let%map _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              ( { new_commands = []
                ; removed_commands = []
                ; reorg_best_tip = false
                }
                : Mock_transition_frontier.best_tip_diff )
          in
          assert_pool_txs [] )

    let%test_unit "Now-invalid transactions are removed from the pool when the \
                   transition frontier is recreated (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          (* Set up initial frontier *)
          let frontier_pipe_r, frontier_pipe_w = Broadcast_pipe.create None in
          let trust_system = Trust_system.null () in
          let config =
            Test.Resource_pool.make_config ~trust_system ~pool_max_size
              ~verifier
          in
          let pool_, _, _ =
            Test.create ~config ~logger ~constraint_constants
              ~consensus_constants ~time_controller ~expiry_ns
              ~frontier_broadcast_pipe:frontier_pipe_r ~log_gossip_heard:false
              ~on_remote_push:(Fn.const Deferred.unit)
          in
          let pool = Test.resource_pool pool_ in
          let assert_pool_txs txs =
            [%test_eq: User_command.t List.t]
              ( Test.Resource_pool.transactions ~logger pool
              |> Sequence.map
                   ~f:Transaction_hash.User_command_with_valid_signature.command
              |> Sequence.to_list
              |> List.sort ~compare:User_command.compare )
            @@ List.sort ~compare:User_command.compare txs
          in
          assert_pool_txs [] ;
          let frontier1, best_tip_diff_w1 =
            Mock_transition_frontier.create ()
          in
          let%bind _ =
            Broadcast_pipe.Writer.write frontier_pipe_w (Some frontier1)
          in
          let%bind _ = verify_and_apply pool independent_cmds' in
          assert_pool_txs independent_cmds' ;
          (* Destroy initial frontier *)
          Broadcast_pipe.Writer.close best_tip_diff_w1 ;
          let%bind _ = Broadcast_pipe.Writer.write frontier_pipe_w None in
          (* Set up second frontier *)
          let ((_, ledger_ref2) as frontier2), _best_tip_diff_w2 =
            Mock_transition_frontier.create ()
          in
          map_set_multi !ledger_ref2
            [ mk_account ~idx:0 ~balance:20_000_000_000_000 ~nonce:5
            ; mk_account ~idx:1 ~balance:0 ~nonce:0
            ; mk_account ~idx:2 ~balance:0 ~nonce:1
            ] ;
          let%bind _ =
            Broadcast_pipe.Writer.write frontier_pipe_w (Some frontier2)
          in
          assert_pool_txs @@ List.drop independent_cmds' 3 ;
          Deferred.unit )

    let%test_unit "transaction replacement works" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind assert_pool_txs, pool, _best_tip_diff_w, frontier =
        setup_test ()
      in
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
        [ mk_payment' ~sender_idx:0 ~fee:1_000_000_000 ~nonce:0 ~receiver_idx:9
            ~amount:20_000_000_000 ()
        ; mk_payment' ~sender_idx:0 ~fee:1_000_000_000 ~nonce:1 ~receiver_idx:9
            ~amount:12_000_000_000 ()
        ; mk_payment' ~sender_idx:0 ~fee:1_000_000_000 ~nonce:2 ~receiver_idx:9
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
      let txs_all = List.map txs_all ~f:User_command.forget_check in
      let%bind apply_res = verify_and_apply pool txs_all in
      [%test_eq: pool_apply] (Ok txs_all) (accepted_commands apply_res) ;
      assert_pool_txs @@ txs_all ;
      let replace_txs =
        [ (* sufficient fee *)
          mk_payment ~sender_idx:0 ~fee:16_000_000_000 ~nonce:0 ~receiver_idx:1
            ~amount:440_000_000_000 ()
        ; (* insufficient fee *)
          mk_payment ~sender_idx:1 ~fee:1_000_000_000 ~nonce:0 ~receiver_idx:1
            ~amount:788_000_000_000 ()
        ; (* sufficient *)
          mk_payment ~sender_idx:2 ~fee:20_000_000_000 ~nonce:1 ~receiver_idx:4
            ~amount:721_000_000_000 ()
        ; (* insufficient *)
          (let amount = 927_000_000_000 in
           let fee =
             let ledger = Mock_transition_frontier.best_tip frontier in
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
      let replace_txs = List.map replace_txs ~f:User_command.forget_check in
      let%bind apply_res_2 = verify_and_apply pool replace_txs in
      [%test_eq: pool_apply]
        (Ok [ List.nth_exn replace_txs 0; List.nth_exn replace_txs 2 ])
        (accepted_commands apply_res_2) ;
      Deferred.unit

    let%test_unit "it drops queued transactions if a committed one makes there \
                   be insufficient funds" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
        setup_test ()
      in
      let txs =
        [ mk_payment ~sender_idx:0 ~fee:5_000_000_000 ~nonce:0 ~receiver_idx:9
            ~amount:20_000_000_000 ()
        ; mk_payment ~sender_idx:0 ~fee:6_000_000_000 ~nonce:1 ~receiver_idx:5
            ~amount:77_000_000_000 ()
        ; mk_payment ~sender_idx:0 ~fee:1_000_000_000 ~nonce:2 ~receiver_idx:3
            ~amount:891_000_000_000 ()
        ]
      in
      let committed_tx =
        mk_payment ~sender_idx:0 ~fee:5_000_000_000 ~nonce:0 ~receiver_idx:2
          ~amount:25_000_000_000 ()
      in
      let txs = txs |> List.map ~f:User_command.forget_check in
      let%bind apply_res = verify_and_apply pool txs in
      [%test_eq: pool_apply] (Ok txs) (accepted_commands apply_res) ;
      assert_pool_txs @@ txs ;
      map_set_multi !best_tip_ref
        [ mk_account ~idx:0 ~balance:970_000_000_000 ~nonce:1 ] ;
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          { new_commands = List.map ~f:mk_with_status @@ [ committed_tx ]
          ; removed_commands = []
          ; reorg_best_tip = false
          }
      in
      assert_pool_txs [ List.nth_exn txs 1 ] ;
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
              let%bind _assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref)
                  =
                setup_test ()
              in
              let mock_ledger =
                Account_id.Table.of_alist_exn
                  ( init_ledger_state |> Array.to_sequence
                  |> Sequence.map ~f:(fun (kp, balance, nonce, timing) ->
                         let public_key = Public_key.compress kp.public_key in
                         let account_id =
                           Account_id.create public_key Token_id.default
                         in
                         ( account_id
                         , { (Account.initialize account_id) with
                             balance =
                               Currency.Balance.of_uint64
                                 (Currency.Amount.to_uint64 balance)
                           ; nonce
                           ; timing
                           } ) )
                  |> Sequence.to_list )
              in
              best_tip_ref := mock_ledger ;
              let%bind () =
                Broadcast_pipe.Writer.write best_tip_diff_w
                  { new_commands = []
                  ; removed_commands = []
                  ; reorg_best_tip = true
                  }
              in
              let cmds1, cmds2 = List.split_n cmds pool_max_size in
              let%bind apply_res1 =
                verify_and_apply pool
                  (List.map cmds1 ~f:User_command.forget_check)
              in
              assert (Result.is_ok apply_res1) ;
              [%test_eq: int] pool_max_size (Indexed_pool.size pool.pool) ;
              let%map _apply_res2 =
                verify_and_apply pool
                  (List.map cmds2 ~f:User_command.forget_check)
              in
              (* N.B. Adding a transaction when the pool is full may drop > 1
                 command, so the size now is not necessarily the maximum.
                 Applying the diff may also return an error if none of the new
                 commands have higher fee than the lowest one already in the
                 pool.
              *)
              assert (Indexed_pool.size pool.pool <= pool_max_size) ) )

    let assert_rebroadcastable pool cmds =
      let normalize = List.sort ~compare:User_command.compare in
      let expected =
        match normalize cmds with [] -> [] | normalized -> [ normalized ]
      in
      [%test_eq: User_command.t list list]
        ( List.map ~f:normalize
        @@ Test.Resource_pool.get_rebroadcastable pool
             ~has_timed_out:(Fn.const `Ok) )
        expected

    let mock_sender =
      Envelope.Sender.Remote
        (Peer.create
           (Unix.Inet_addr.of_string "1.2.3.4")
           ~peer_id:(Peer.Id.unsafe_of_string "contents should be irrelevant")
           ~libp2p_port:8302 )

    let mk_rebroadcastable_test assert_pool_txs pool best_tip_diff_w cmds =
      assert_pool_txs [] ;
      let local_cmds = List.take cmds 5 in
      let local_cmds' = List.map local_cmds ~f:User_command.forget_check in
      let remote_cmds = List.drop cmds 5 in
      let remote_cmds' = List.map remote_cmds ~f:User_command.forget_check in
      (* Locally generated transactions are rebroadcastable *)
      let%bind apply_res_1 = verify_and_apply pool local_cmds' in
      [%test_eq: pool_apply] (accepted_commands apply_res_1) (Ok local_cmds') ;
      assert_pool_txs local_cmds' ;
      assert_rebroadcastable pool local_cmds' ;
      (* Adding non-locally-generated transactions doesn't affect
         rebroadcastable pool *)
      let%bind apply_res_2 =
        let%bind verified =
          Test.Resource_pool.Diff.verify pool
            (Envelope.Incoming.wrap ~data:remote_cmds' ~sender:mock_sender)
          >>| Or_error.ok_exn
        in
        Test.Resource_pool.Diff.unsafe_apply pool verified
      in
      [%test_eq: pool_apply] (accepted_commands apply_res_2) (Ok remote_cmds') ;
      assert_pool_txs (local_cmds' @ remote_cmds') ;
      assert_rebroadcastable pool local_cmds' ;
      (* When locally generated transactions are committed they are no
         longer rebroadcastable *)
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands =
                List.map ~f:mk_with_status @@ List.take local_cmds 2
                @ List.take remote_cmds 3
            ; removed_commands = []
            ; reorg_best_tip = false
            }
            : Mock_transition_frontier.best_tip_diff )
      in
      assert_pool_txs (List.drop local_cmds' 2 @ List.drop remote_cmds' 3) ;
      assert_rebroadcastable pool (List.drop local_cmds' 2) ;
      (* Reorgs put locally generated transactions back into the
         rebroadcastable pool, if they were removed and not re-added *)
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands = List.map ~f:mk_with_status @@ List.take local_cmds 1
            ; removed_commands =
                List.map ~f:mk_with_status @@ List.take local_cmds 2
            ; reorg_best_tip = true
            }
            : Mock_transition_frontier.best_tip_diff )
      in
      assert_pool_txs (List.tl_exn local_cmds' @ List.drop remote_cmds' 3) ;
      assert_rebroadcastable pool (List.tl_exn local_cmds') ;
      (* Committing them again removes them from the pool again. *)
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands =
                List.map ~f:mk_with_status @@ List.tl_exn local_cmds
                @ List.drop remote_cmds 3
            ; removed_commands = []
            ; reorg_best_tip = false
            }
            : Mock_transition_frontier.best_tip_diff )
      in
      assert_pool_txs [] ;
      assert_rebroadcastable pool [] ;
      (* A reorg that doesn't re-add anything puts the right things back
         into the rebroadcastable pool. *)
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands = []
            ; removed_commands =
                List.map ~f:mk_with_status @@ List.drop local_cmds 3
                @ remote_cmds
            ; reorg_best_tip = true
            }
            : Mock_transition_frontier.best_tip_diff )
      in
      assert_pool_txs (List.drop local_cmds' 3 @ remote_cmds') ;
      assert_rebroadcastable pool (List.drop local_cmds' 3) ;
      (* Committing again removes them. (Checking this works in both one and
         two step reorg processes) *)
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          ( { new_commands =
                List.map ~f:mk_with_status @@ [ List.nth_exn local_cmds 3 ]
            ; removed_commands = []
            ; reorg_best_tip = false
            }
            : Mock_transition_frontier.best_tip_diff )
      in
      assert_pool_txs (List.drop local_cmds' 4 @ remote_cmds') ;
      assert_rebroadcastable pool (List.drop local_cmds' 4) ;
      (* When transactions expire from rebroadcast pool they are gone. This
         doesn't affect the main pool.
      *)
      ignore
        ( Test.Resource_pool.get_rebroadcastable pool
            ~has_timed_out:(Fn.const `Timed_out)
          : User_command.t list list ) ;
      assert_pool_txs (List.drop local_cmds' 4 @ remote_cmds') ;
      assert_rebroadcastable pool [] ;
      Deferred.unit

    let%test_unit "rebroadcastable transaction behavior (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, _frontier =
            setup_test ()
          in
          mk_rebroadcastable_test assert_pool_txs pool best_tip_diff_w
            independent_cmds )

    let%test_unit "rebroadcastable transaction behavior (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, _frontier =
            setup_test ()
          in
          mk_rebroadcastable_test assert_pool_txs pool best_tip_diff_w
            (mk_parties_cmds pool) )

    let%test_unit "apply user cmds and zkapps" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, _best_tip_diff_w, _frontier =
            setup_test ()
          in
          let num_cmds = Array.length test_keys in
          (* the user cmds and snapp cmds are taken from the same list of keys,
             so splitting by the order from that list makes sure that they
             don't share fee payer keys
             therefore, the original nonces in the accounts are valid
          *)
          let take_len = num_cmds / 2 in
          let snapp_cmds = List.take (mk_parties_cmds' pool) take_len in
          let user_cmds = List.drop independent_cmds' take_len in
          let all_cmds = snapp_cmds @ user_cmds in
          assert_pool_txs [] ;
          let%bind apply_res = verify_and_apply pool all_cmds in
          [%test_eq: pool_apply] (accepted_commands apply_res) (Ok all_cmds) ;
          assert_pool_txs all_cmds ;
          Deferred.unit )
  end )
