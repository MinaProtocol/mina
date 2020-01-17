(** A pool of transactions that can be included in future blocks. Combined with
    the Network_pool module, this handles storing and gossiping the correct
    transactions (user commands) and providing them to the block producer code.
*)

open Core
open Async
open Coda_base
open Module_version
open Pipe_lib
open Signature_lib

(* TEMP HACK UNTIL DEFUNCTORING: transition frontier interface is simplified *)
module type Transition_frontier_intf = sig
  type t

  type staged_ledger

  module Breadcrumb : sig
    type t

    val staged_ledger : t -> staged_ledger
  end

  type best_tip_diff =
    { new_user_commands: User_command.t list
    ; removed_user_commands: User_command.t list
    ; reorg_best_tip: bool }

  val best_tip : t -> Breadcrumb.t

  val best_tip_diff_pipe : t -> best_tip_diff Broadcast_pipe.Reader.t
end

module type S = sig
  open Intf

  type transition_frontier

  type best_tip_diff

  module Resource_pool : sig
    include
      Transaction_resource_pool_intf
      with type best_tip_diff := best_tip_diff
       and type transition_frontier := transition_frontier

    module Diff : Transaction_pool_diff_intf
  end

  include
    Network_pool_base_intf
    with type resource_pool := Resource_pool.t
     and type transition_frontier := transition_frontier
     and type resource_pool_diff := Resource_pool.Diff.t
     and type config := Resource_pool.Config.t

  val add : t -> User_command.t list -> unit Deferred.t
end

(* Functor over user command, base ledger and transaction validator for
   mocking. *)
module Make0 (Base_ledger : sig
  type t

  module Location : sig
    type t
  end

  val location_of_key : t -> Public_key.Compressed.t -> Location.t option

  val get : t -> Location.t -> Account.t option
end) (Max_size : sig
  val pool_max_size : int
end) (Staged_ledger : sig
  type t

  val ledger : t -> Base_ledger.t
end)
(Transition_frontier : Transition_frontier_intf
                       with type staged_ledger := Staged_ledger.t) =
