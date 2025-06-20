(** A pool of transactions that can be included in future blocks. Combined with
    the Network_pool module, this handles storing and gossiping the correct
    transactions (user commands) and providing them to the block producer code.
*)

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
  type t = User_command.Stable.Latest.t list [@@deriving to_yojson]

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
  [@@deriving to_yojson]

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
      { transaction_hash : Transaction_hash.t
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
        ; vk_cache_db : Zkapp_vk_cache_tag.cache_db
        ; proof_cache_db : Proof_cache_tag.cache_db
        }

      (* remove next line if there's a way to force [@@deriving make] write a
         named parameter instead of an optional parameter *)
      let make ~trust_system ~pool_max_size ~verifier ~genesis_constants
          ~slot_tx_end ~vk_cache_db ~proof_cache_db =
        { trust_system
        ; pool_max_size
        ; verifier
        ; genesis_constants
        ; slot_tx_end
        ; vk_cache_db
        ; proof_cache_db
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
            (int * Zkapp_vk_cache_tag.t) Zkapp_basic.F_map.Table.t
        ; account_id_to_vks : int Zkapp_basic.F_map.Map.t Account_id.Table.t
        ; vk_to_account_ids : int Account_id.Map.t Zkapp_basic.F_map.Table.t
        ; vk_cache_db : Zkapp_vk_cache_tag.cache_db
        }

      let create vk_cache_db () =
        { verification_keys = Zkapp_basic.F_map.Table.create ()
        ; account_id_to_vks = Account_id.Table.create ()
        ; vk_to_account_ids = Zkapp_basic.F_map.Table.create ()
        ; vk_cache_db
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
              (1, Zkapp_vk_cache_tag.write_key_to_disk t.vk_cache_db vk)
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
      ; locally_generated_uncommitted : Locally_generated.t
            (** Commands generated on this machine, that are not included in the
          current best tip, along with the time they were added. *)
      ; locally_generated_committed : Locally_generated.t
            (** Ones that are included in the current best tip. *)
      ; mutable current_batch : int
      ; mutable remaining_in_batch : int
      ; config : Config.t
      ; logger : Logger.t
      ; batcher : Batcher.t
      ; mutable best_tip_diff_relay : unit Deferred.t Option.t
      ; mutable best_tip_ledger : Base_ledger.t Option.t
      ; verification_key_table : Vk_refcount_table.t
      }

    let member t x = Indexed_pool.member t.pool x

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
                Locally_generated.find_and_remove t.locally_generated_committed
                  cmd
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
                Locally_generated.add_exn t.locally_generated_uncommitted
                  ~key:cmd ~data:time_added ) ;
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
          ~f:(Locally_generated.mem t.locally_generated_uncommitted)
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
                |> Transaction_hash.User_command_with_valid_signature
                   .transaction_hash
              in
              Set.add set cmd_hash )
        in
        Sequence.to_list dropped_commands
        |> List.partition_tf ~f:(fun cmd ->
               Set.mem command_hashes
                 (Transaction_hash.User_command_with_valid_signature
                  .transaction_hash cmd ) )
      in
      List.iter committed_commands ~f:(fun cmd ->
          vk_table_lift_hashed vk_table_dec cmd ;
          Locally_generated.find_and_remove t.locally_generated_uncommitted cmd
          |> Option.iter ~f:(fun data ->
                 Locally_generated.add_exn t.locally_generated_committed
                   ~key:cmd ~data ) ) ;
      let commit_conflicts_locally_generated =
        List.filter dropped_commit_conflicts ~f:(fun cmd ->
            Locally_generated.find_and_remove t.locally_generated_uncommitted
              cmd
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
              @@ Locally_generated.find_and_remove
                   t.locally_generated_uncommitted cmd )
          in
          let log_and_remove ?(metadata = []) error_str =
            log_indexed_pool_error error_str ~metadata cmd ;
            remove_cmd ()
          in
          if not (Locally_generated.mem t.locally_generated_committed cmd) then
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
            ( Locally_generated.find_and_remove t.locally_generated_uncommitted
                cmd
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
        ; locally_generated_uncommitted = Locally_generated.create ()
        ; locally_generated_committed = Locally_generated.create ()
        ; current_batch = 0
        ; remaining_in_batch = max_per_15_seconds
        ; config
        ; logger
        ; batcher =
            Batcher.create ~proof_cache_db:config.proof_cache_db ~logger
              config.verifier
        ; best_tip_diff_relay = None
        ; best_tip_ledger = None
        ; verification_key_table =
            Vk_refcount_table.create config.vk_cache_db ()
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
                         Locally_generated.find_and_remove tbl cmd
                         |> Option.is_some
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
      type t = User_command.Stable.Latest.t list

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
        type t = (User_command.Stable.Latest.t * Diff_error.t) list

        let (_ : (t, Diff_versioned.Rejected.t) Type_equal.t) = Type_equal.T
      end

      type rejected = Rejected.t

      type verified = Diff_versioned.verified [@@deriving to_yojson]

      let reject_overloaded_diff (diff : verified) : rejected =
        List.map diff ~f:(fun cmd ->
            ( Transaction_hash.User_command_with_valid_signature.command cmd
              |> User_command.read_all_proofs_from_disk
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

      let report_command_error ~logger ~is_sender_local transaction_hash
          (e : Command_error.t) =
        let diff_err, error_extra = of_indexed_pool_error e in
        if is_sender_local then
          [%str_log error]
            (Rejecting_command_for_reason
               { transaction_hash; reason = diff_err; error_extra } ) ;
        let log = if is_sender_local then [%log error] else [%log debug] in
        match e with
        | Insufficient_replace_fee (`Replace_fee rfee, fee) ->
            log
              "rejecting command with hash $transaction_hash because of \
               insufficient replace fee ($rfee > $fee)"
              ~metadata:
                [ ( "transaction_hash"
                  , Transaction_hash.to_yojson transaction_hash )
                ; ("rfee", Currency.Fee.to_yojson rfee)
                ; ("fee", Currency.Fee.to_yojson fee)
                ]
        | Unwanted_fee_token fee_token ->
            log
              "rejecting command with hash $transaction_hash because we don't \
               accept fees in $token"
              ~metadata:
                [ ( "transaction_hash"
                  , Transaction_hash.to_yojson transaction_hash )
                ; ("token", Token_id.to_yojson fee_token)
                ]
        | _ ->
            ()

      let load_vk_cache ~t ~ledger account_ids =
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
                |> List.map ~f:(fun vk_cached ->
                       let vk =
                         Zkapp_vk_cache_tag.read_key_from_disk vk_cached
                       in
                       (vk.hash, vk) )
                |> Zkapp_basic.F_map.Map.of_alist_exn
              in
              (account_id, vks) )
          |> Account_id.Map.of_alist_exn
        in
        Map.merge_skewed ledger_vks mempool_vks ~combine:(fun ~key:_ ->
            Map.merge_skewed ~combine:(fun ~key:_ _ x -> x) )

      (** DO NOT mutate any transaction pool state in this function, you may only mutate in the synchronous `apply` function. *)
      let verify (t : pool)
          Envelope.Incoming.{ data = diff; sender; received_at } :
          ( verified Envelope.Incoming.t
          , Intf.Verification_error.t )
          Deferred.Result.t =
        let signature_kind = Mina_signature_kind.t_DEPRECATED in
        let open Deferred.Result.Let_syntax in
        let open Intf.Verification_error in
        let%bind () =
          let well_formedness_errors =
            List.fold diff ~init:[] ~f:(fun acc user_cmd ->
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
                        [ ("cmd", User_command.Stable.Latest.to_yojson user_cmd)
                        ; ("sender", Envelope.Sender.to_yojson sender)
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
        let%bind verified_diff =
          O1trace.sync_thread "convert_transactions_to_verifiable" (fun () ->
              List.map
                ~f:
                  (User_command.write_all_proofs_to_disk ~signature_kind
                     ~proof_cache_db:t.config.proof_cache_db )
                diff
              |> User_command.Unapplied_sequence.to_all_verifiable
                   ~load_vk_cache:(load_vk_cache ~t ~ledger) )
          |> Result.map_error ~f:(fun e -> Invalid e)
          |> Deferred.return
        in
        match%bind.Deferred
          O1trace.thread "batching_transaction_verification" (fun () ->
              Batcher.verify t.batcher
                { Envelope.Incoming.data = verified_diff; received_at; sender } )
        with
        | Error e ->
            [%log' error t.logger] "Transaction verification error: $error"
              ~metadata:[ ("error", `String (Error.to_string_hum e)) ] ;
            [%log' debug t.logger]
              "Failed to batch verify $transaction_pool_diff"
              ~metadata:
                [ ("transaction_pool_diff", Diff_versioned.to_yojson diff) ] ;
            Deferred.Result.fail (Failure e)
        | Ok (Error invalid) ->
            let err = Verifier.invalid_to_error invalid in
            [%log' error t.logger]
              "Batch verification failed when adding from gossip"
              ~metadata:[ ("error", Error_json.error_to_yojson err) ] ;
            let%map.Deferred () =
              Trust_system.record_envelope_sender t.config.trust_system t.logger
                sender
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
                  { Envelope.Incoming.received_at
                  ; sender
                  ; data =
                      List.map commands
                        ~f:
                          Transaction_hash.User_command_with_valid_signature
                          .create
                  } )

      let register_locally_generated t txn =
        Locally_generated.update t.locally_generated_uncommitted txn
          ~f:(function
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
              (Transaction_hash.User_command_with_valid_signature
               .transaction_hash cmd )
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
                         .transaction_hash cmd )
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
            ~f:
              Transaction_hash.User_command_with_valid_signature
              .transaction_hash
          |> Transaction_hash.Set.of_list
        in
        let dropped_for_size_hashes =
          List.map dropped_for_size
            ~f:
              Transaction_hash.User_command_with_valid_signature
              .transaction_hash
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
              Locally_generated.find_and_remove t.locally_generated_uncommitted
                cmd
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
                       (Transaction_hash.User_command_with_valid_signature
                        .transaction_hash cmd ) )
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
                    (Transaction_hash.User_command_with_valid_signature
                     .transaction_hash cmd )
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
            let f =
              Fn.compose User_command.read_all_proofs_from_disk
                Transaction_hash.User_command_with_valid_signature.command
            in
            Ok
              ( decision
              , List.map ~f accepted
              , List.map ~f:(Tuple2.map_fst ~f) rejected )
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
        List.map
          ~f:
            (Fn.compose User_command.read_all_proofs_from_disk
               Transaction_hash.User_command_with_valid_signature.command )
    end

    let get_rebroadcastable (t : t) ~has_timed_out : Diff.t list =
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
      Locally_generated.filteri_inplace t.locally_generated_uncommitted
        ~f:(fun ~key ~data:(time, `Batch _) ->
          match has_timed_out time with
          | `Timed_out ->
              [%log info]
                "No longer rebroadcasting uncommitted command $cmd, %s"
                added_str ~metadata:(metadata ~key ~time) ;
              false
          | `Ok ->
              true ) ;
      Locally_generated.filteri_inplace t.locally_generated_committed
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
      Locally_generated.to_alist t.locally_generated_uncommitted
      |> List.sort
           ~compare:(fun (txn1, (_, `Batch batch1)) (txn2, (_, `Batch batch2))
                    ->
             let cmp = compare batch1 batch2 in
             let get_hash =
               Transaction_hash.User_command_with_valid_signature
               .transaction_hash
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
                  Transaction_hash.User_command_with_valid_signature.command txn
                  |> User_command.read_all_proofs_from_disk ) )
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

    let block_window_duration =
      Mina_compile_config.For_unit_tests.t.block_window_duration

    (* keys that can be used when generating new accounts *)
    let extra_keys =
      Array.init num_extra_keys ~f:(fun _ -> Signature_lib.Keypair.create ())

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let signature_kind = Mina_signature_kind.Testnet

    let constraint_constants = precomputed_values.constraint_constants

    let consensus_constants = precomputed_values.consensus_constants

    let proof_level = precomputed_values.proof_level

    let genesis_constants = precomputed_values.genesis_constants

    let minimum_fee =
      Currency.Fee.to_nanomina_int genesis_constants.minimum_user_command_fee

    let logger = Logger.null ()

    let time_controller = Block_time.Controller.basic ~logger

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default ~constraint_constants ~logger ~proof_level
            () )

    let `VK vk, `Prover prover =
      Transaction_snark.For_tests.create_trivial_snapp ()

    let vk = Async.Thread_safe.block_on_async_exn (fun () -> vk)

    let dummy_state_view =
      let state_body =
        let consensus_constants =
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
        global_slot_since_genesis = Mina_numbers.Global_slot_since_genesis.zero
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

      let create ?permissions :
          unit -> t * best_tip_diff Broadcast_pipe.Writer.t =
       fun () ->
        let zkappify_account (account : Account.t) : Account.t =
          let zkapp =
            Some { Zkapp_account.default with verification_key = Some vk }
          in
          { account with
            zkapp
          ; permissions =
              ( match permissions with
              | Some p ->
                  p
              | None ->
                  Permissions.user_default )
          }
        in
        let pipe_r, pipe_w =
          Broadcast_pipe.create
            { new_commands = []; removed_commands = []; reorg_best_tip = false }
        in
        let initial_balance =
          Currency.Balance.of_mina_string_exn "900000000.0"
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

    let apply_initial_ledger_state t init_ledger_state =
      let new_ledger =
        Mina_ledger.Ledger.create_ephemeral
          ~depth:(Mina_ledger.Ledger.depth !(t.best_tip_ref))
          ()
      in
      Mina_ledger.Ledger.apply_initial_ledger_state new_ledger init_ledger_state ;
      t.best_tip_ref := new_ledger

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
              Core.Printf.printf !"  %{Sexp}\n"
                (User_command.Stable.Latest.sexp_of_t c) )
        in
        if List.length additional1 > 0 then
          report_additional additional1 "actual" "expected" ;
        if List.length additional2 > 0 then
          report_additional additional2 "expected" "actual" ) ;
      [%test_eq: Transaction_hash.Set.t] set1 set2

    let replace_valid_zkapp_command_authorizations ~keymap ~ledger valid_cmds :
        User_command.Valid.t list Deferred.t =
      let open Deferred.Let_syntax in
      let%map zkapp_commands_fixed =
        Deferred.List.map
          (valid_cmds : User_command.Valid.t list)
          ~f:(function
            | Zkapp_command zkapp_command_dummy_auths ->
                let%map cmd =
                  Zkapp_command_builder.replace_authorizations ~keymap ~prover
                    (Zkapp_command.Valid.forget zkapp_command_dummy_auths)
                in
                User_command.Zkapp_command cmd
            | Signed_command _ ->
                failwith "Expected Zkapp_command valid user command" )
      in
      match
        User_command.Unapplied_sequence.to_all_verifiable zkapp_commands_fixed
          ~load_vk_cache:(fun account_ids ->
            Set.to_list account_ids
            |> Zkapp_command.Verifiable.load_vks_from_ledger
                 ~get_batch:(Mina_ledger.Ledger.get_batch ledger)
                 ~location_of_account_batch:
                   (Mina_ledger.Ledger.location_of_account_batch ledger)
            |> Map.map ~f:(fun vk ->
                   Zkapp_basic.F_map.Map.singleton vk.hash vk ) )
        |> Or_error.bind ~f:(fun xs ->
               List.map xs
                 ~f:(User_command.For_tests.check_verifiable ~signature_kind)
               |> Or_error.combine_errors )
      with
      | Ok cmds ->
          cmds
      | Error err ->
          Error.raise
          @@ Error.tag ~tag:"Could not create Zkapp_command.Valid.t" err

    (** Assert the invariants of the locally generated command tracking system. *)
    let assert_locally_generated (pool : Test.Resource_pool.t) =
      Locally_generated.iter_intersection pool.locally_generated_committed
        pool.locally_generated_uncommitted
        ~f:(fun ~key (committed, _) (uncommitted, _) ->
          failwithf
            !"Command \
              %{sexp:Transaction_hash.User_command_with_valid_signature.t} in \
              both locally generated committed and uncommitted with times %s \
              and %s"
            key (Time.to_string committed)
            (Time.to_string uncommitted)
            () ) ;
      Locally_generated.iteri pool.locally_generated_uncommitted
        ~f:(fun ~key ~data:_ ->
          assert (
            Indexed_pool.member pool.pool
              (Transaction_hash.User_command_with_valid_signature
               .transaction_hash key ) ) )

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
      Indexed_pool.For_tests.assert_pool_consistency test.txn_pool.pool ;
      assert_locally_generated test.txn_pool ;
      assert_fee_wu_ordering test.txn_pool ;
      assert_user_command_sets_equal
        ( Sequence.to_list
        @@ Sequence.map ~f:Transaction_hash.User_command.of_checked
        @@ Test.Resource_pool.transactions test.txn_pool )
        (List.map
           ~f:(fun tx ->
             Transaction_hash.User_command.create
               User_command.(forget_check tx |> read_all_proofs_from_disk) )
           txs )

    let setup_test ?(verifier = verifier) ?permissions ?slot_tx_end () =
      let frontier, best_tip_diff_w =
        Mock_transition_frontier.create ?permissions ()
      in
      let _, best_tip_ref = frontier in
      let frontier_pipe_r, frontier_pipe_w =
        Broadcast_pipe.create @@ Some frontier
      in
      let trust_system = Trust_system.null () in
      let config =
        Test.Resource_pool.make_config ~trust_system ~pool_max_size ~verifier
          ~genesis_constants ~slot_tx_end
          ~vk_cache_db:(Zkapp_vk_cache_tag.For_tests.create_db ())
          ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
      in
      let pool_, _, _ =
        Test.create ~config ~logger ~constraint_constants ~consensus_constants
          ~time_controller ~frontier_broadcast_pipe:frontier_pipe_r
          ~log_gossip_heard:false ~on_remote_push:(Fn.const Deferred.unit)
          ~block_window_duration
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
            let signature_kind = Mina_signature_kind.t_DEPRECATED in
            User_command.Valid.Gen.payment ~sign_type:(`Real signature_kind)
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
      let signature_kind = Mina_signature_kind.t_DEPRECATED in
      let get_pk idx = Public_key.compress test_keys.(idx).public_key in
      Signed_command.sign ~signature_kind test_keys.(sender_idx)
        (Signed_command_payload.create
           ~fee:(Currency.Fee.of_nanomina_int_exn fee)
           ~fee_payer_pk:(get_pk sender_idx) ~valid_until
           ~nonce:(Account.Nonce.of_int nonce)
           ~memo:(Signed_command_memo.create_by_digesting_string_exn "foo")
           ~body:
             (Signed_command_payload.Body.Payment
                { receiver_pk = get_pk receiver_idx
                ; amount = Currency.Amount.of_nanomina_int_exn amount
                } ) )

    let mk_single_account_update ~fee_payer_idx ~zkapp_account_idx ~fee ~nonce
        ~ledger =
      let fee = Currency.Fee.of_nanomina_int_exn fee in
      let fee_payer_kp = test_keys.(fee_payer_idx) in
      let nonce = Account.Nonce.of_int nonce in
      let spec : Transaction_snark.For_tests.Single_account_update_spec.t =
        Transaction_snark.For_tests.Single_account_update_spec.
          { fee_payer = (fee_payer_kp, nonce)
          ; fee
          ; memo = Signed_command_memo.create_from_string_exn "invalid proof"
          ; zkapp_account_keypair = test_keys.(zkapp_account_idx)
          ; update = { Account_update.Update.noop with zkapp_uri = Set "abcd" }
          ; call_data = Snark_params.Tick.Field.zero
          ; events = []
          ; actions = []
          }
      in
      let%map zkapp_command =
        Transaction_snark.For_tests.single_account_update ~constraint_constants
          spec
      in
      Or_error.ok_exn
        (Zkapp_command.Verifiable.create ~failed:false
           ~find_vk:
             (Zkapp_command.Verifiable.load_vk_from_ledger
                ~get:(Mina_ledger.Ledger.get ledger)
                ~location_of_account:
                  (Mina_ledger.Ledger.location_of_account ledger) )
           zkapp_command )

    let mk_transfer_zkapp_command ?valid_period ?fee_payer_idx ~sender_idx
        ~receiver_idx ~fee ~nonce ~amount () =
      let sender_kp = test_keys.(sender_idx) in
      let sender_nonce = Account.Nonce.of_int nonce in
      let sender = (sender_kp, sender_nonce) in
      let amount = Currency.Amount.of_nanomina_int_exn amount in
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
      let fee = Currency.Fee.of_nanomina_int_exn fee in
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
        ; actions = []
        ; preconditions =
            Some
              { Account_update.Preconditions.network =
                  protocol_state_precondition
              ; account =
                  (let nonce =
                     if Option.is_none fee_payer then
                       Account.Nonce.succ sender_nonce
                     else sender_nonce
                   in
                   Zkapp_precondition.Account.nonce nonce )
              ; valid_while = Ignore
              }
        }
      in
      let zkapp_command =
        Transaction_snark.For_tests.multiple_transfers ~constraint_constants
          test_spec
      in
      let zkapp_command =
        Or_error.ok_exn
          (Zkapp_command.Valid.For_tests.to_valid ~failed:false
             ~find_vk:
               (Zkapp_command.Verifiable.load_vk_from_ledger
                  ~get:(fun _ -> failwith "Not expecting proof zkapp_command")
                  ~location_of_account:(fun _ ->
                    failwith "Not expecting proof zkapp_command" ) )
             zkapp_command )
      in
      User_command.Zkapp_command zkapp_command

    let mk_payment ?valid_until ~sender_idx ~receiver_idx ~fee ~nonce ~amount ()
        =
      User_command.Signed_command
        (mk_payment' ?valid_until ~sender_idx ~fee ~nonce ~receiver_idx ~amount
           () )

    let mk_zkapp_commands_single_block num_cmds (pool : Test.Resource_pool.t) :
        User_command.Valid.t list Deferred.t =
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
        if n >= num_cmds then Quickcheck.Generator.return @@ List.rev cmds
        else
          let%bind cmd =
            let fee_payer_keypair = test_keys.(n) in
            let%map (zkapp_command : Zkapp_command.t) =
              Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
                ~max_token_updates:1 ~keymap ~account_state_tbl
                ~fee_payer_keypair ~ledger:best_tip_ledger ~constraint_constants
                ~genesis_constants
                ~map_account_update:(fun p ->
                  Zkapp_command.For_tests.replace_vk vk
                    { p with
                      body =
                        { p.body with
                          preconditions =
                            { p.body.preconditions with
                              account =
                                ( match p.body.preconditions.account.nonce with
                                | Zkapp_basic.Or_ignore.Check n as c
                                  when Zkapp_precondition.Numeric.(
                                         is_constant Tc.nonce c) ->
                                    Zkapp_precondition.Account.nonce n.lower
                                | _ ->
                                    Zkapp_precondition.Account.accept )
                            }
                        }
                    } )
                ()
            in
            let valid_zkapp_command =
              Or_error.ok_exn
                (Zkapp_command.Valid.For_tests.to_valid ~failed:false
                   ~find_vk:
                     (Zkapp_command.Verifiable.load_vk_from_ledger
                        ~get:(Mina_ledger.Ledger.get best_tip_ledger)
                        ~location_of_account:
                          (Mina_ledger.Ledger.location_of_account
                             best_tip_ledger ) )
                   zkapp_command )
            in
            User_command.Zkapp_command valid_zkapp_command
          in
          go (n + 1) (cmd :: cmds)
      in
      let valid_zkapp_commands =
        Quickcheck.random_value ~seed:(`Deterministic "zkapp_command") (go 0 [])
      in
      replace_valid_zkapp_command_authorizations ~keymap ~ledger:best_tip_ledger
        valid_zkapp_commands

    type pool_apply =
      (User_command.Stable.Latest.t list, [ `Other of Error.t ]) Result.t
    [@@deriving sexp, compare]

    let canonicalize t =
      Result.map t ~f:(List.sort ~compare:User_command.Stable.Latest.compare)

    let compare_pool_apply (t1 : pool_apply) (t2 : pool_apply) =
      compare_pool_apply (canonicalize t1) (canonicalize t2)

    let assert_pool_apply expected_commands result =
      let accepted_commands =
        Result.map result ~f:(fun (_, accepted, _) -> accepted)
      in
      [%test_eq: pool_apply] accepted_commands
        (Ok
           (List.map
              ~f:
                User_command.(Fn.compose read_all_proofs_from_disk forget_check)
              expected_commands ) )

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
      let%map verified =
        Test.Resource_pool.Diff.verify test.txn_pool
          (Envelope.Incoming.wrap
             ~data:
               (List.map
                  ~f:
                    User_command.(
                      Fn.compose read_all_proofs_from_disk forget_check)
                  cs )
             ~sender )
        >>| Fn.compose Or_error.ok_exn
              (Result.map_error ~f:Intf.Verification_error.to_error)
      in
      let result =
        Test.Resource_pool.Diff.unsafe_apply test.txn_pool verified
      in
      let tm1 = Time.now () in
      [%log' info test.txn_pool.logger] "Time for add_commands: %0.04f sec"
        (Time.diff tm1 tm0 |> Time.Span.to_sec) ;
      let debug = false in
      ( match result with
      | Ok (`Accept, _, rejects) ->
          if debug then
            List.iter rejects ~f:(fun (cmd, err) ->
                Core.Printf.printf
                  !"command was rejected because %s: %{Yojson.Safe}\n%!"
                  (Diff_versioned.Diff_error.to_string_name err)
                  (User_command.Stable.Latest.to_yojson cmd) )
      | Ok (`Reject, _, _) ->
          failwith "diff was rejected during application"
      | Error (`Other err) ->
          if debug then
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
                     ~txn_global_slot:
                       Mina_numbers.Global_slot_since_genesis.zero ledger valid
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
                     ~signature_kind ~constraint_constants
                     ~global_slot:dummy_state_view.global_slot_since_genesis
                     ~state_view:dummy_state_view ledger p
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
      assert (
        not (phys_equal (Option.value_exn test.txn_pool.best_tip_ledger) ledger) ) ;
      assert (
        phys_equal
          (Option.value_exn test.txn_pool.best_tip_ledger)
          !(test.best_tip_ref) ) ;
      commit_commands test cs ;
      assert (
        not (phys_equal (Option.value_exn test.txn_pool.best_tip_ledger) ledger) ) ;
      assert (
        phys_equal
          (Option.value_exn test.txn_pool.best_tip_ledger)
          !(test.best_tip_ref) ) ;
      ledger

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
          balance = Currency.Balance.of_nanomina_int_exn balance
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
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_linear_case_test test )

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
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_remove_and_add_test test )

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
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_invalid_test test )

    let current_global_slot () =
      let current_time = Block_time.now time_controller in
      (* for testing, consider this slot to be a since-genesis slot *)
      Consensus.Data.Consensus_time.(
        of_time_exn ~constants:consensus_constants current_time
        |> to_global_slot)
      |> Mina_numbers.Global_slot_since_hard_fork.to_uint32
      |> Mina_numbers.Global_slot_since_genesis.of_uint32

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
          mk_zkapp_commands_single_block 7 test.txn_pool
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
      let slot_padding = Mina_numbers.Global_slot_span.of_int padding in
      let curr_slot_plus_padding =
        Mina_numbers.Global_slot_since_genesis.add curr_slot slot_padding
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
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_expired_not_accepted_test test ~padding:55 )

    let%test_unit "Expired transactions that are already in the pool are \
                   removed from the pool when best tip changes (user commands)"
        =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind t = setup_test () in
          assert_pool_txs t [] ;
          let curr_slot = current_global_slot () in
          let curr_slot_plus_three =
            Mina_numbers.Global_slot_since_genesis.add curr_slot
              (Mina_numbers.Global_slot_span.of_int 3)
          in
          let curr_slot_plus_seven =
            Mina_numbers.Global_slot_since_genesis.add curr_slot
              (Mina_numbers.Global_slot_span.of_int 7)
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
          let%bind t = setup_test () in
          assert_pool_txs t [] ;
          let curr_slot = current_global_slot () in
          let curr_slot_plus_three =
            Mina_numbers.Global_slot_since_genesis.add curr_slot
              (Mina_numbers.Global_slot_span.of_int 3)
          in
          let curr_slot_plus_seven =
            Mina_numbers.Global_slot_since_genesis.add curr_slot
              (Mina_numbers.Global_slot_span.of_int 7)
          in
          let few_now =
            List.take independent_cmds (List.length independent_cmds / 2)
          in
          let expires_later1 =
            mk_transfer_zkapp_command
              ~valid_period:{ lower = curr_slot; upper = curr_slot_plus_three }
              ~fee_payer_idx:(0, 1) ~sender_idx:1 ~receiver_idx:9
              ~fee:minimum_fee ~amount:10_000_000_000 ~nonce:1 ()
          in
          let expires_later2 =
            mk_transfer_zkapp_command
              ~valid_period:{ lower = curr_slot; upper = curr_slot_plus_seven }
              ~fee_payer_idx:(2, 1) ~sender_idx:3 ~receiver_idx:9
              ~fee:minimum_fee ~amount:10_000_000_000 ~nonce:1 ()
          in
          let valid_commands = few_now @ [ expires_later1; expires_later2 ] in
          let%bind () = add_commands' t valid_commands in
          assert_pool_txs t valid_commands ;
          let n_block_times n =
            Int64.(
              Block_time.Span.to_ms consensus_constants.block_window_duration_ms
              * n)
            |> Block_time.Span.of_ms
          in
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 4L))
          in
          let%bind () = reorg t [] [] in
          assert_pool_txs t (expires_later2 :: few_now) ;
          (* after 5 block times there should be no expired transactions *)
          let%bind () =
            after (Block_time.Span.to_time_span (n_block_times 5L))
          in
          let%bind () = reorg t [] [] in
          assert_pool_txs t few_now ; Deferred.unit )

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
      let signature_kind = Mina_signature_kind.Testnet in
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
              ; body = Payment payload
              }
          | { common; body = Stake_delegation (Set_delegate payload) } ->
              { common = { common with fee_payer_pk = sender_pk }
              ; body = Stake_delegation (Set_delegate payload)
              }
        in
        User_command.Signed_command
          (Signed_command.sign ~signature_kind sender_kp payload)
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
      let%bind () = add_commands' t txs_all in
      assert_pool_txs t txs_all ;
      let replace_txs =
        [ (* sufficient fee *)
          mk_payment ~sender_idx:0
            ~fee:
              ( minimum_fee
              + Currency.Fee.to_nanomina_int Indexed_pool.replace_fee )
            ~nonce:0 ~receiver_idx:1 ~amount:440_000_000_000 ()
        ; (* insufficient fee *)
          mk_payment ~sender_idx:1 ~fee:minimum_fee ~nonce:0 ~receiver_idx:1
            ~amount:788_000_000_000 ()
        ; (* sufficient *)
          mk_payment ~sender_idx:2
            ~fee:
              ( minimum_fee
              + Currency.Fee.to_nanomina_int Indexed_pool.replace_fee )
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
             Currency.Balance.to_nanomina_int account.balance - amount
           in
           mk_payment ~sender_idx:3 ~fee ~nonce:1 ~receiver_idx:4 ~amount () )
        ]
      in
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
      let signature_kind = Mina_signature_kind.Testnet in
      Quickcheck.test ~trials:500
        (let open Quickcheck.Generator.Let_syntax in
        let%bind init_ledger_state =
          Mina_ledger.Ledger.gen_initial_ledger_state
        in
        let%bind cmds_count = Int.gen_incl pool_max_size (pool_max_size * 2) in
        let%bind cmds =
          User_command.Valid.Gen.sequence ~sign_type:(`Real signature_kind)
            ~length:cmds_count init_ledger_state
        in
        return (init_ledger_state, cmds))
        ~f:(fun (init_ledger_state, cmds) ->
          Thread_safe.block_on_async_exn (fun () ->
              let%bind t = setup_test () in
              apply_initial_ledger_state t init_ledger_state ;
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
          [ List.map cmds ~f:(fun tx ->
                Transaction_hash.User_command.create
                  User_command.(forget_check tx |> read_all_proofs_from_disk) )
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
      (* reorg both removes and re-adds the first command (which is local) *)
      let%bind () = reorg t (List.take cmds 1) (List.take cmds 5) in
      assert_pool_txs t (List.slice cmds 1 7) ;
      assert_rebroadcastable t (List.nth_exn cmds 1 :: List.slice cmds 5 7) ;
      (* Committing them again removes them from the pool again. *)
      commit_commands t (List.slice cmds 1 5) ;
      let%bind () = reorg t (List.slice cmds 1 5) [] in
      assert_pool_txs t (List.slice cmds 5 7) ;
      assert_rebroadcastable t (List.slice cmds 5 7) ;
      (* When transactions expire from rebroadcast pool they are gone. This
         doesn't affect the main pool.
      *)
      t.best_tip_ref := checkpoint_1 ;
      let%bind () = reorg t [] (List.take cmds 5) in
      assert_pool_txs t (List.take cmds 7) ;
      assert_rebroadcastable t (List.take cmds 2 @ List.slice cmds 5 7) ;
      ignore
        ( Test.Resource_pool.get_rebroadcastable t.txn_pool
            ~has_timed_out:(Fn.const `Timed_out)
          : User_command.Stable.Latest.t list list ) ;
      assert_rebroadcastable t [] ;
      Deferred.unit

    let%test_unit "rebroadcastable transaction behavior (user cmds)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_rebroadcastable_test test independent_cmds )

    let%test_unit "rebroadcastable transaction behavior (zkapps)" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind test = setup_test () in
          mk_zkapp_commands_single_block 7 test.txn_pool
          >>= mk_rebroadcastable_test test )

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
            let%map cmds = mk_zkapp_commands_single_block 7 t.txn_pool in
            List.take cmds take_len
          in
          let user_cmds = List.drop independent_cmds take_len in
          let all_cmds = snapp_cmds @ user_cmds in
          assert_pool_txs t [] ;
          let%bind () = add_commands' t all_cmds in
          assert_pool_txs t all_cmds ; Deferred.unit )

    let mk_zkapp_user_cmd (pool : Test.Resource_pool.t) zkapp_command =
      let best_tip_ledger = Option.value_exn pool.best_tip_ledger in
      let keymap =
        Array.fold (Array.append test_keys extra_keys)
          ~init:Public_key.Compressed.Map.empty
          ~f:(fun map { public_key; private_key } ->
            let key = Public_key.compress public_key in
            Public_key.Compressed.Map.add_exn map ~key ~data:private_key )
      in
      let zkapp_command =
        Or_error.ok_exn
          (Zkapp_command.Valid.For_tests.to_valid ~failed:false
             ~find_vk:
               (Zkapp_command.Verifiable.load_vk_from_ledger
                  ~get:(Mina_ledger.Ledger.get best_tip_ledger)
                  ~location_of_account:
                    (Mina_ledger.Ledger.location_of_account best_tip_ledger) )
             zkapp_command )
      in
      let zkapp_command = User_command.Zkapp_command zkapp_command in
      let%bind zkapp_command =
        replace_valid_zkapp_command_authorizations ~keymap
          ~ledger:best_tip_ledger [ zkapp_command ]
      in
      let zkapp_command = List.hd_exn zkapp_command in
      Deferred.return zkapp_command

    let mk_basic_zkapp ?(fee = 10_000_000_000) ?(empty_update = false)
        ?preconditions ?permissions nonce fee_payer_kp =
      let open Zkapp_command_builder in
      let preconditions =
        Option.value preconditions
          ~default:
            Account_update.Preconditions.
              { network = Zkapp_precondition.Protocol_state.accept
              ; account = Zkapp_precondition.Account.accept
              ; valid_while = Ignore
              }
      in
      let update : Account_update.Update.t =
        let permissions =
          match permissions with
          | None ->
              Zkapp_basic.Set_or_keep.Keep
          | Some perms ->
              Zkapp_basic.Set_or_keep.Set perms
        in
        { Account_update.Update.noop with permissions }
      in
      let account_updates =
        if empty_update then []
        else
          mk_forest
            [ mk_node
                (mk_account_update_body Signature No fee_payer_kp
                   Token_id.default 0 ~preconditions ~update )
                []
            ]
      in
      account_updates
      |> mk_zkapp_command ~memo:"" ~fee
           ~fee_payer_pk:(Public_key.compress fee_payer_kp.public_key)
           ~fee_payer_nonce:(Account.Nonce.of_int nonce)

    let%test_unit "zkapp cmd with same nonce should replace previous submitted \
                   zkapp with same nonce" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind () = after (Time.Span.of_sec 2.) in
          let%bind t = setup_test () in
          assert_pool_txs t [] ;
          let fee_payer_kp = test_keys.(0) in
          let%bind valid_command1 =
            mk_basic_zkapp ~fee:10_000_000_000 0 fee_payer_kp
            |> mk_zkapp_user_cmd t.txn_pool
          in
          let%bind valid_command2 =
            mk_basic_zkapp ~fee:20_000_000_000 ~empty_update:true 0 fee_payer_kp
            |> mk_zkapp_user_cmd t.txn_pool
          in
          let%bind () =
            add_commands t ([ valid_command1 ] @ [ valid_command2 ])
            >>| assert_pool_apply [ valid_command2 ]
          in
          Deferred.unit )

    let%test_unit "commands are rejected if fee payer permissions are not \
                   handled" =
      let test_permissions ~is_able_to_send send_command permissions =
        let%bind t = setup_test () in
        assert_pool_txs t [] ;
        let%bind set_permissions_command =
          mk_basic_zkapp 0 test_keys.(0) ~permissions
          |> mk_zkapp_user_cmd t.txn_pool
        in
        let%bind () = add_commands' t [ set_permissions_command ] in
        let%bind () = advance_chain t [ set_permissions_command ] in
        assert_pool_txs t [] ;
        let%map result = add_commands t [ send_command ] in
        let expectation = if is_able_to_send then [ send_command ] else [] in
        assert_pool_apply expectation result
      in
      let run_test_cases send_cmd =
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.Signature
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.Either
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.None
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.Impossible
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              send = Permissions.Auth_required.Proof
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.Signature
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.Either
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.None
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.Impossible
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              increment_nonce = Permissions.Auth_required.Proof
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.Signature
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.Either
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:true send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.None
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.Impossible
            }
        in
        let%bind () =
          test_permissions ~is_able_to_send:false send_cmd
            { Permissions.user_default with
              access = Permissions.Auth_required.Proof
            }
        in
        return ()
      in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind () =
            let send_command =
              mk_payment ~sender_idx:0 ~fee:minimum_fee ~nonce:1 ~receiver_idx:1
                ~amount:1_000_000 ()
            in
            run_test_cases send_command
          in
          let%bind () =
            let send_command =
              mk_transfer_zkapp_command ~fee_payer_idx:(0, 1) ~sender_idx:0
                ~fee:minimum_fee ~nonce:2 ~receiver_idx:1 ~amount:1_000_000 ()
            in
            run_test_cases send_command
          in
          return () )

    let%test "account update with a different network id that uses proof \
              authorization would be rejected" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind verifier_full =
            Verifier.For_tests.default ~constraint_constants ~logger
              ~proof_level:Full ()
          in
          let%bind test =
            setup_test ~verifier:verifier_full
              ~permissions:
                { Permissions.user_default with set_zkapp_uri = Proof }
              ()
          in
          let%bind zkapp_command =
            mk_single_account_update ~fee_payer_idx:0 ~fee:minimum_fee ~nonce:0
              ~zkapp_account_idx:1
              ~ledger:(Option.value_exn test.txn_pool.best_tip_ledger)
          in
          let tx =
            User_command.Zkapp_command
              (Zkapp_command.Valid.For_tests.of_verifiable zkapp_command)
          in
          match%map
            Test.Resource_pool.Diff.verify test.txn_pool
              (Envelope.Incoming.wrap
                 ~data:
                   [ User_command.(forget_check tx |> read_all_proofs_from_disk)
                   ]
                 ~sender:Envelope.Sender.Local )
          with
          | Error (Intf.Verification_error.Invalid e) ->
              String.is_substring (Error.to_string_hum e) ~substring:"proof"
          | _ ->
              false )

    let%test_unit "transactions added before slot_tx_end are accepted" =
      Thread_safe.block_on_async_exn (fun () ->
          let curr_slot =
            Mina_numbers.(
              Global_slot_since_hard_fork.of_uint32
              @@ Global_slot_since_genesis.to_uint32 @@ current_global_slot ())
          in
          let slot_tx_end =
            Mina_numbers.Global_slot_since_hard_fork.(succ @@ succ curr_slot)
          in
          let%bind t = setup_test ~slot_tx_end () in
          assert_pool_txs t [] ;
          add_commands t independent_cmds >>| assert_pool_apply independent_cmds )

    let%test_unit "transactions added at slot_tx_end are rejected" =
      Thread_safe.block_on_async_exn (fun () ->
          let curr_slot =
            Mina_numbers.(
              Global_slot_since_hard_fork.of_uint32
              @@ Global_slot_since_genesis.to_uint32 @@ current_global_slot ())
          in
          let%bind t = setup_test ~slot_tx_end:curr_slot () in
          assert_pool_txs t [] ;
          add_commands t independent_cmds >>| assert_pool_apply [] )

    let%test_unit "transactions added after slot_tx_end are rejected" =
      Thread_safe.block_on_async_exn (fun () ->
          let curr_slot =
            Mina_numbers.(
              Global_slot_since_hard_fork.of_uint32
              @@ Global_slot_since_genesis.to_uint32 @@ current_global_slot ())
          in
          let slot_tx_end =
            Option.value_exn
            @@ Mina_numbers.(
                 Global_slot_since_hard_fork.(
                   sub curr_slot @@ Global_slot_span.of_int 1))
          in
          let%bind t = setup_test ~slot_tx_end () in
          assert_pool_txs t [] ;
          add_commands t independent_cmds >>| assert_pool_apply [] )

    let get_random_from_array arr =
      let open Quickcheck.Generator.Let_syntax in
      let%bind idx = Int.gen_incl 0 (Array.length arr - 1) in
      let item = arr.(idx) in
      return (idx, item)

    module Sender_info = struct
      type t = { key_idx : int; nonce : int } [@@deriving yojson]

      let to_key_and_nonce (t : t) =
        (Public_key.compress test_keys.(t.key_idx).public_key, t.nonce)
    end

    module Simple_account : sig
      type t [@@deriving to_yojson]

      val to_sender_info : t -> Sender_info.t

      val key_idx : t -> int

      val balance : t -> int

      val nonce : t -> int

      val seal : t -> t

      val subtract_balance : t -> int -> t

      val apply_cmd : int -> t -> t

      val apply_cmd_or_fail : amount:int -> fee:int -> t -> t * int

      val get_random_unsealed : t array -> (int * t) Quickcheck.Generator.t

      val of_account : key_idx:int -> Account.t -> t
    end = struct
      type t = { key_idx : int; balance : int; nonce : int; sealed : bool }
      [@@deriving yojson]

      let to_sender_info ({ key_idx; nonce; _ } : t) : Sender_info.t =
        { key_idx; nonce }

      let key_idx { key_idx; _ } = key_idx

      let balance { balance; _ } = balance

      let nonce { nonce; _ } = nonce

      let seal t =
        { key_idx = t.key_idx
        ; balance = t.balance
        ; nonce = t.nonce
        ; sealed = true
        }

      let can_apply amount t = amount < t.balance

      let subtract_balance t amount =
        { key_idx = t.key_idx
        ; balance = t.balance - amount
        ; nonce = t.nonce
        ; sealed = t.sealed
        }

      let apply_cmd amount t =
        { key_idx = t.key_idx
        ; balance = t.balance - amount
        ; nonce = t.nonce + 1
        ; sealed = t.sealed
        }

      let apply_cmd_or_fail ~amount ~fee t =
        if not (can_apply (amount + fee) t) then
          if not (can_apply fee t) then
            failwithf
              "cannot generate tx for key: %d as balance (%d) is less than fee \
               (%d)"
              t.key_idx t.balance fee ()
          else (apply_cmd fee t, 0)
        else (apply_cmd (amount + fee) t, amount)

      let get_random_unsealed (arr : t array) =
        let open Quickcheck.Generator.Let_syntax in
        let%bind item =
          Array.filter arr ~f:(fun x -> not x.sealed) |> Quickcheck_lib.of_array
        in
        return (item.key_idx, item)

      let of_account ~key_idx (account : Account.t) =
        { key_idx
        ; balance = Account.balance account |> Currency.Balance.to_nanomina_int
        ; nonce = Account.nonce account |> Account.Nonce.to_int
        ; sealed = false
        }
    end

    module Simple_ledger : sig
      type t [@@deriving to_yojson]

      type index

      val index_of_int : int -> index

      val index_to_int : index -> int

      val ledger_snapshot : test -> t

      val copy : t -> t

      val get : t -> index -> Simple_account.t

      val set : t -> index -> Simple_account.t -> unit

      val get_random_unsealed :
        t -> (index * Simple_account.t) Quickcheck.Generator.t

      val find_by_key_idx : t -> int -> Simple_account.t
    end = struct
      type t = Simple_account.t array [@@deriving to_yojson]

      type index = int

      let index_of_int x = x

      let index_to_int x = x

      let ledger_snapshot t =
        Array.mapi test_keys ~f:(fun key_idx kp ->
            let ledger = Option.value_exn t.txn_pool.best_tip_ledger in
            let account_id =
              Account_id.create
                (Public_key.compress kp.public_key)
                Token_id.default
            in
            let loc =
              Option.value_exn
              @@ Mina_ledger.Ledger.Ledger_inner.location_of_account ledger
                   account_id
            in
            let account =
              Option.value_exn @@ Mina_ledger.Ledger.Ledger_inner.get ledger loc
            in
            Simple_account.of_account ~key_idx account )

      let copy = Array.copy

      let get t idx = t.(idx)

      let set = Array.set

      let get_random_unsealed ledger = Simple_account.get_random_unsealed ledger

      let find_by_key_idx (ledger : t) key_idx = ledger.(key_idx)
    end

    module Simple_command = struct
      type t =
        | Payment of
            { sender : Sender_info.t
            ; receiver_idx : int
            ; fee : int
            ; amount : int
            }
        | Zkapp_blocking_send of { sender : Sender_info.t; fee : int }
      [@@deriving yojson]

      let gen_zkapp_blocking_send_and_update_ledger (ledger : Simple_ledger.t) =
        let open Quickcheck.Generator.Let_syntax in
        let%bind random_idx, account =
          Simple_ledger.get_random_unsealed ledger
        in
        let new_account_spec, _ =
          Simple_account.apply_cmd_or_fail ~amount:0 ~fee:minimum_fee account
        in
        Simple_ledger.set ledger random_idx new_account_spec ;
        return
          (Zkapp_blocking_send
             { sender = Simple_account.to_sender_info account
             ; fee = minimum_fee
             } )

      let gen_single_and_update_ledger ?(lower = 5_000_000_000_000)
          ?(higher = 10_000_000_000_000) (ledger : Simple_ledger.t)
          (idx, account) =
        let open Quickcheck.Generator.Let_syntax in
        let%bind receiver_idx =
          test_keys |> Array.mapi ~f:(fun i _ -> i) |> Quickcheck_lib.of_array
        in
        let%bind amount = Int.gen_incl lower higher in
        let new_account_spec, amount =
          Simple_account.apply_cmd_or_fail ~amount ~fee:minimum_fee account
        in
        Simple_ledger.set ledger idx new_account_spec ;
        return
          (Payment
             { sender = Simple_account.to_sender_info account
             ; fee = minimum_fee
             ; receiver_idx
             ; amount
             } )

      let gen_sequence_and_update_ledger ?(lower = 5_000_000_000_000)
          ?(higher = 10_000_000_000_000) (ledger : Simple_ledger.t) ~length =
        let open Quickcheck.Generator.Let_syntax in
        Quickcheck_lib.init_gen_array length ~f:(fun _ ->
            let%bind random_idx, account =
              Simple_ledger.get_random_unsealed ledger
            in
            gen_single_and_update_ledger ~lower ~higher ledger
              (random_idx, account) )

      let sender t =
        match t with
        | Payment { sender; _ } ->
            sender
        | Zkapp_blocking_send { sender; _ } ->
            sender

      let total_cost t =
        match t with
        | Payment { amount; fee; _ } ->
            amount + fee
        | Zkapp_blocking_send { fee; _ } ->
            fee

      let to_full_command ~ledger spec =
        match spec with
        | Zkapp_blocking_send { sender; _ } ->
            let zkapp =
              mk_basic_zkapp sender.nonce test_keys.(sender.key_idx)
                ~permissions:
                  { Permissions.user_default with
                    send = Permissions.Auth_required.Impossible
                  ; increment_nonce = Permissions.Auth_required.Impossible
                  }
            in
            Or_error.ok_exn
              (Zkapp_command.Valid.For_tests.to_valid ~failed:false
                 ~find_vk:
                   (Zkapp_command.Verifiable.load_vk_from_ledger
                      ~get:(Mina_ledger.Ledger.get ledger)
                      ~location_of_account:
                        (Mina_ledger.Ledger.location_of_account ledger) )
                 zkapp )
            |> User_command.Zkapp_command
        | Payment { sender; fee; amount; receiver_idx } ->
            mk_payment ~sender_idx:sender.key_idx ~fee ~nonce:sender.nonce
              ~receiver_idx ~amount ()
    end

    (** appends a and b to the end of c, taking an element of a or b at random, 
       continuing until both a and b run out of elements
    *)
    let rec gen_merge (a : 'a list) (b : 'a list) (c : 'a list) =
      let open Quickcheck.Generator.Let_syntax in
      match (a, b) with
      | [], [] ->
          return c
      | [ left ], [] ->
          return (c @ [ left ])
      | [], [ right ] ->
          return (c @ [ right ])
      | [ left ], [ right ] -> (
          match%bind Bool.quickcheck_generator with
          | true ->
              return (c @ [ left; right ])
          | false ->
              return (c @ [ right; left ]) )
      | [], right :: tail ->
          return (c @ [ right ] @ tail)
      | left :: tail, [] ->
          gen_merge tail [] (c @ [ left ])
      | left :: left_tail, right :: right_tail -> (
          match%bind Bool.quickcheck_generator with
          | true ->
              gen_merge left_tail (right :: right_tail) (c @ [ left ])
          | false ->
              gen_merge (left :: left_tail) right_tail (c @ [ right ]) )

    type branches =
      { prefix_commands : Simple_command.t array
      ; major_commands : Simple_command.t array
      ; minor_commands : Simple_command.t array
      ; minor : Simple_ledger.t
      ; major : Simple_ledger.t
      }
    [@@deriving to_yojson]

    let gen_branches_basic ledger ?(sequence_max_length = 3) () =
      let open Quickcheck.Generator.Let_syntax in
      let%bind prefix_length = Int.gen_incl 0 sequence_max_length in
      let%bind major_length = Int.gen_incl 0 sequence_max_length in
      let%bind minor_length = Int.gen_incl 0 sequence_max_length in
      let%bind prefix_commands =
        Simple_command.gen_sequence_and_update_ledger ledger
          ~length:prefix_length
      in
      let minor = Simple_ledger.copy ledger in
      let%bind minor_commands =
        Simple_command.gen_sequence_and_update_ledger minor ~length:minor_length
      in
      let major = Simple_ledger.copy ledger in
      let%bind major_commands =
        Simple_command.gen_sequence_and_update_ledger major ~length:major_length
      in
      return { prefix_commands; major_commands; minor_commands; minor; major }

    let split_by_account (account : Simple_account.t) commands =
      Array.partition_tf commands ~f:(fun cmd ->
          let sender = Simple_command.sender cmd in
          sender.key_idx = Simple_account.key_idx account )

    (** Optional Edge Case 1: Limited Account Capacity

        - In major sequence*, a transaction `T` from a specific account
          decreases its balance by amount `X`.
        - In minor sequence*, the same account decreases its balance in a
          similar transaction `T'`, but by an amount much smaller than `X`,
          followed by several other transactions using the same account.
        - The prefix ledger* contains just enough funds to process major
          sequence, with a small surplus.
        - When applying *minor sequence* without the transaction `T'` (of the
          same nonce as the large-amount transaction `T` in major sequence), the
          sequence becomes partially applicable, forcing the mempool logic to
          drop some transactions at the end of *minor sequence*.
    *)
    let gen_updated_branches_for_limited_capacity
        { prefix_commands; major_commands; minor_commands; minor; major } =
      let open Quickcheck.Generator.Let_syntax in
      let%bind target_account_idx, target_account =
        Simple_ledger.get_random_unsealed major
      in
      let initial_nonce = Simple_account.nonce target_account in
      (* find receiver which is not our selected account*)
      let%bind receiver_idx =
        test_keys
        |> Array.filter_mapi ~f:(fun i _ ->
               if Int.equal i (Simple_account.key_idx target_account) then None
               else Some i )
        |> Quickcheck_lib.of_array
      in
      let%bind major_sequence_length = Int.gen_incl 2 10 in
      let%bind minor_sequence_length =
        let%map minor_sequence_length = Int.gen_incl 2 4 in
        minor_sequence_length + major_sequence_length + initial_nonce
      in
      let initial_balance = Simple_account.balance target_account in
      let half_initial_balance = Simple_account.balance target_account / 2 in
      let recieved_amount =
        Array.filter_map (Array.append prefix_commands major_commands)
          ~f:(fun cmd ->
            match cmd with
            | Payment cmd ->
                Option.some_if
                  ( cmd.receiver_idx
                  = Simple_ledger.index_to_int target_account_idx )
                  cmd.amount
            | Zkapp_blocking_send _cmd ->
                None )
        |> Array.fold ~init:0 ~f:(fun acc el -> acc + el)
      in

      let gen_sequence_and_update_account ledger len =
        let account = ref (Simple_ledger.get ledger target_account_idx) in
        let amount_max = half_initial_balance / len in
        let amount_min = amount_max / 100 in
        let%map sequence =
          Quickcheck_lib.init_gen_array len ~f:(fun _ ->
              let%bind amount = Int.gen_incl amount_min amount_max in
              let tx =
                Simple_command.Payment
                  { sender = Simple_account.to_sender_info !account
                  ; receiver_idx
                  ; fee = minimum_fee
                  ; amount
                  }
              in
              account :=
                Simple_account.apply_cmd (amount + minimum_fee) !account ;
              return tx )
        in
        Simple_ledger.set ledger target_account_idx
          (Simple_account.seal !account) ;
        sequence
      in
      let%bind major_sequence =
        gen_sequence_and_update_account major major_sequence_length
      in
      let%bind minor_sequence =
        gen_sequence_and_update_account minor minor_sequence_length
      in
      let major_sequence_total_cost =
        Array.fold ~init:0 major_sequence ~f:(fun acc item ->
            acc + Simple_command.total_cost item )
      in
      let%bind num_suffix_commands =
        Int.gen_incl 1 (minor_sequence_length - major_sequence_length)
      in
      let suffix_commands_total_cost =
        Array.sub minor_sequence
          ~pos:(major_sequence_length - 1)
          ~len:num_suffix_commands
        |> Array.fold ~init:0 ~f:(fun acc item ->
               acc + Simple_command.total_cost item )
      in
      let%bind random_idx, tx_to_increase =
        get_random_from_array major_sequence
      in
      let increased_tx =
        match tx_to_increase with
        | Payment { sender; receiver_idx; fee; amount } ->
            let addition =
              initial_balance + recieved_amount - major_sequence_total_cost
              - suffix_commands_total_cost
            in
            let () =
              (* Update account in ledger *)
              Simple_ledger.get major target_account_idx
              |> (fun acct -> Simple_account.subtract_balance acct addition)
              |> Simple_ledger.set major target_account_idx
            in
            Simple_command.Payment
              { sender; receiver_idx; fee; amount = amount + addition }
        | _ ->
            failwith
              "Only payments are supported in limited account capacity corner \
               case"
      in
      Array.set major_sequence random_idx increased_tx ;
      let unchanged_major_commands, major_commands_to_merge =
        split_by_account target_account major_commands
      in
      let unchanged_minor_commands, minor_commands_to_merge =
        split_by_account target_account minor_commands
      in
      let%bind major_commands =
        gen_merge
          (Array.to_list major_commands_to_merge)
          (Array.to_list major_sequence)
          []
      in
      let%bind minor_commands =
        gen_merge
          (Array.to_list minor_commands_to_merge)
          (Array.to_list minor_sequence)
          []
      in
      return
        { prefix_commands
        ; major_commands =
            List.append (Array.to_list unchanged_major_commands) major_commands
            |> List.to_array
        ; minor_commands =
            List.append (Array.to_list unchanged_minor_commands) minor_commands
            |> List.to_array
        ; minor
        ; major
        }

    (** Optional Edge Case : Permission Changes:

        - In major sequence, a transaction modifies an account's permissions:
            1. It removes the permission to maintain the nonce.
            2. It removes the permission to send transactions.
        - In minor sequence, there is a regular transaction involving the same account,
          but after the permission-modifying transaction in major sequence,
          the new transaction becomes invalid and must be dropped.
    *)
    let gen_updated_branches_for_permission_change
        { prefix_commands; major_commands; minor_commands; minor; major } =
      let open Quickcheck.Generator.Let_syntax in
      let%bind permission_change_cmd =
        Simple_command.gen_zkapp_blocking_send_and_update_ledger major
      in
      let sender_on_major = Simple_command.sender permission_change_cmd in
      (* We need to increase nonce so transaction has a chance to be placed in the pool.
         Otherwise it will be dropped as we already have transaction with the same nonce from major sequence
      *)
      let sender_index = Simple_ledger.index_of_int sender_on_major.key_idx in
      let sender_on_minor = Simple_ledger.get minor sender_index in
      let%bind aux_minor_cmd =
        Quickcheck_lib.init_gen_array
          (sender_on_major.nonce - Simple_account.nonce sender_on_minor + 1)
          ~f:(fun _ ->
            let sender_on_minor = Simple_ledger.get minor sender_index in
            let sender_on_minor_idx =
              Simple_ledger.index_of_int
                (Simple_account.key_idx sender_on_minor)
            in
            Simple_command.gen_single_and_update_ledger minor
              (sender_on_minor_idx, sender_on_minor) )
      in

      let unchanged_minor_commands, minor_commands_to_merge =
        split_by_account sender_on_minor minor_commands
      in

      let%bind minor_commands =
        gen_merge
          (Array.to_list minor_commands_to_merge)
          (Array.to_list aux_minor_cmd)
          []
      in

      return
        { prefix_commands
        ; major_commands =
            Array.append major_commands [| permission_change_cmd |]
        ; minor_commands =
            List.append (Array.to_list unchanged_minor_commands) minor_commands
            |> List.to_array
        ; minor
        ; major
        }

    (** Main generator for prefix, minor and major sequences. This generator
        has a more firm grip on how data is generated than usual. It uses
        Simple_command and Simple_account modules for user command definitions
        which then are carved into Signed_command list. By default generator
        fulfill standard use cases for ledger reorg, like merging transactions
        from minor and major sequences with preference for major sequence as
        well as 2 additional corner cases:

        ### Edge Case : Nonce Precedence

        - In major sequence, transactions update the account state to a point
          where the nonce of the account is smaller than the first nonce in the
          sequence of removed transactions.
        - The mempool logic determines that if this condition is true, the
           entire minor sequence should be dropped.

        ### Edge Case : Nonce Intersection

        - Transactions using the same account appear in all three sequences (prefix, minor, major)

        On top of that one can enable/disable two special corner cases
        (permission change and limited capacity).
    *)
    let gen_branches ledger ~permission_change ~limited_capacity
        ?sequence_max_length () =
      let open Quickcheck.Generator.Let_syntax in
      let%bind branches = gen_branches_basic ledger ?sequence_max_length () in
      let%bind branches =
        if limited_capacity then
          gen_updated_branches_for_limited_capacity branches
        else return branches
      in
      let%bind branches =
        if permission_change then
          gen_updated_branches_for_permission_change branches
        else return branches
      in
      return branches

    let commands_from_specs (sequence : Simple_command.t array) test :
        User_command.Valid.t list =
      let best_tip_ledger = Option.value_exn test.txn_pool.best_tip_ledger in
      sequence
      |> Array.map ~f:(Simple_command.to_full_command ~ledger:best_tip_ledger)
      |> Array.to_list

    let%test_unit "Handle transition frontier diff (permission send tx updated)"
        =
      (* Testing strategy focuses specifically on the mempool layer, where we
         are given the following inputs:

         - A list of transactions that were **removed** due to the blockchain
           reorganization.
         - A list of transactions that were **added** in the new blocks.
         - The new **ledger** after the reorganization.

         This property-based test that generates three transaction sequences,
         computes intermediate ledgers and verifies certain invariants after
         the call to `handle_transition_frontier_diff`.

         - Prefix sequence: a sequence of transactions originating from initial
           ledger
         - Major sequence: a sequence of transactions originating from prefix
           ledger
         - Major ledger: result of application of joint prefix and major
           sequences to prefix ledger
         - Minor sequence: a sequence of transactions originating from *prefix
           ledger
         - It’s role in testing is that of a transaction sequence extracted
           from an “rolled back” chain
      *)
      Quickcheck.test ~trials:1 ~seed:(`Deterministic "")
        (let open Quickcheck.Generator.Let_syntax in
        let test = Thread_safe.block_on_async_exn (fun () -> setup_test ()) in
        let init_ledger_state = Simple_ledger.ledger_snapshot test in
        let%bind branches =
          gen_branches init_ledger_state ~permission_change:true
            ~limited_capacity:true ~sequence_max_length:10 ()
        in
        return (test, branches))
        ~f:(fun ( test
                , ( { prefix_commands
                    ; major_commands
                    ; minor_commands
                    ; minor = _
                    ; major
                    } as input_data ) ) ->
          Thread_safe.block_on_async_exn (fun () ->
              [%log info] "Input Data $data"
                ~metadata:[ ("data", [%to_yojson: branches] input_data) ] ;
              let prefix_cmds = commands_from_specs prefix_commands test in
              let minor_cmds = commands_from_specs minor_commands test in
              let major_cmds = commands_from_specs major_commands test in
              commit_commands test (prefix_cmds @ major_cmds) ;
              Test.Resource_pool.handle_transition_frontier_diff_inner
                ~new_commands:
                  (List.map ~f:mk_with_status (prefix_cmds @ major_cmds))
                ~removed_commands:
                  (List.map ~f:mk_with_status (prefix_cmds @ minor_cmds))
                ~best_tip_ledger:
                  (Option.value_exn test.txn_pool.best_tip_ledger)
                test.txn_pool ;
              let pool_state =
                Test.Resource_pool.get_all test.txn_pool
                |> List.map ~f:(fun tx ->
                       let data =
                         Transaction_hash.User_command_with_valid_signature.data
                           tx
                         |> User_command.forget_check
                       in
                       let nonce =
                         data |> User_command.applicable_at_nonce
                         |> Unsigned.UInt32.to_int
                       in
                       let fee_payer_pk =
                         data |> User_command.fee_payer |> Account_id.public_key
                       in
                       (fee_payer_pk, nonce) )
              in
              [%log info] "Pool state"
                ~metadata:
                  [ ( "pool state"
                    , [%to_yojson: (Public_key.Compressed.t * int) list]
                        pool_state )
                  ] ;

              let actual_nonce_opt pk nonce =
                List.find ~f:(fun (fee_payer_pk, actual_nonce) ->
                    Public_key.Compressed.equal pk fee_payer_pk
                    && Int.equal actual_nonce nonce )
              in

              let assert_pool_contains pool_state (pk, nonce) =
                match actual_nonce_opt pk nonce pool_state with
                | Some actual ->
                    [%test_eq: Public_key.Compressed.t * int] (pk, nonce) actual
                | None ->
                    failwithf
                      !"Expected transaction from %{sexp: \
                        Public_key.Compressed.t} with nonce %d not found \n"
                      pk nonce ()
              in

              let assert_pool_doesn't_contain pool_state (pk, nonce) =
                match actual_nonce_opt pk nonce pool_state with
                | Some _ ->
                    failwithf
                      !"Unexpected transaction from %{sexp: \
                        Public_key.Compressed.t} with nonce %d found \n"
                      pk nonce ()
                | None ->
                    ()
              in

              let sent_blocking_zkapp (specs : Simple_command.t array) pk =
                Array.find specs ~f:(fun s ->
                    match s with
                    | Payment _ ->
                        false
                    | Zkapp_blocking_send { sender; _ } ->
                        let cur_pk, _ = Sender_info.to_key_and_nonce sender in
                        Public_key.Compressed.equal pk cur_pk )
                |> Option.is_some
              in

              let find_owned (target_sender : Sender_info.t)
                  (txs : Simple_command.t array) =
                Array.filter txs ~f:(fun x ->
                    let sender = Simple_command.sender x in
                    Int.equal target_sender.key_idx sender.key_idx
                    && Int.( > ) target_sender.nonce sender.nonce )
              in

              let total_cost sender =
                find_owned sender minor_commands
                |> Array.map ~f:Simple_command.total_cost
                |> Array.sum ~f:Fn.id (module Int)
              in

              Array.iter minor_commands ~f:(fun (spec : Simple_command.t) ->
                  let sender = Simple_command.sender spec in
                  let pk, nonce = Sender_info.to_key_and_nonce sender in
                  let account_spec =
                    Simple_ledger.find_by_key_idx major sender.key_idx
                  in
                  if sender.nonce < Simple_account.nonce account_spec then (
                    [%log info]
                      "sender nonce is smaller or equal than last major nonce. \
                       command should be dropped"
                      ~metadata:
                        [ ( "sent from"
                          , `String
                              (Printf.sprintf
                                 !"%{sexp: Public_key.Compressed.t} -> %d"
                                 pk nonce ) )
                        ] ;
                    assert_pool_doesn't_contain pool_state (pk, nonce) )
                  else if sent_blocking_zkapp major_commands pk then (
                    [%log info]
                      "major chain contains blocking zkapp. command should be \
                       dropped"
                      ~metadata:
                        [ ( "sent from"
                          , `String
                              (Printf.sprintf
                                 !"%{sexp: Public_key.Compressed.t}"
                                 pk ) )
                        ] ;
                    assert_pool_doesn't_contain pool_state (pk, nonce) )
                  else if
                    Simple_account.balance account_spec > total_cost sender
                  then (
                    [%log info]
                      "sender nonce is greater than last major nonce. should \
                       be in the pool"
                      ~metadata:
                        [ ( "sent from"
                          , `String
                              (Printf.sprintf
                                 !"%{sexp: Public_key.Compressed.t} -> %d}"
                                 pk nonce ) )
                        ; ("balance", `Int (Simple_account.balance account_spec))
                        ; ("cost", `Int (total_cost sender))
                        ] ;
                    assert_pool_contains pool_state (pk, nonce) ;
                    Simple_ledger.set major
                      ( Simple_account.key_idx account_spec
                      |> Simple_ledger.index_of_int )
                      (Simple_account.subtract_balance account_spec
                         (total_cost sender) ) )
                  else (
                    [%log info]
                      "balance is negative. should be dropped from pool"
                      ~metadata:
                        [ ( "sent from"
                          , `String
                              (Printf.sprintf
                                 !"%{sexp: Public_key.Compressed.t} -> %d"
                                 pk nonce ) )
                        ] ;
                    assert_pool_doesn't_contain pool_state (pk, nonce) ) ) ;
              Deferred.unit ) )
  end )
