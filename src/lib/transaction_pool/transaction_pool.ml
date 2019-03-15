(** A pool of transactions that can be included in future blocks. Combined with
    the Network_pool module, this handles storing and gossiping the correct
    transactions (user commands) and providing them to the proposer code. *)

open Core_kernel
open Async
open Protocols.Coda_transition_frontier
open Pipe_lib

module type Transition_frontier_intf = sig
  type t

  type user_command

  type staged_ledger

  module Breadcrumb : sig
    type t [@@deriving sexp]

    val staged_ledger : t -> staged_ledger

    val to_user_commands : t -> user_command list
  end

  module Extensions : sig
    module Best_tip_diff : sig
      type view = user_command Best_tip_diff_view.t
    end
  end

  val best_tip : t -> Breadcrumb.t

  val best_tip_diff_pipe :
    t -> Extensions.Best_tip_diff.view Broadcast_pipe.Reader.t
end

module type User_command_intf = sig
  module Stable : sig
    module Latest : sig
      type t [@@deriving sexp, bin_io]
    end
  end

  type t = Stable.Latest.t [@@deriving sexp]

  include Comparable.S with type t := t

  module With_valid_signature : sig
    type nonrec t = private t [@@deriving sexp]

    include Comparable.S with type t := t
  end

  val check : t -> With_valid_signature.t option

  val forget_check : With_valid_signature.t -> t
end

module type Transaction_validator_intf = sig
  type base_ledger

  type user_command_with_valid_signature

  module Hashless_ledger : sig
    type t
  end

  val create : base_ledger -> Hashless_ledger.t

  val apply_user_command :
    Hashless_ledger.t -> user_command_with_valid_signature -> unit Or_error.t
end

(*
 * TODO: Remove could be really slow, we need to deal with this:
 *
 *  Reification of in-person discussion:
 *  Let's say our transaction pool has 100M transactions in it
 *  The question is: How often will we be removing transactions?
 *
 * 1. If we want to minimize space, we can remove transactions as soon as we
 *    see that they were used. In this case, we shouldn't use an Fheap as
 *    removing is O(n). We could use a balanced BST instead and remove would be
 *    faster, but we'd sacrifice `get` performance.
 * 2. We could instead just pop from our heap until we get `k` transactions that
 *    are valid on the current state (optionally we could use periodic garbage
 *    collection as well).
 *
 * For now we are removing lazily when we look for the next transactions
 *)
(* Functor over user command, base ledger and transaction validator for mocking. *)
module Make0
    (User_command : User_command_intf) (Base_ledger : sig
        type t
    end) (Staged_ledger : sig
      type t

      val ledger : t -> Base_ledger.t
    end)
    (Transaction_validator : Transaction_validator_intf
                             with type base_ledger := Base_ledger.t
                             with type user_command_with_valid_signature :=
                                         User_command.With_valid_signature.t)
    (Transition_frontier : Transition_frontier_intf
                           with type user_command := User_command.t
                            and type staged_ledger := Staged_ledger.t) =
