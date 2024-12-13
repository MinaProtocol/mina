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

      module V3 = struct
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
          | After_slot_tx_end
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
      | After_slot_tx_end
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
      | After_slot_tx_end ->
          "after_slot_tx_end"

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
      | After_slot_tx_end ->
          "This transaction was submitted after the slot defined to stop \
           accepting transactions"
  end

  module Rejected = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V3 = struct
        type t = (User_command.Stable.V2.t * Diff_error.Stable.V3.t) list
        [@@deriving sexp, yojson, compare]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t [@@deriving sexp, yojson, compare]
  end

  type rejected = Rejected.t [@@deriving sexp, yojson, compare]

  type verified = Transaction_hash.User_command_with_valid_signature.t list
  [@@deriving sexp, to_yojson]

  let summary t =
    Printf.sprintf
      !"Transaction_pool_diff of length %d with fee payer summary %s"
      (List.length t)
      ( String.concat ~sep:","
      @@ List.map ~f:User_command.fee_payer_summary_string t )

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
        ; slot_tx_end : Mina_numbers.Global_slot_since_hard_fork.t option
        }
      [@@deriving sexp_of]

      (* remove next line if there's a way to force [@@deriving make] write a
         named parameter instead of an optional parameter *)
      let make ~trust_system ~pool_max_size ~verifier ~genesis_constants
          ~slot_tx_end =
        { trust_system
        ; pool_max_size
        ; verifier
        ; genesis_constants
        ; slot_tx_end
        }
    end

    let make_config = Config.make

    module Batcher = Batcher.Transaction_pool

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

    module Vk_refcount_table = struct
      type t =
        { verification_keys :
            (int * Verification_key_wire.t) Zkapp_basic.F_map.Table.t
        ; account_id_to_vks : int Zkapp_basic.F_map.Map.t Account_id.Table.t
        ; vk_to_account_ids : int Account_id.Map.t Zkapp_basic.F_map.Table.t
        }

      let create () =
        { verification_keys = Zkapp_basic.F_map.Table.create ()
        ; account_id_to_vks = Account_id.Table.create ()
        ; vk_to_account_ids = Zkapp_basic.F_map.Table.create ()
        }

      let find_vk (t : t) = Hashtbl.find t.verification_keys

      let find_vks_by_account_id (t : t) account_id =
        match Hashtbl.find t.account_id_to_vks account_id with
        | None ->
            []
        | Some vks ->
            Map.keys vks
            |> List.map ~f:(find_vk t)
            |> Option.all
            |> Option.value_exn ~message:"malformed Vk_refcount_table.t"
            |> List.map ~f:snd

      let inc (t : t) ~account_id ~(vk : Verification_key_wire.t) =
        let inc_map ~default_map key map =
          Map.update (Option.value map ~default:default_map) key ~f:(function
            | None ->
                1
            | Some count ->
                count + 1 )
        in
        Hashtbl.update t.verification_keys vk.hash ~f:(function
          | None ->
              (1, vk)
          | Some (count, vk) ->
              (count + 1, vk) ) ;
        Hashtbl.update t.account_id_to_vks account_id
          ~f:(inc_map ~default_map:Zkapp_basic.F_map.Map.empty vk.hash) ;
        Hashtbl.update t.vk_to_account_ids vk.hash
          ~f:(inc_map ~default_map:Account_id.Map.empty account_id) ;
        Mina_metrics.(
          Gauge.set Transaction_pool.vk_refcount_table_size
            (Float.of_int (Zkapp_basic.F_map.Table.length t.verification_keys)))

      let dec (t : t) ~account_id ~vk_hash =
        let open Option.Let_syntax in
        let dec count = if count = 1 then None else Some (count - 1) in
        let dec_map key map =
          let map' = Map.change map key ~f:(Option.bind ~f:dec) in
          if Map.is_empty map' then None else Some map'
        in
        Hashtbl.change t.verification_keys vk_hash
          ~f:
            (Option.bind ~f:(fun (count, value) ->
                 let%map count' = dec count in
                 (count', value) ) ) ;
        Hashtbl.change t.account_id_to_vks account_id
          ~f:(Option.bind ~f:(dec_map vk_hash)) ;
        Hashtbl.change t.vk_to_account_ids vk_hash
          ~f:(Option.bind ~f:(dec_map account_id)) ;
        Mina_metrics.(
          Gauge.set Transaction_pool.vk_refcount_table_size
            (Float.of_int (Zkapp_basic.F_map.Table.length t.verification_keys)))

      let lift_common (t : t) table_modify cmd =
        User_command.extract_vks cmd
        |> List.iter ~f:(fun (account_id, vk) -> table_modify t ~account_id ~vk)

      let lift (t : t) table_modify (cmd : User_command.Valid.t With_status.t) =
        With_status.data cmd |> User_command.forget_check
        |> lift_common t table_modify

      let lift_hashed (t : t) table_modify cmd =
        Transaction_hash.User_command_with_valid_signature.forget_check cmd
        |> With_hash.data |> lift_common t table_modify
    end

    type t =
      { mutable pool : Indexed_pool.t
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
      ; verification_key_table : (Vk_refcount_table.t[@sexp.opaque])
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
        Command_error.t -> Diff_versioned.Diff_error.t = function
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
      | After_slot_tx_end ->
          After_slot_tx_end

    let indexed_pool_error_metadata = function
      | Command_error.Invalid_nonce (`Between (low, hi), nonce) ->
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
          [ ( "valid_until"
            , Mina_numbers.Global_slot_since_genesis.to_yojson valid_until )
          ; ( "current_global_slot_since_genesis"
            , Mina_numbers.Global_slot_since_genesis.to_yojson
                global_slot_since_genesis )
          ]
      | After_slot_tx_end ->
          []

    let indexed_pool_error_log_info e =
      ( Diff_versioned.Diff_error.to_string_name
          (diff_error_of_indexed_pool_error e)
      , indexed_pool_error_metadata e )

    let handle_transition_frontier_diff_inner ~new_commands ~removed_commands
        ~best_tip_ledger t =
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

         Don't forget to modify the refcount table as well as remove from the
         index pool.
      *)
      let vk_table_inc = Vk_refcount_table.inc in
      let vk_table_dec t ~account_id ~(vk : Verification_key_wire.t) =
        Vk_refcount_table.dec t ~account_id ~vk_hash:vk.hash
      in
      let vk_table_lift = Vk_refcount_table.lift t.verification_key_table in
      let vk_table_lift_hashed =
        Vk_refcount_table.lift_hashed t.verification_key_table
      in
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
      List.iter new_commands ~f:(vk_table_lift vk_table_inc) ;
      List.iter removed_commands ~f:(vk_table_lift vk_table_dec) ;
      let compact_json =
        Fn.compose User_command.fee_payer_summary_json User_command.forget_check
      in
      [%log' trace t.logger]
        ~metadata:
          [ ( "removed"
            , `List
                (List.map removed_commands
                   ~f:(With_status.to_yojson compact_json) ) )
          ; ( "added"
            , `List
                (List.map new_commands ~f:(With_status.to_yojson compact_json))
            )
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
      Sequence.iter dropped_backtrack ~f:(vk_table_lift_hashed vk_table_dec) ;
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
                |> User_command.accounts_referenced |> Account_id.Set.of_list
              in
              Set.union set set' )
        in
        let get_account =
          let existing_account_states_by_id =
            preload_accounts best_tip_ledger accounts_to_check
          in
          fun id ->
            match Map.find existing_account_states_by_id id with
            | Some account ->
                account
            | None ->
                if Set.mem accounts_to_check id then Account.empty
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
          vk_table_lift_hashed vk_table_dec cmd ;
          Hashtbl.find_and_remove t.locally_generated_uncommitted cmd
          |> Option.iter ~f:(fun data ->
                 Hashtbl.add_exn t.locally_generated_committed ~key:cmd ~data ) ) ;
      let commit_conflicts_locally_generated =
        List.filter dropped_commit_conflicts ~f:(fun cmd ->
            Hashtbl.find_and_remove t.locally_generated_uncommitted cmd
            |> Option.is_some )
      in
      if not (List.is_empty commit_conflicts_locally_generated) then
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
            vk_table_lift_hashed vk_table_dec cmd ;
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
                      vk_table_lift_hashed Vk_refcount_table.inc cmd ;
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
          vk_table_lift_hashed vk_table_dec cmd ;
          ignore
            ( Hashtbl.find_and_remove t.locally_generated_uncommitted cmd
              : (Time.t * [ `Batch of int ]) option ) ) ;
      Mina_metrics.(
        Gauge.set Transaction_pool.pool_size
          (Float.of_int (Indexed_pool.size pool))) ;
      t.pool <- pool

    let handle_transition_frontier_diff
        ( ({ new_commands; removed_commands; reorg_best_tip = _ } :
            Transition_frontier.best_tip_diff )
        , best_tip_ledger ) t =
      handle_transition_frontier_diff_inner ~new_commands ~removed_commands
        ~best_tip_ledger t

    let create ~constraint_constants ~consensus_constants ~time_controller
        ~frontier_broadcast_pipe ~config ~logger ~tf_diff_writer =
      let t =
        { pool =
            Indexed_pool.empty ~constraint_constants ~consensus_constants
              ~time_controller ~slot_tx_end:config.Config.slot_tx_end
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
        ; best_tip_ledger = None
        ; verification_key_table = Vk_refcount_table.create ()
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
                 let new_pool, dropped =
                   Indexed_pool.revalidate t.pool ~logger:t.logger `Entire_pool
                     (fun sender ->
                       match
                         Base_ledger.location_of_account validation_ledger
                           sender
                       with
                       | None ->
                           Account.empty
                       | Some loc ->
                           Option.value_exn
                             ~message:
                               "Somehow a public key has a location but no \
                                account"
                             (Base_ledger.get validation_ledger loc) )
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

      let (_ : (t, Diff_versioned.t) Type_equal.t) = Type_equal.T

      let label = label

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
          (*Indexed_pool*)
          | After_slot_tx_end
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
          | Fee_payer_not_permitted_to_send
          | After_slot_tx_end ->
              false
          | Overflow | Bad_token | Unwanted_fee_token ->
              true
      end

      module Rejected = struct
        type t = (User_command.t * Diff_error.t) list
        [@@deriving sexp, yojson, compare]

        let (_ : (t, Diff_versioned.Rejected.t) Type_equal.t) = Type_equal.T
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
        Printf.sprintf
          !"Transaction_pool_diff of length %d with fee payer summary %s"
          (List.length t)
          ( String.concat ~sep:","
          @@ List.map ~f:User_command.fee_payer_summary_string t )

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

      let report_command_error ~logger ~is_sender_local tx (e : Command_error.t)
          =
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

      (** DO NOT mutate any transaction pool state in this function, you may only mutate in the synchronous `apply` function. *)
      let verify (t : pool) (diff : t Envelope.Incoming.t) :
          ( verified Envelope.Incoming.t
          , Intf.Verification_error.t )
          Deferred.Result.t =
        let open Deferred.Result.Let_syntax in
        let open Intf.Verification_error in
        let%bind () =
          let well_formedness_errors =
            List.fold (Envelope.Incoming.data diff) ~init:[]
              ~f:(fun acc user_cmd ->
                match
                  User_command.check_well_formedness
                    ~genesis_constants:t.config.genesis_constants user_cmd
                with
                | Ok () ->
                    acc
                | Error errs ->
                    [%log' debug t.logger]
                      "User command $cmd from $sender has one or more \
                       well-formedness errors."
                      ~metadata:
                        [ ("cmd", User_command.to_yojson user_cmd)
                        ; ( "sender"
                          , Envelope.(Sender.to_yojson (Incoming.sender diff))
                          )
                        ; ( "errors"
                          , `List
                              (List.map errs
                                 ~f:User_command.Well_formedness_error.to_yojson )
                          )
                        ] ;
                    errs @ acc )
          in
          match
            List.dedup_and_sort well_formedness_errors
              ~compare:User_command.Well_formedness_error.compare
          with
          | [] ->
              return ()
          | errs ->
              let err_str =
                List.map errs ~f:User_command.Well_formedness_error.to_string
                |> String.concat ~sep:","
              in
              Deferred.Result.fail
              @@ Invalid
                   (Error.createf
                      "Some commands have one or more well-formedness errors: \
                       %s "
                      err_str )
        in
        let%bind ledger =
          match t.best_tip_ledger with
          | Some ledger ->
              return ledger
          | None ->
              Deferred.Result.fail
              @@ Failure
                   (Error.of_string
                      "We don't have a transition frontier at the moment, so \
                       we're unable to verify any transactions." )
        in

        let%bind diff' =
          O1trace.sync_thread "convert_transactions_to_verifiable" (fun () ->
              Envelope.Incoming.map diff ~f:(fun diff ->
                  User_command.Unapplied_sequence.to_all_verifiable diff
                    ~load_vk_cache:(fun account_ids ->
                      let account_ids = Set.to_list account_ids in
                      let ledger_vks =
                        Zkapp_command.Verifiable.load_vks_from_ledger
                          ~location_of_account_batch:
                            (Base_ledger.location_of_account_batch ledger)
                          ~get_batch:(Base_ledger.get_batch ledger)
                          account_ids
                      in
                      let ledger_vks =
                        Map.map ledger_vks ~f:(fun vk ->
                            Zkapp_basic.F_map.Map.singleton vk.hash vk )
                      in
                      let mempool_vks =
                        List.map account_ids ~f:(fun account_id ->
                            let vks =
                              Vk_refcount_table.find_vks_by_account_id
                                t.verification_key_table account_id
                            in
                            let vks =
                              vks
                              |> List.map ~f:(fun vk -> (vk.hash, vk))
                              |> Zkapp_basic.F_map.Map.of_alist_exn
                            in
                            (account_id, vks) )
                        |> Account_id.Map.of_alist_exn
                      in
                      Map.merge_skewed ledger_vks mempool_vks
                        ~combine:(fun ~key:_ ->
                          Map.merge_skewed ~combine:(fun ~key:_ _ x -> x) ) ) ) )
          |> Envelope.Incoming.lift_error
          |> Result.map_error ~f:(fun e -> Invalid e)
          |> Deferred.return
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
            Deferred.Result.fail (Failure e)
        | Ok (Error invalid) ->
            let err = Verifier.invalid_to_error invalid in
            [%log' error t.logger]
              "Batch verification failed when adding from gossip"
              ~metadata:[ ("error", Error_json.error_to_yojson err) ] ;
            let%map.Deferred () =
              Trust_system.record_envelope_sender t.config.trust_system t.logger
                (Envelope.Incoming.sender diff)
                ( Trust_system.Actions.Sent_useless_gossip
                , Some
                    ( "rejecting command because had invalid signature or proof"
                    , [] ) )
            in
            Error (Invalid err)
        | Ok (Ok commands) ->
            (* TODO: avoid duplicate hashing (#11706) *)
            O1trace.sync_thread "hashing_transactions_after_verification"
              (fun () ->
                return
                  { diff with
                    data =
                      List.map commands
                        ~f:
                          Transaction_hash.User_command_with_valid_signature
                          .create
                  } )

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

      (* This must be synchronous, but you MAY modify state here (do not modify pool state in `verify` *)
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
          let already_in_pool =
            Indexed_pool.member pool
              (Transaction_hash.User_command.of_checked cmd)
          in
          let%map.Result () =
            if already_in_pool then
              if is_sender_local then Ok () else Error Diff_error.Duplicate
            else
              match Map.find fee_payer_accounts (fee_payer cmd) with
              | None ->
                  Error Diff_error.Fee_payer_account_not_found
              | Some account ->
                  Result.ok_if_true
                    ( Account.has_permission_to_send account
                    && Account.has_permission_to_increment_nonce account )
                    ~error:Diff_error.Fee_payer_not_permitted_to_send
          in
          already_in_pool
        in
        (* Dedicated variant to track whether the transaction was already in
           the pool. We use this to signal that the user wants to re-broadcast
           a txn that already exists in their local pool.
        *)
        let module Command_state = struct
          type t = New_command | Rebroadcast
        end in
        let pool, add_results =
          List.fold_map (Envelope.Incoming.data diff) ~init:t.pool
            ~f:(fun pool cmd ->
              let result =
                let%bind.Result already_in_pool = check_command pool cmd in
                let global_slot =
                  Indexed_pool.global_slot_since_genesis t.pool
                in
                let account = Map.find_exn fee_payer_accounts (fee_payer cmd) in
                if already_in_pool then
                  Ok ((cmd, pool, Sequence.empty), Command_state.Rebroadcast)
                else
                  match
                    Indexed_pool.add_from_gossip_exn pool cmd account.nonce
                      ( Account.liquid_balance_at_slot ~global_slot account
                      |> Currency.Balance.to_amount )
                  with
                  | Ok x ->
                      Ok (x, Command_state.New_command)
                  | Error err ->
                      report_command_error ~logger:t.logger ~is_sender_local
                        (Transaction_hash.User_command_with_valid_signature
                         .command cmd )
                        err ;
                      Error (diff_error_of_indexed_pool_error err)
              in
              match result with
              | Ok ((cmd', pool', dropped), cmd_state) ->
                  (pool', Ok (cmd', dropped, cmd_state))
              | Error err ->
                  (pool, Error (cmd, err)) )
        in
        let added_cmds =
          List.filter_map add_results ~f:(function
            | Ok (cmd, _, Command_state.New_command) ->
                Some cmd
            | Ok (_, _, Command_state.Rebroadcast) | Error _ ->
                None )
        in
        let dropped_for_add =
          List.filter_map add_results ~f:(function
            | Ok (_, dropped, Command_state.New_command) ->
                Some (Sequence.to_list dropped)
            | Ok (_, _, Command_state.Rebroadcast) | Error _ ->
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

        (* apply changes to the vk-refcount-table here *)
        let () =
          let lift = Vk_refcount_table.lift_hashed t.verification_key_table in
          List.iter added_cmds ~f:(lift Vk_refcount_table.inc) ;
          List.iter all_dropped_cmds
            ~f:
              (lift (fun t ~account_id ~vk ->
                   Vk_refcount_table.dec t ~account_id ~vk_hash:vk.hash ) )
        in
        let dropped_for_add_hashes =
          List.map dropped_for_add
            ~f:Transaction_hash.User_command_with_valid_signature.hash
          |> Transaction_hash.Set.of_list
        in
        let dropped_for_size_hashes =
          List.map dropped_for_size
            ~f:Transaction_hash.User_command_with_valid_signature.hash
          |> Transaction_hash.Set.of_list
        in
        let all_dropped_cmd_hashes =
          Transaction_hash.Set.union dropped_for_add_hashes
            dropped_for_size_hashes
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
            | Ok (cmd, _dropped, _command_type) ->
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
        let accepted, rejected, _dropped =
          List.partition3_map add_results ~f:(function
            | Ok (cmd, _dropped, _cmd_state) ->
                (* NB: We ignore the command state here, so that commands only
                   for rebroadcast are still included in the bundle that we
                   rebroadcast.
                *)
                if
                  Set.mem all_dropped_cmd_hashes
                    (Transaction_hash.User_command_with_valid_signature.hash cmd)
                then `Trd cmd
                else `Fst cmd
            | Error (cmd, error) ->
                `Snd (cmd, error) )
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

      let unsafe_apply (t : pool) (diff : verified Envelope.Incoming.t) :
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

      type Structured_log_events.t +=
        | Transactions_received of
            { fee_payer_summaries : User_command.fee_payer_summary_t list
            ; sender : Envelope.Sender.t
            }
        [@@deriving
          register_event
            { msg =
                "Received transaction-pool $fee_payer_summaries from $sender"
            }]

      let update_metrics ~logger ~log_gossip_heard envelope valid_cb =
        Mina_metrics.(Counter.inc_one Network.gossip_messages_received) ;
        Mina_metrics.(Gauge.inc_one Network.transaction_pool_diff_received) ;
        let diff = Envelope.Incoming.data envelope in
        if log_gossip_heard then (
          let fee_payer_summaries =
            List.map ~f:User_command.fee_payer_summary diff
          in
          [%str_log debug]
            (Transactions_received
               { fee_payer_summaries
               ; sender = Envelope.Incoming.sender envelope
               } ) ;
          Mina_net2.Validation_callback.set_message_type valid_cb `Transaction ;
          Mina_metrics.(Counter.inc_one Network.Transaction.received) )

      let log_internal ?reason ~logger msg
          { Envelope.Incoming.data = diff; sender; _ } =
        let metadata =
          [ ( "diff"
            , `List
                (List.map diff
                   ~f:Mina_transaction.Transaction.yojson_summary_of_command )
            )
          ]
        in
        let metadata =
          match sender with
          | Remote addr ->
              ("sender", `String (Core.Unix.Inet_addr.to_string @@ Peer.ip addr))
              :: metadata
          | Local ->
              metadata
        in
        let metadata =
          Option.value_map reason
            ~f:(fun r -> List.cons ("reason", `String r))
            ~default:ident metadata
        in
        if not (is_empty diff) then
          [%log internal] "%s" ("Transaction_diff_" ^ msg) ~metadata

      let t_of_verified =
        List.map ~f:Transaction_hash.User_command_with_valid_signature.command
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