struct
  module Breadcrumb = Transition_frontier.Breadcrumb

  module Resource_pool = struct
    include Max_size

    module Config = struct
      type t = {trust_system: Trust_system.t sexp_opaque}
      [@@deriving sexp_of, make]
    end

    let make_config = Config.make

    type t =
      { mutable pool: Indexed_pool.t
      ; locally_generated_uncommitted:
          (User_command.With_valid_signature.t, Time.t) Hashtbl.t
            (** Commands generated on this machine, that are not included in the
                current best tip, along with the time they were added. *)
      ; locally_generated_committed:
          (User_command.With_valid_signature.t, Time.t) Hashtbl.t
            (** Ones that are included in the current best tip. *)
      ; config: Config.t
      ; logger: Logger.t sexp_opaque
      ; mutable diff_reader: unit Deferred.t sexp_opaque Option.t
      ; mutable best_tip_ledger: Base_ledger.t sexp_opaque option }
    [@@deriving sexp_of]

    let member t = Indexed_pool.member t.pool

    let transactions' p =
      Sequence.unfold ~init:p ~f:(fun pool ->
          match Indexed_pool.get_highest_fee pool with
          | Some cmd ->
              Some
                ( cmd
                , fst
                  @@ Indexed_pool.handle_committed_txn pool cmd
                       (* we have the invariant that the transactions currently
                          in the pool are always valid against the best tip, so
                          no need to check balances here *)
                       Currency.Amount.max_int )
          | None ->
              None )

    let transactions t = transactions' t.pool

    let all_from_user {pool; _} = Indexed_pool.all_from_user pool

    (** Get the best tip ledger and update our cache. *)
    let get_best_tip_ledger_and_update t frontier =
      let best_tip_ledger =
        Transition_frontier.best_tip frontier
        |> Breadcrumb.staged_ledger |> Staged_ledger.ledger
      in
      t.best_tip_ledger <- Some best_tip_ledger ;
      best_tip_ledger

    let drop_until_below_max_size :
           Indexed_pool.t
        -> Indexed_pool.t * User_command.With_valid_signature.t Sequence.t =
     fun pool ->
      let rec go pool' dropped =
        if Indexed_pool.size pool' > pool_max_size then (
          let dropped', pool'' = Indexed_pool.remove_lowest_fee pool' in
          assert (not (Sequence.is_empty dropped')) ;
          go pool'' @@ Sequence.append dropped dropped' )
        else (pool', dropped)
      in
      go pool @@ Sequence.empty

    let has_sufficient_fee pool cmd : bool =
      match Indexed_pool.min_fee pool with
      | None ->
          true
      | Some min_fee ->
          if Indexed_pool.size pool >= pool_max_size then
            Currency.Fee.(User_command.fee cmd > min_fee)
          else true

    let handle_diff t frontier
        ({new_user_commands; removed_user_commands; reorg_best_tip= _} :
          Transition_frontier.best_tip_diff) =
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
      let validation_ledger = get_best_tip_ledger_and_update t frontier in
      Logger.trace t.logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          [ ( "removed"
            , `List (List.map removed_user_commands ~f:User_command.to_yojson)
            )
          ; ( "added"
            , `List (List.map new_user_commands ~f:User_command.to_yojson) ) ]
        "Diff: removed: $removed added: $added from best tip" ;
      let pool', dropped_backtrack =
        Sequence.fold
          ( removed_user_commands |> List.rev |> Sequence.of_list
          |> Sequence.map ~f:(fun unchecked ->
                 Option.value_exn
                   ~message:
                     "somehow user command from the frontier has an invalid \
                      signature!"
                   (User_command.check unchecked) ) )
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
              drop_until_below_max_size
              @@ Indexed_pool.add_from_backtrack pool cmd
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
        Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
          "Dropped locally generated commands $cmds during backtracking to \
           maintain max size. Will attempt to re-add after forwardtracking."
          ~metadata:
            [ ( "cmds"
              , `List
                  (List.map ~f:User_command.With_valid_signature.to_yojson
                     locally_generated_dropped) ) ] ;
      let pool'', dropped_commit_conflicts =
        List.fold new_user_commands ~init:(pool', Sequence.empty)
          ~f:(fun (p, dropped_so_far) cmd ->
            let sender = User_command.sender cmd in
            let balance =
              match Base_ledger.location_of_key validation_ledger sender with
              | None ->
                  Currency.Balance.zero
              | Some loc ->
                  let acc =
                    Option.value_exn
                      ~message:"public key has location but no account"
                      (Base_ledger.get validation_ledger loc)
                  in
                  acc.balance
            in
            let cmd' = User_command.check cmd |> Option.value_exn in
            ( match
                Hashtbl.find_and_remove t.locally_generated_uncommitted cmd'
              with
            | None ->
                ()
            | Some time_added ->
                Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                  "Locally generated command $cmd committed in a block!"
                  ~metadata:[("cmd", User_command.to_yojson cmd)] ;
                Hashtbl.add_exn t.locally_generated_committed ~key:cmd'
                  ~data:time_added ) ;
            let p', dropped =
              Indexed_pool.handle_committed_txn p cmd'
                (Currency.Balance.to_amount balance)
            in
            (p', Sequence.append dropped_so_far dropped) )
      in
      let commit_conflicts_locally_generated =
        Sequence.filter dropped_commit_conflicts ~f:(fun cmd ->
            Hashtbl.find_and_remove t.locally_generated_uncommitted cmd
            |> Option.is_some )
      in
      if not @@ Sequence.is_empty commit_conflicts_locally_generated then
        Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
          "Locally generated commands $cmds dropped because they conflicted \
           with a committed command."
          ~metadata:
            [ ( "cmds"
              , `List
                  (Sequence.to_list
                     (Sequence.map commit_conflicts_locally_generated
                        ~f:User_command.With_valid_signature.to_yojson)) ) ] ;
      Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
        !"Finished handling diff. Old pool size %i, new pool size %i. Dropped \
          %i commands during backtracking to maintain max size."
        (Indexed_pool.size t.pool) (Indexed_pool.size pool'')
        (Sequence.length dropped_backtrack) ;
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
          let log_invalid () =
            Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
              "Couldn't re-add locally generated command $cmd, not valid \
               against new ledger."
              ~metadata:
                [("cmd", User_command.to_yojson (cmd :> User_command.t))] ;
            remove_cmd ()
          in
          if not (Hashtbl.mem t.locally_generated_committed cmd) then
            if not (has_sufficient_fee t.pool (cmd :> User_command.t)) then (
              Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                "Not re-adding locally generated command $cmd to pool, \
                 insufficient fee"
                ~metadata:
                  [("cmd", User_command.to_yojson (cmd :> User_command.t))] ;
              remove_cmd () )
            else
              match
                Option.bind
                  (Base_ledger.location_of_key validation_ledger
                     (User_command.sender (cmd :> User_command.t)))
                  ~f:(Base_ledger.get validation_ledger)
              with
              | Some acct -> (
                match
                  Indexed_pool.add_from_gossip_exn t.pool cmd acct.nonce
                    (Currency.Balance.to_amount acct.balance)
                with
                | Error _ ->
                    log_invalid ()
                | Ok (pool''', _) ->
                    Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
                      "re-added locally generated command $cmd to transaction \
                       pool after reorg"
                      ~metadata:
                        [ ( "cmd"
                          , User_command.to_yojson (cmd :> User_command.t) ) ] ;
                    t.pool <- pool''' )
              | None ->
                  log_invalid () ) ;
      Deferred.unit

    let create ~frontier_broadcast_pipe ~config ~logger =
      let t =
        { pool= Indexed_pool.empty
        ; locally_generated_uncommitted=
            Hashtbl.create (module User_command.With_valid_signature)
        ; locally_generated_committed=
            Hashtbl.create (module User_command.With_valid_signature)
        ; config
        ; logger
        ; diff_reader= None
        ; best_tip_ledger= None }
      in
      don't_wait_for
        (Broadcast_pipe.Reader.iter frontier_broadcast_pipe
           ~f:(fun frontier_opt ->
             match frontier_opt with
             | None -> (
                 Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
                   "no frontier" ;
                 (* Sanity check: the view pipe should have been closed before
                    the frontier was destroyed. *)
                 match t.diff_reader with
                 | None ->
                     Deferred.unit
                 | Some hdl ->
                     let is_finished = ref false in
                     t.best_tip_ledger <- None ;
                     Deferred.any_unit
                       [ (let%map () = hdl in
                          t.diff_reader <- None ;
                          is_finished := true)
                       ; (let%map () = Async.after (Time.Span.of_sec 5.) in
                          if not !is_finished then (
                            Logger.fatal t.logger ~module_:__MODULE__
                              ~location:__LOC__
                              "Transition frontier closed without first \
                               closing best tip view pipe" ;
                            assert false )
                          else ()) ] )
             | Some frontier ->
                 Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
                   "Got frontier!" ;
                 let validation_ledger =
                   get_best_tip_ledger_and_update t frontier
                 in
                 (* The frontier has changed, so transactions in the pool may
                    not be valid against the current best tip. *)
                 let new_pool, dropped =
                   Indexed_pool.revalidate t.pool (fun sender ->
                       match
                         Base_ledger.location_of_key validation_ledger sender
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
                           (acc.nonce, Currency.Balance.to_amount acc.balance)
                   )
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
                   Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                     "Dropped locally generated commands $cmds from pool when \
                      transition frontier was recreated."
                     ~metadata:
                       [ ( "cmds"
                         , `List
                             (List.map
                                (Sequence.to_list dropped_locally_generated)
                                ~f:User_command.With_valid_signature.to_yojson)
                         ) ] ;
                 Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
                   !"Re-validated transaction pool after restart: dropped %i \
                     of %i previously in pool"
                   (Sequence.length dropped) (Indexed_pool.size t.pool) ;
                 t.pool <- new_pool ;
                 t.diff_reader
                 <- Some
                      (Broadcast_pipe.Reader.iter
                         (Transition_frontier.best_tip_diff_pipe frontier)
                         ~f:(handle_diff t frontier)) ;
                 Deferred.unit )) ;
      t

    module Diff = struct
      module Stable = struct
        module V1 = struct
          module T = struct
            type t = User_command.Stable.V1.t list
            [@@deriving bin_io, sexp, yojson, version]
          end

          include T
          include Registration.Make_latest_version (T)
        end

        module Latest = V1

        module Module_decl = struct
          let name = "transaction_pool_diff"

          type latest = Latest.t
        end

        module Registrar = Registration.Make (Module_decl)
        module Registered_V1 = Registrar.Register (V1)
      end

      (* bin_io omitted *)
      type t = Stable.Latest.t [@@deriving sexp, yojson]

      let summary t =
        Printf.sprintf "Transaction diff of length %d" (List.length t)

      let apply t env =
        let txs = Envelope.Incoming.data env in
        let sender = Envelope.Incoming.sender env in
        match t.best_tip_ledger with
        | None ->
            Deferred.Or_error.error_string
              "Got transaction pool diff when transition frontier is \
               unavailable, ignoring."
        | Some ledger ->
            let trust_record =
              Trust_system.record_envelope_sender t.config.trust_system
                t.logger sender
            in
            let rec go txs' pool accepted =
              match txs' with
              | [] ->
                  t.pool <- pool ;
                  if not (List.is_empty accepted) then
                    Deferred.Or_error.return @@ List.rev accepted
                  else Deferred.Or_error.error_string "no useful transactions"
              | tx :: txs'' -> (
                match User_command.check tx with
                | None ->
                    let%bind _ =
                      trust_record
                        ( Trust_system.Actions.Sent_invalid_signature
                        , Some
                            ( "command was: $cmd"
                            , [("cmd", User_command.to_yojson tx)] ) )
                    in
                    (* that's an insta-ban, so ignore the rest of the diff. *)
                    t.pool <- pool ;
                    Deferred.Or_error.error_string "invalid signature"
                | Some tx' -> (
                    if Indexed_pool.member pool tx' then
                      let%bind _ =
                        trust_record
                          (Trust_system.Actions.Sent_old_gossip, None)
                      in
                      go txs'' pool accepted
                    else
                      match
                        Option.bind
                          (Base_ledger.location_of_key ledger
                             (User_command.sender tx))
                          ~f:(Base_ledger.get ledger)
                      with
                      | None ->
                          let%bind _ =
                            trust_record
                              ( Trust_system.Actions.Sent_useless_gossip
                              , Some
                                  ( "account does not exist for command: $cmd"
                                  , [("cmd", User_command.to_yojson tx)] ) )
                          in
                          go txs'' pool accepted
                      | Some account ->
                          if has_sufficient_fee pool tx then
                            let add_res =
                              Indexed_pool.add_from_gossip_exn pool tx'
                                account.nonce
                              @@ Currency.Balance.to_amount account.balance
                            in
                            let yojson_fail_reason =
                              Fn.compose
                                (fun s -> `String s)
                                (function
                                  | `Invalid_nonce ->
                                      "invalid nonce"
                                  | `Insufficient_funds ->
                                      "insufficient funds"
                                  | `Insufficient_replace_fee ->
                                      "insufficient replace fee"
                                  | `Overflow ->
                                      "overflow" )
                            in
                            match add_res with
                            | Ok (pool', dropped) ->
                                let%bind _ =
                                  trust_record
                                    ( Trust_system.Actions.Sent_useful_gossip
                                    , Some
                                        ( "$cmd"
                                        , [("cmd", User_command.to_yojson tx)]
                                        ) )
                                in
                                if
                                  Envelope.Sender.equal sender
                                    Envelope.Sender.Local
                                then
                                  Hashtbl.add_exn
                                    t.locally_generated_uncommitted ~key:tx'
                                    ~data:(Time.now ()) ;
                                let pool'', dropped_for_size =
                                  drop_until_below_max_size pool'
                                in
                                let seq_cmd_to_yojson seq =
                                  `List
                                    Sequence.(
                                      to_list
                                      @@ map
                                           ~f:
                                             User_command.With_valid_signature
                                             .to_yojson seq)
                                in
                                if not (Sequence.is_empty dropped) then
                                  Logger.debug t.logger ~module_:__MODULE__
                                    ~location:__LOC__
                                    "dropped commands due to transaction \
                                     replacement: $dropped"
                                    ~metadata:
                                      [("dropped", seq_cmd_to_yojson dropped)] ;
                                if not (Sequence.is_empty dropped_for_size)
                                then
                                  Logger.debug t.logger ~module_:__MODULE__
                                    ~location:__LOC__
                                    "dropped commands to maintain max size: \
                                     $cmds"
                                    ~metadata:
                                      [ ( "cmds"
                                        , seq_cmd_to_yojson dropped_for_size )
                                      ] ;
                                let locally_generated_dropped =
                                  Sequence.filter
                                    (Sequence.append dropped dropped_for_size)
                                    ~f:(fun tx_dropped ->
                                      Hashtbl.find_and_remove
                                        t.locally_generated_uncommitted
                                        tx_dropped
                                      |> Option.is_some )
                                  |> Sequence.to_list
                                in
                                if
                                  not (List.is_empty locally_generated_dropped)
                                then
                                  Logger.info t.logger ~module_:__MODULE__
                                    ~location:__LOC__
                                    "Dropped locally generated commands $cmds \
                                     from transaction pool due to replacement \
                                     or max size"
                                    ~metadata:
                                      [ ( "cmds"
                                        , `List
                                            (List.map
                                               ~f:
                                                 User_command
                                                 .With_valid_signature
                                                 .to_yojson
                                               locally_generated_dropped) ) ] ;
                                go txs'' pool'' (tx :: accepted)
                            | Error `Insufficient_replace_fee ->
                                (* We can't punish peers for this, since an
                                   attacker can simultaneously send different
                                   transactions at the same nonce to different
                                   nodes, which will then naturally gossip them.
                                *)
                                Logger.debug t.logger ~module_:__MODULE__
                                  ~location:__LOC__
                                  "rejecting $cmd because of insufficient \
                                   replace fee"
                                  ~metadata:[("cmd", User_command.to_yojson tx)] ;
                                go txs'' pool accepted
                            | Error err ->
                                let%bind _ =
                                  trust_record
                                    ( Trust_system.Actions.Sent_useless_gossip
                                    , Some
                                        ( "rejecting $cmd because of $reason"
                                        , [ ("cmd", User_command.to_yojson tx)
                                          ; ("reason", yojson_fail_reason err)
                                          ] ) )
                                in
                                go txs'' pool accepted
                          else
                            let%bind _ =
                              trust_record
                                ( Trust_system.Actions.Sent_useless_gossip
                                , Some
                                    ( sprintf
                                        "rejecting command $cmd due to \
                                         insufficient fee."
                                    , [("cmd", User_command.to_yojson tx)] ) )
                            in
                            go txs'' pool accepted ) )
            in
            go txs t.pool []
    end

    let get_rebroadcastable (t : t) ~is_expired =
      let metadata ~(key : User_command.With_valid_signature.t) ~data =
        [ ("cmd", User_command.to_yojson (key :> User_command.t))
        ; ("time", `String (Time.to_string_abs ~zone:Time.Zone.utc data)) ]
      in
      let added_str =
        "it was added at $time and its rebroadcast period is now expired."
      in
      Hashtbl.filteri_inplace t.locally_generated_uncommitted
        ~f:(fun ~key ~data ->
          match is_expired data with
          | `Expired ->
              Logger.info t.logger ~module_:__MODULE__ ~location:__LOC__
                "No longer rebroadcasting uncommitted command $cmd, %s"
                added_str ~metadata:(metadata ~key ~data) ;
              false
          | `Ok ->
              true ) ;
      Hashtbl.filteri_inplace t.locally_generated_committed
        ~f:(fun ~key ~data ->
          match is_expired data with
          | `Expired ->
              Logger.debug t.logger ~module_:__MODULE__ ~location:__LOC__
                "Removing committed locally generated command $cmd from \
                 possible rebroadcast pool, %s"
                added_str ~metadata:(metadata ~key ~data) ;
              false
          | `Ok ->
              true ) ;
      (* Important to maintain ordering here *)
      let rebroadcastable_txs =
        (Hashtbl.keys t.locally_generated_uncommitted :> User_command.t list)
      in
      if List.is_empty rebroadcastable_txs then []
      else
        [ List.sort rebroadcastable_txs ~compare:(fun tx1 tx2 ->
              User_command.(
                Coda_numbers.Account_nonce.compare (nonce tx1) (nonce tx2)) )
        ]
  end

  include Network_pool_base.Make (Transition_frontier) (Resource_pool)

  (* TODO: This causes the signature to get checked twice as it is checked
     below before feeding it to add *)
  let add t txns = apply_and_broadcast t (Envelope.Incoming.local txns)
end

(* Use this one in downstream consumers *)
module Make (Staged_ledger : sig
  type t

  val ledger : t -> Coda_base.Ledger.t
end)
(Transition_frontier : Transition_frontier_intf
                       with type staged_ledger := Staged_ledger.t) :
  S
  with type transition_frontier := Transition_frontier.t
   and type best_tip_diff := Transition_frontier.best_tip_diff =
  Make0
    (Coda_base.Ledger)
    (struct
      (* note this value needs to be mostly the same across gossipping nodes, so
       nodes with larger pools don't send nodes with smaller pools lots of
       low fee transactions the smaller-pooled nodes consider useless and get
       themselves banned.
    *)
      [%%import
      "../../config.mlh"]

      [%%inject
      "pool_max_size", pool_max_size]
    end)
    (Staged_ledger)
    (Transition_frontier)

(* TODO: defunctor or remove monkey patching (#3731) *)
include Make
          (Staged_ledger)
          (struct
            include Transition_frontier

            type best_tip_diff = Extensions.Best_tip_diff.view =
              { new_user_commands: User_command.t list
              ; removed_user_commands: User_command.t list
              ; reorg_best_tip: bool }

            let best_tip_diff_pipe t =
              Extensions.(get_view_pipe (extensions t) Best_tip_diff)
          end)

let%test_module _ =
  ( module struct
    module Mock_base_ledger = struct
      type t = Account.t Public_key.Compressed.Map.t

      module Location = struct
        type t = Public_key.Compressed.t
      end

      let location_of_key _t k = Some k

      let get t l = Map.find t l
    end

    module Mock_staged_ledger = struct
      type t = Mock_base_ledger.t

      let ledger = Fn.id
    end

    let test_keys = Array.init 10 ~f:(fun _ -> Signature_lib.Keypair.create ())

    module Mock_transition_frontier = struct
      module Breadcrumb = struct
        type t = Mock_staged_ledger.t

        let staged_ledger = Fn.id
      end

      type best_tip_diff =
        { new_user_commands: User_command.t list
        ; removed_user_commands: User_command.t list
        ; reorg_best_tip: bool }

      type t = best_tip_diff Broadcast_pipe.Reader.t * Breadcrumb.t ref

      let create : unit -> t * best_tip_diff Broadcast_pipe.Writer.t =
       fun () ->
        let pipe_r, pipe_w =
          Broadcast_pipe.create
            { new_user_commands= []
            ; removed_user_commands= []
            ; reorg_best_tip= false }
        in
        let accounts =
          List.map (Array.to_list test_keys) ~f:(fun kp ->
              let compressed = Public_key.compress kp.public_key in
              ( compressed
              , Account.create compressed @@ Currency.Balance.of_int 1_000 ) )
        in
        let ledger = Public_key.Compressed.Map.of_alist_exn accounts in
        ((pipe_r, ref ledger), pipe_w)

      let best_tip (_, best_tip_ref) = !best_tip_ref

      let best_tip_diff_pipe (pipe, _) = pipe
    end

    module Test =
      Make0
        (Mock_base_ledger)
        (struct
          let pool_max_size = 25
        end)
        (Mock_staged_ledger)
        (Mock_transition_frontier)

    let _ =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    (** Assert the invariants of the locally generated command tracking system.
    *)
    let assert_locally_generated (pool : Test.Resource_pool.t) =
      let _ =
        Hashtbl.merge pool.locally_generated_committed
          pool.locally_generated_uncommitted ~f:(fun ~key -> function
          | `Both (committed, uncommitted) ->
              failwithf
                !"Command %{sexp:User_command.With_valid_signature.t} in both \
                  locally generated committed and uncommitted with times %s \
                  and %s"
                key (Time.to_string committed)
                (Time.to_string uncommitted)
                ()
          | `Left cmd ->
              Some cmd
          | `Right cmd ->
              (* Locally generated uncommitted transactions should be in the
                 pool, so long as we're not in the middle of updating it. *)
              assert (Indexed_pool.member pool.pool key) ;
              Some cmd )
      in
      ()

    let setup_test () =
      let tf, best_tip_diff_w = Mock_transition_frontier.create () in
      let tf_pipe_r, _tf_pipe_w = Broadcast_pipe.create @@ Some tf in
      let trust_system = Trust_system.null () in
      let logger = Logger.null () in
      let config = Test.Resource_pool.make_config ~trust_system in
      let pool =
        Test.Resource_pool.create ~config ~logger
          ~frontier_broadcast_pipe:tf_pipe_r
      in
      let%map () = Async.Scheduler.yield () in
      ( (fun txs ->
          Indexed_pool.For_tests.assert_invariants pool.pool ;
          assert_locally_generated pool ;
          [%test_eq: User_command.t List.t]
            ( Test.Resource_pool.transactions pool
            |> Sequence.map ~f:User_command.forget_check
            |> Sequence.to_list
            |> List.sort ~compare:User_command.compare )
            (List.sort ~compare:User_command.compare txs) )
      , pool
      , best_tip_diff_w
      , tf )

    let independent_cmds =
      let rec go n cmds =
        let open Quickcheck.Generator.Let_syntax in
        if n < Array.length test_keys then
          let%bind cmd =
            let sender = test_keys.(n) in
            User_command.Gen.payment ~sign_type:`Real
              ~key_gen:
                (Quickcheck.Generator.tuple2 (return sender)
                   (Quickcheck_lib.of_array test_keys))
              ~max_amount:100 ~max_fee:10 ()
          in
          go (n + 1) (cmd :: cmds)
        else Quickcheck.Generator.return @@ List.rev cmds
      in
      Quickcheck.random_value ~seed:(`Deterministic "constant") (go 0 [])

    let%test_unit "transactions are removed in linear case" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, _frontier =
            setup_test ()
          in
          assert_pool_txs [] ;
          let%bind apply_res =
            Test.Resource_pool.Diff.apply pool
              (Envelope.Incoming.local independent_cmds)
          in
          [%test_eq: User_command.t list Or_error.t] apply_res
            (Ok independent_cmds) ;
          assert_pool_txs independent_cmds ;
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= [List.hd_exn independent_cmds]
              ; removed_user_commands= []
              ; reorg_best_tip= false }
          in
          assert_pool_txs (List.tl_exn independent_cmds) ;
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= List.take (List.tl_exn independent_cmds) 2
              ; removed_user_commands= []
              ; reorg_best_tip= false }
          in
          assert_pool_txs (List.drop independent_cmds 3) ;
          Deferred.unit )

    let rec map_set_multi map pairs =
      match pairs with
      | (k, v) :: pairs' ->
          map_set_multi
            (Map.set map
               ~key:(Public_key.compress test_keys.(k).public_key)
               ~data:v)
            pairs'
      | [] ->
          map

    let mk_account i balance nonce =
      ( i
      , Account.Poly.Stable.Latest.
          { public_key= Public_key.compress @@ test_keys.(i).public_key
          ; balance= Currency.Balance.of_int balance
          ; nonce= Account.Nonce.of_int nonce
          ; receipt_chain_hash= Receipt.Chain_hash.empty
          ; delegate= Public_key.Compressed.empty
          ; voting_for=
              Quickcheck.random_value ~seed:(`Deterministic "constant")
                State_hash.gen
          ; timing= Account.Timing.Untimed } )

    let%test_unit "Transactions are removed and added back in fork changes" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          assert_pool_txs [] ;
          let%bind apply_res =
            Test.Resource_pool.Diff.apply pool
              ( Envelope.Incoming.local
              @@ (List.hd_exn independent_cmds :: List.drop independent_cmds 2)
              )
          in
          [%test_eq: User_command.t list Or_error.t] apply_res
            (Ok (List.hd_exn independent_cmds :: List.drop independent_cmds 2)) ;
          best_tip_ref := map_set_multi !best_tip_ref [mk_account 1 1_000 1] ;
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= List.take independent_cmds 1
              ; removed_user_commands= [List.nth_exn independent_cmds 1]
              ; reorg_best_tip= true }
          in
          assert_pool_txs (List.tl_exn independent_cmds) ;
          Deferred.unit )

    let%test_unit "invalid transactions are not accepted" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          assert_pool_txs [] ;
          best_tip_ref :=
            map_set_multi !best_tip_ref [mk_account 0 0 0; mk_account 1 1_000 1] ;
          (* need a best tip diff so the ref is actually read *)
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= []
              ; removed_user_commands= []
              ; reorg_best_tip= false }
          in
          let%bind apply_res =
            Test.Resource_pool.Diff.apply pool
            @@ Envelope.Incoming.local independent_cmds
          in
          [%test_eq: User_command.t list Or_error.t]
            (Ok (List.drop independent_cmds 2))
            apply_res ;
          assert_pool_txs (List.drop independent_cmds 2) ;
          Deferred.unit )

    let mk_payment sender_idx fee nonce receiver_idx amount =
      User_command.forget_check
      @@ User_command.sign test_keys.(sender_idx)
           (User_command_payload.create ~fee:(Currency.Fee.of_int fee)
              ~valid_until:Coda_numbers.Global_slot.max_value
              ~nonce:(Account.Nonce.of_int nonce)
              ~memo:(User_command_memo.create_by_digesting_string_exn "foo")
              ~body:
                (User_command_payload.Body.Payment
                   { receiver=
                       Public_key.compress test_keys.(receiver_idx).public_key
                   ; amount= Currency.Amount.of_int amount }))

    let%test_unit "Now-invalid transactions are removed from the pool on fork \
                   changes" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          assert_pool_txs [] ;
          best_tip_ref := map_set_multi !best_tip_ref [mk_account 0 1_000 1] ;
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= List.take independent_cmds 2
              ; removed_user_commands= []
              ; reorg_best_tip= false }
          in
          assert_pool_txs [] ;
          let cmd1 =
            let sender = test_keys.(0) in
            Quickcheck.random_value
              (User_command.Gen.payment ~sign_type:`Real
                 ~key_gen:
                   Quickcheck.Generator.(
                     tuple2 (return sender) (Quickcheck_lib.of_array test_keys))
                 ~nonce:(Account.Nonce.of_int 1) ~max_amount:100 ~max_fee:10 ())
          in
          let%bind apply_res =
            Test.Resource_pool.Diff.apply pool @@ Envelope.Incoming.local [cmd1]
          in
          [%test_eq: User_command.t list Or_error.t] apply_res (Ok [cmd1]) ;
          assert_pool_txs [cmd1] ;
          let cmd2 = mk_payment 0 1 0 5 999 in
          best_tip_ref := map_set_multi !best_tip_ref [mk_account 0 0 1] ;
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= cmd2 :: List.drop independent_cmds 2
              ; removed_user_commands= List.take independent_cmds 2
              ; reorg_best_tip= true }
          in
          assert_pool_txs [List.nth_exn independent_cmds 1] ;
          Deferred.unit )

    let%test_unit "Now-invalid transactions are removed from the pool when \
                   the transition frontier is recreated" =
      Thread_safe.block_on_async_exn (fun () ->
          (* Set up initial frontier *)
          let frontier_pipe_r, frontier_pipe_w = Broadcast_pipe.create None in
          let logger = Logger.null () in
          let trust_system = Trust_system.null () in
          let config = Test.Resource_pool.make_config ~trust_system in
          let pool =
            Test.Resource_pool.create ~config ~logger
              ~frontier_broadcast_pipe:frontier_pipe_r
          in
          let assert_pool_txs txs =
            [%test_eq: User_command.t List.t]
              ( Test.Resource_pool.transactions pool
              |> Sequence.map ~f:User_command.forget_check
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
          let%bind _ =
            Test.Resource_pool.Diff.apply pool
              (Envelope.Incoming.local independent_cmds)
          in
          assert_pool_txs @@ independent_cmds ;
          (* Destroy initial frontier *)
          Broadcast_pipe.Writer.close best_tip_diff_w1 ;
          let%bind _ = Broadcast_pipe.Writer.write frontier_pipe_w None in
          (* Set up second frontier *)
          let ((_, ledger_ref2) as frontier2), _best_tip_diff_w2 =
            Mock_transition_frontier.create ()
          in
          ledger_ref2 :=
            map_set_multi !ledger_ref2
              [mk_account 0 20_000 5; mk_account 1 0 0; mk_account 2 0 1] ;
          let%bind _ =
            Broadcast_pipe.Writer.write frontier_pipe_w (Some frontier2)
          in
          assert_pool_txs @@ List.drop independent_cmds 3 ;
          Deferred.unit )

    let%test_unit "transaction replacement works and drops later transactions"
        =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind assert_pool_txs, pool, _best_tip_diff_w, _frontier =
        setup_test ()
      in
      let set_sender idx (tx : User_command.t) =
        User_command.forget_check
        @@ User_command.sign test_keys.(idx) tx.payload
      in
      let txs0 =
        [mk_payment 0 1 0 9 20; mk_payment 0 1 1 9 12; mk_payment 0 1 2 9 500]
      in
      let txs1 = List.map ~f:(set_sender 1) txs0 in
      let txs2 = List.map ~f:(set_sender 2) txs0 in
      let txs3 = List.map ~f:(set_sender 3) txs0 in
      let txs_all = txs0 @ txs1 @ txs2 @ txs3 in
      let%bind apply_res =
        Test.Resource_pool.Diff.apply pool (Envelope.Incoming.local txs_all)
      in
      [%test_eq: User_command.t list Or_error.t] (Ok txs_all) apply_res ;
      assert_pool_txs @@ txs_all ;
      let replace_txs =
        [ (* sufficient fee *)
          mk_payment 0 16 0 1 440
        ; (* insufficient fee *)
          mk_payment 1 4 0 1 788
        ; (* sufficient *)
          mk_payment 2 20 1 4 721
        ; (* insufficient *)
          mk_payment 3 10 1 4 927 ]
      in
      let%bind apply_res_2 =
        Test.Resource_pool.Diff.apply pool
          (Envelope.Incoming.local replace_txs)
      in
      [%test_eq: User_command.t list Or_error.t]
        (Ok [List.nth_exn replace_txs 0; List.nth_exn replace_txs 2])
        apply_res_2 ;
      Deferred.unit

    let%test_unit "it drops queued transactions if a committed one makes \
                   there be insufficient funds" =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
        setup_test ()
      in
      let txs =
        [mk_payment 0 5 0 9 20; mk_payment 0 6 1 5 77; mk_payment 0 1 2 3 891]
      in
      let committed_tx = mk_payment 0 5 0 2 25 in
      let%bind apply_res =
        Test.Resource_pool.Diff.apply pool @@ Envelope.Incoming.local txs
      in
      [%test_eq: User_command.t list Or_error.t] (Ok txs) apply_res ;
      assert_pool_txs @@ txs ;
      best_tip_ref := map_set_multi !best_tip_ref [mk_account 0 970 1] ;
      let%bind () =
        Broadcast_pipe.Writer.write best_tip_diff_w
          { new_user_commands= [committed_tx]
          ; removed_user_commands= []
          ; reorg_best_tip= false }
      in
      assert_pool_txs [List.nth_exn txs 1] ;
      Deferred.unit

    let%test_unit "max size is maintained" =
      Quickcheck.test ~trials:500
        (let open Quickcheck.Generator.Let_syntax in
        let%bind init_ledger_state = Ledger.gen_initial_ledger_state in
        let%bind cmds_count =
          Int.gen_incl Test.Resource_pool.pool_max_size
            (Test.Resource_pool.pool_max_size * 2)
        in
        let%bind cmds =
          User_command.Gen.sequence ~sign_type:`Real ~length:cmds_count
            init_ledger_state
        in
        return (init_ledger_state, cmds))
        ~f:(fun (init_ledger_state, cmds) ->
          Thread_safe.block_on_async_exn (fun () ->
              let%bind ( _assert_pool_txs
                       , pool
                       , best_tip_diff_w
                       , (_, best_tip_ref) ) =
                setup_test ()
              in
              let mock_ledger =
                Public_key.Compressed.Map.of_alist_exn
                  ( init_ledger_state |> Array.to_sequence
                  |> Sequence.map ~f:(fun (kp, bal, nonce) ->
                         let public_key = Public_key.compress kp.public_key in
                         ( public_key
                         , { (Account.initialize public_key) with
                             balance=
                               Currency.Balance.of_int
                                 (Currency.Amount.to_int bal)
                           ; nonce } ) )
                  |> Sequence.to_list )
              in
              best_tip_ref := mock_ledger ;
              let%bind () =
                Broadcast_pipe.Writer.write best_tip_diff_w
                  { new_user_commands= []
                  ; removed_user_commands= []
                  ; reorg_best_tip= true }
              in
              let cmds1, cmds2 =
                List.split_n cmds Test.Resource_pool.pool_max_size
              in
              let%bind apply_res1 =
                Test.Resource_pool.Diff.apply pool
                  (Envelope.Incoming.local cmds1)
              in
              assert (Result.is_ok apply_res1) ;
              [%test_eq: int] Test.Resource_pool.pool_max_size
                (Indexed_pool.size pool.pool) ;
              let%map _apply_res2 =
                Test.Resource_pool.Diff.apply pool
                  (Envelope.Incoming.local cmds2)
              in
              (* N.B. Adding a transaction when the pool is full may drop > 1
                 command, so the size now is not necessarily the maximum.
                 Applying the diff may also return an error if none of the new
                 commands have higher fee than the lowest one already in the
                 pool.
              *)
              assert (
                Indexed_pool.size pool.pool <= Test.Resource_pool.pool_max_size
              ) ) )

    let assert_rebroadcastable pool cmds =
      let normalize = List.sort ~compare:User_command.compare in
      let expected =
        match normalize cmds with [] -> [] | normalized -> [normalized]
      in
      [%test_eq: User_command.t list list]
        ( List.map ~f:normalize
        @@ Test.Resource_pool.get_rebroadcastable pool
             ~is_expired:(Fn.const `Ok) )
        expected

    let mock_sender =
      Envelope.Sender.Remote (Unix.Inet_addr.of_string "1.2.3.4")

    let%test_unit "rebroadcastable transaction behavior" =
      Thread_safe.block_on_async_exn (fun () ->
          let%bind assert_pool_txs, pool, best_tip_diff_w, _frontier =
            setup_test ()
          in
          assert_pool_txs [] ;
          let local_cmds = List.take independent_cmds 5 in
          let remote_cmds = List.drop independent_cmds 5 in
          (* Locally generated transactions are rebroadcastable *)
          let%bind apply_res_1 =
            Test.Resource_pool.Diff.apply pool
              (Envelope.Incoming.local local_cmds)
          in
          [%test_eq: User_command.t list Or_error.t] apply_res_1
            (Ok local_cmds) ;
          assert_pool_txs local_cmds ;
          assert_rebroadcastable pool local_cmds ;
          (* Adding non-locally-generated transactions doesn't affect
             rebroadcastable pool *)
          let%bind apply_res_2 =
            Test.Resource_pool.Diff.apply pool
              (Envelope.Incoming.wrap ~data:remote_cmds ~sender:mock_sender)
          in
          [%test_eq: User_command.t list Or_error.t] apply_res_2
            (Ok remote_cmds) ;
          assert_pool_txs (local_cmds @ remote_cmds) ;
          assert_rebroadcastable pool local_cmds ;
          (* When locally generated transactions are committed they are no
             longer rebroadcastable *)
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands=
                  List.take local_cmds 2 @ List.take remote_cmds 3
              ; removed_user_commands= []
              ; reorg_best_tip= false }
          in
          assert_pool_txs (List.drop local_cmds 2 @ List.drop remote_cmds 3) ;
          assert_rebroadcastable pool (List.drop local_cmds 2) ;
          (* Reorgs put locally generated transactions back into the
             rebroadcastable pool, if they were removed and not re-added *)
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= List.take local_cmds 1
              ; removed_user_commands= List.take local_cmds 2
              ; reorg_best_tip= true }
          in
          assert_pool_txs (List.tl_exn local_cmds @ List.drop remote_cmds 3) ;
          assert_rebroadcastable pool (List.tl_exn local_cmds) ;
          (* Committing them again removes them from the pool again. *)
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands=
                  List.tl_exn local_cmds @ List.drop remote_cmds 3
              ; removed_user_commands= []
              ; reorg_best_tip= false }
          in
          assert_pool_txs [] ;
          assert_rebroadcastable pool [] ;
          (* A reorg that doesn't re-add anything puts the right things back
             into the rebroadcastable pool. *)
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= []
              ; removed_user_commands= List.drop local_cmds 3 @ remote_cmds
              ; reorg_best_tip= true }
          in
          assert_pool_txs (List.drop local_cmds 3 @ remote_cmds) ;
          assert_rebroadcastable pool (List.drop local_cmds 3) ;
          (* Committing again removes them. (Checking this works in both one and
             two step reorg processes) *)
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= [List.nth_exn local_cmds 3]
              ; removed_user_commands= []
              ; reorg_best_tip= false }
          in
          assert_pool_txs (List.drop local_cmds 4 @ remote_cmds) ;
          assert_rebroadcastable pool (List.drop local_cmds 4) ;
          (* When transactions expire from rebroadcast pool they are gone. This
             doesn't affect the main pool.
          *)
          let _ =
            Test.Resource_pool.get_rebroadcastable pool
              ~is_expired:(Fn.const `Expired)
          in
          assert_pool_txs (List.drop local_cmds 4 @ remote_cmds) ;
          assert_rebroadcastable pool [] ;
          Deferred.unit )
  end )