struct
  module Breadcrumb = Transition_frontier.Breadcrumb

  type pool =
    { heap: User_command.With_valid_signature.t Fheap.t
    ; set: User_command.With_valid_signature.Set.t }

  type t =
    { mutable pool: pool
    ; log: Logger.t
    ; mutable diff_reader:
        unit Deferred.t Option.t
        (* TODO we want to validate against the best tip + any relevant commands
       already in the pool, to support queuing. *)
    ; mutable best_tip_ledger: Base_ledger.t option }

  let add' pool txn = {heap= Fheap.add pool.heap txn; set= Set.add pool.set txn}

  let add t txn = t.pool <- add' t.pool txn

  (* FIXME terrible hack *)
  let remove_tx t tx =
    let filter_out_tx =
      (* The user commands in the breadcrumbs we get *have* been checked for
         valid signatures, but we don't express that with types yet. *)
      List.filter ~f:(fun tx' ->
          User_command.compare tx (User_command.forget_check tx') <> 0 )
    in
    t.pool
    <- { heap=
           Fheap.to_list t.pool.heap |> filter_out_tx
           |> Fheap.of_list ~cmp:User_command.With_valid_signature.compare
       ; set=
           User_command.With_valid_signature.Set.to_list t.pool.set
           |> filter_out_tx |> User_command.With_valid_signature.Set.of_list }

  (** Update the best tip ledger and create a fresh validation ledger. **)
  let get_validation_ledger_and_update t frontier =
    let best_tip_ledger =
      Transition_frontier.best_tip frontier
      |> Breadcrumb.staged_ledger |> Staged_ledger.ledger
    in
    t.best_tip_ledger <- Some best_tip_ledger ;
    Transaction_validator.create best_tip_ledger

  (** Create a fresh validation ledger. *)
  let get_validation_ledger t =
    Option.map ~f:Transaction_validator.create t.best_tip_ledger

  let handle_diff t frontier
      ({new_user_commands; removed_user_commands; _} :
        Transition_frontier.Extensions.Best_tip_diff.view) =
    (* This runs whenever the best tip changes. The simple case is when the new
       best tip is an extension of the old one. There, we remove any user
       commands that were included in it from the transaction pool. Dealing with
       a fork is more intricate. In general we want to remove any commands from
       the pool that are included in the new best tip; and add any commands to
       the pool that were included in the old one but not the new one, provided
       they are still valid against the ledger of the best tip. The goal is that
       transactions are carried from losing forks to winning ones as much as
       possible. *)
    let validation_ledger = get_validation_ledger_and_update t frontier in
    Logger.trace t.log
      !"Diff: removed: %{sexp:User_command.t list} added: \
        %{sexp:User_command.t list} from best tip"
      removed_user_commands new_user_commands ;
    let removed_set = User_command.Set.of_list removed_user_commands in
    let added_set = User_command.Set.of_list new_user_commands in
    let removed_but_not_added = User_command.Set.diff removed_set added_set in
    (* Only considering commands that were added to the best tip and not removed
       is an optimization, we have the invariant that a command in the pool is
       never in the best tip. *)
    let added_but_not_removed = User_command.Set.diff added_set removed_set in
    Logger.trace t.log
      !"Re-adding: %{sexp:User_command.Set.t}"
      removed_but_not_added ;
    Sequence.iter
      ( Sequence.of_list removed_user_commands
      |> Sequence.filter ~f:(User_command.Set.mem removed_but_not_added) )
      ~f:(fun tx ->
        let tx =
          Option.value_exn
            ~message:
              "Somehow a user command from the frontier has an invalid \
               signature"
            (User_command.check tx)
        in
        (* Remember, apply_user_command is side-effecting. We're checking that
             the transactions are valid against the new best tip when applied in
             sequence. *)
        match
          Transaction_validator.apply_user_command validation_ledger tx
        with
        | Ok () -> add t tx
        | Error err ->
            Logger.trace t.log
              !"Transaction %{sexp: User_command.With_valid_signature.t} \
                removed from best tip not valid against new best tip because: \
                %{sexp: Error.t}. (This is not necessarily an error.)"
              tx err ) ;
    User_command.Set.iter added_but_not_removed ~f:(fun tx -> remove_tx t tx) ;
    Logger.trace t.log
      !"Current pool is: %{sexp: User_command.With_valid_signature.t list}"
    @@ Fheap.to_list t.pool.heap ;
    Deferred.unit

  let create ~parent_log ~frontier_broadcast_pipe =
    let t =
      { pool=
          { heap= Fheap.create ~cmp:User_command.With_valid_signature.compare
          ; set= User_command.With_valid_signature.Set.empty }
      ; log= Logger.child parent_log __MODULE__
      ; diff_reader= None
      ; best_tip_ledger= None }
    in
    don't_wait_for
      (Broadcast_pipe.Reader.iter frontier_broadcast_pipe
         ~f:(fun frontier_opt ->
           match frontier_opt with
           | None -> (
               Logger.debug t.log "no frontier" ;
               (* Sanity check: the view pipe should have been closed before the
                    frontier was destroyed. *)
               match t.diff_reader with
               | None -> Deferred.unit
               | Some hdl ->
                   let is_finished = ref false in
                   t.best_tip_ledger <- None ;
                   Deferred.any_unit
                     [ (let%map () = hdl in
                        t.diff_reader <- None ;
                        is_finished := true)
                     ; (let%map () = Async.after (Time.Span.of_sec 5.) in
                        if not !is_finished then (
                          Logger.fatal t.log
                            "Transition frontier closed without first closing \
                             best tip view pipe" ;
                          assert false )
                        else ()) ] )
           | Some frontier ->
               Logger.debug t.log "Got frontier!\n" ;
               let validation_ledger =
                 get_validation_ledger_and_update t frontier
               in
               let old_txs = Fheap.to_sequence t.pool.heap in
               let new_txs =
                 Sequence.to_list
                 @@ Sequence.filter old_txs ~f:(fun tx ->
                        Or_error.is_ok
                        @@ Transaction_validator.apply_user_command
                             validation_ledger tx )
               in
               t.pool
               <- { heap=
                      Fheap.of_list new_txs
                        ~cmp:User_command.With_valid_signature.compare
                  ; set= User_command.With_valid_signature.Set.of_list new_txs
                  } ;
               Logger.debug t.log
                 !"Re-validated transaction pool after restart: %i of %i \
                   still valid"
                 (List.length new_txs) (Sequence.length old_txs) ;
               t.diff_reader
               <- Some
                    (Broadcast_pipe.Reader.iter
                       (Transition_frontier.best_tip_diff_pipe frontier)
                       ~f:(handle_diff t frontier)) ;
               Deferred.unit )) ;
    t

  let transactions t = Sequence.unfold ~init:t.pool.heap ~f:Fheap.pop

  module Diff = struct
    type t = User_command.Stable.Latest.t list [@@deriving bin_io, sexp]

    let summary t =
      Printf.sprintf "Transaction diff of length %d" (List.length t)

    let apply t env =
      let txns = Envelope.Incoming.data env in
      let pool0 = t.pool in
      let pool', res =
        List.fold txns ~init:(pool0, []) ~f:(fun (pool, acc) txn ->
            match User_command.check txn with
            | None ->
                Logger.faulty_peer t.log
                  !"Transaction doesn't check %{sexp: Envelope.Sender.t}"
                  (Envelope.Incoming.sender env) ;
                (pool, acc)
            | Some txn -> (
                if Set.mem pool.set txn then (
                  Logger.debug t.log
                    !"Skipping txn %{sexp: \
                      User_command.With_valid_signature.t} because I've \
                      already seen it"
                    txn ;
                  (pool, acc) )
                else
                  (* FIXME this does not support queuing multiple transactions
                     from one account. Fix this in #1734. *)
                  match get_validation_ledger t with
                  | None ->
                      Logger.debug t.log
                        !"Transition frontier not available, rejecting \
                          transaction %{sexp: \
                          User_command.With_valid_signature.t}"
                        txn ;
                      (pool, acc)
                  | Some validation_ledger -> (
                    match
                      Transaction_validator.apply_user_command
                        validation_ledger txn
                    with
                    | Ok () ->
                        Logger.debug t.log
                          !"Adding %{sexp: \
                            User_command.With_valid_signature.t} to my pool \
                            locally, and scheduling for rebroadcast"
                          txn ;
                        (add' pool txn, (txn :> User_command.t) :: acc)
                    | Error err ->
                        Logger.faulty_peer t.log
                          !"Got transaction not valid against strongest \
                            ledger: %{sexp: \
                            User_command.With_valid_signature.t}, because \
                            %{sexp: Error.t} rejecting."
                          txn err ;
                        (pool, acc) ) ) )
      in
      t.pool <- pool' ;
      match res with
      | [] -> Deferred.Or_error.error_string "No new transactions"
      | xs -> Deferred.Or_error.return xs
  end

  (* TODO: Actually back this by the file-system *)
  let load ~disk_location:_ ~parent_log ~frontier_broadcast_pipe:_ =
    return (create ~parent_log)
end

(* Use this one in downstream consumers *)
module Make (Staged_ledger : sig
  type t

  val ledger : t -> Coda_base.Ledger.t
end)
(Transition_frontier : Transition_frontier_intf
                       with type user_command := Coda_base.User_command.t
                       with type staged_ledger := Staged_ledger.t) =
  Make0 (Coda_base.User_command) (Coda_base.Ledger) (Staged_ledger)
    (Coda_base.Transaction_validator)
    (Transition_frontier)

let%test_module _ =
  ( module struct
    module Mock_transition_frontier = struct
      module Breadcrumb = struct
        (* List of txs in that block, set of txs that are invalid when applying
           to the staged ledger of that block. *)
        type t = int list * Int.Set.t [@@deriving sexp]

        let staged_ledger = Tuple2.get2

        let to_user_commands = Tuple2.get1
      end

      type t =
        int Best_tip_diff_view.t Broadcast_pipe.Reader.t * Breadcrumb.t ref

      module Extensions = struct
        module Best_tip_diff = struct
          type view = int Best_tip_diff_view.t
        end
      end

      let best_tip (_pipe_r, best_tip_ref) = !best_tip_ref

      let best_tip_diff_pipe = Tuple2.get1

      let create () : t * int Best_tip_diff_view.t Broadcast_pipe.Writer.t =
        let pipe_r, pipe_w =
          Broadcast_pipe.create
            ( { new_user_commands= []
              ; removed_user_commands= []
              ; best_tip_length= -1 }
              : int Best_tip_diff_view.t )
        in
        ((pipe_r, ref ([], Int.Set.empty)), pipe_w)
    end

    module Test =
      Make0 (struct
          module Stable = struct
            module Latest = Int
          end

          include (Int : module type of Int with module Stable := Int.Stable)

          module With_valid_signature = Int

          let check = Option.some

          let forget_check = Fn.id
        end)
        (struct
          type t = Int.Set.t
        end)
        (struct
          type t = Int.Set.t

          let ledger = Fn.id
        end)
        (struct
          module Hashless_ledger = struct
            type t = Int.Set.t ref
          end

          let create ledger = ref ledger

          let apply_user_command ledgerR tx =
            if Int.Set.mem !ledgerR tx then Error (Error.of_string "oh no")
            else Ok ()
        end)
        (Mock_transition_frontier)

    let _ =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let setup_test () =
      let tf, best_tip_diff_w = Mock_transition_frontier.create () in
      let tf_pipe_r, _tf_pipe_w = Broadcast_pipe.create @@ Some tf in
      let pool =
        Test.create ~parent_log:(Logger.null ())
          ~frontier_broadcast_pipe:tf_pipe_r
      in
      ( (fun txs ->
          [%test_eq: int Sequence.t] (Test.transactions pool)
          @@ Sequence.of_list txs )
      , pool
      , best_tip_diff_w
      , tf )

    let%test "transactions are removed in linear case" =
      Thread_safe.block_on_async_exn (fun () ->
          let assert_pool_txs, pool, best_tip_diff_w, _frontier =
            setup_test ()
          in
          assert_pool_txs [] ;
          let txs = [0; 1; 2; 3] in
          List.iter ~f:(Test.add pool) txs ;
          assert_pool_txs txs ;
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= [2]
              ; removed_user_commands= []
              ; best_tip_length= -1 }
          in
          assert_pool_txs [0; 1; 3] ;
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= [0; 3]
              ; removed_user_commands= []
              ; best_tip_length= -1 }
          in
          assert_pool_txs [1] ;
          Deferred.return true )

    let%test "Transactions are removed and added back in fork changes" =
      Thread_safe.block_on_async_exn (fun () ->
          let assert_pool_txs, pool, best_tip_diff_w, _frontier =
            setup_test ()
          in
          assert_pool_txs [] ;
          let txs = [0; 1; 2; 3; 4] in
          List.iter ~f:(Test.add pool) txs ;
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= [0; 3]
              ; removed_user_commands= [5; 6]
              ; best_tip_length= -1 }
          in
          assert_pool_txs [1; 2; 4; 5; 6] ;
          Deferred.return true )

    let fake_peer : Network_peer.Peer.t =
      { host= Unix.Inet_addr.of_string "1.1.1.1"
      ; discovery_port= 2222
      ; communication_port= 2223 }

    let%test "Invalid transactions are not accepted" =
      Thread_safe.block_on_async_exn (fun () ->
          let assert_pool_txs, pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          assert_pool_txs [] ;
          best_tip_ref := ([], Int.Set.of_list [2; 5; 7]) ;
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= []
              ; removed_user_commands= []
              ; best_tip_length= -1 }
          in
          let%bind apply_res =
            Test.Diff.apply pool
            @@ Envelope.Incoming.wrap ~data:[3; 5; 10]
                 ~sender:(Remote fake_peer)
          in
          [%test_result: int list Or_error.t] ~expect:(Ok [10; 3]) apply_res ;
          Deferred.return true )

    let%test "Now-invalid transactions are removed from the pool on fork \
              changes" =
      Thread_safe.block_on_async_exn (fun () ->
          let assert_pool_txs, _pool, best_tip_diff_w, (_, best_tip_ref) =
            setup_test ()
          in
          assert_pool_txs [] ;
          best_tip_ref := ([5; 6; 7; 8], Int.Set.of_list [1; 4; 5; 6; 7; 8]) ;
          let%bind _ =
            Broadcast_pipe.Writer.write best_tip_diff_w
              { new_user_commands= [5; 6; 7; 8]
              ; removed_user_commands= [1; 2; 3; 4; 5]
              ; best_tip_length= -1 }
          in
          assert_pool_txs [2; 3] ;
          Deferred.return true )

    let%test "Now-invalid transactions are removed from the pool when the \
              transition frontier is recreated" =
      Thread_safe.block_on_async_exn (fun () ->
          (* Set up initial frontier *)
          let frontier_pipe_r, frontier_pipe_w = Broadcast_pipe.create None in
          let pool =
            Test.create ~parent_log:(Logger.null ())
              ~frontier_broadcast_pipe:frontier_pipe_r
          in
          let assert_pool_txs txs =
            [%test_eq: int Sequence.t] (Test.transactions pool)
            @@ Sequence.of_list txs
          in
          assert_pool_txs [] ;
          let init_bc_1 = ([], Int.Set.empty) in
          let best_tip_diff_r1, best_tip_diff_w1 =
            Broadcast_pipe.create
              Best_tip_diff_view.
                { new_user_commands= []
                ; removed_user_commands= []
                ; best_tip_length= -1 }
          in
          let frontier1 = (best_tip_diff_r1, ref init_bc_1) in
          let%bind _ =
            Broadcast_pipe.Writer.write frontier_pipe_w (Some frontier1)
          in
          List.iter ~f:(Test.add pool) [0; 1; 2; 3; 4; 5] ;
          assert_pool_txs [0; 1; 2; 3; 4; 5] ;
          (* Destroy initial frontier *)
          Broadcast_pipe.Writer.close best_tip_diff_w1 ;
          let%bind _ = Broadcast_pipe.Writer.write frontier_pipe_w None in
          (* Set up second frontier *)
          let best_tip_diff_r2, _best_tip_diff_w2 =
            Broadcast_pipe.create
              Best_tip_diff_view.
                { new_user_commands= []
                ; removed_user_commands= []
                ; best_tip_length= -1 }
          in
          let init_bc_2 = ([], Int.Set.of_list [2; 3; 5]) in
          let frontier2 = (best_tip_diff_r2, ref init_bc_2) in
          let%bind _ =
            Broadcast_pipe.Writer.write frontier_pipe_w (Some frontier2)
          in
          (* Transactions 2, 3, and 5 are invalid against the new best tip, and
             should have been removed. *)
          assert_pool_txs [0; 1; 4] ;
          Deferred.return true )
  end )
