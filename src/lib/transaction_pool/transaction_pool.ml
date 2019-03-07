open Core_kernel
open Async
open Protocols.Coda_transition_frontier
open Pipe_lib

module type Transition_frontier_intf = sig
  type t

  type user_command

  module Breadcrumb : sig
    type t [@@deriving sexp]

    val to_user_commands : t -> user_command list
  end

  module Extensions : sig
    module Best_tip_diff : sig
      type view = user_command Best_tip_diff_view.t
    end
  end

  val best_tip_diff_pipe :
    t -> Extensions.Best_tip_diff.view Broadcast_pipe.Reader.t
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
module Make (User_command : sig
  type t [@@deriving compare, bin_io, sexp]

  module With_valid_signature : sig
    type nonrec t = private t [@@deriving sexp]

    include Comparable with type t := t
  end

  val check : t -> With_valid_signature.t option

  val forget_check : With_valid_signature.t -> t
end)
(Transition_frontier : Transition_frontier_intf
                       with type user_command := User_command.t) =
struct
  module Breadcrumb = Transition_frontier.Breadcrumb

  type pool =
    { heap: User_command.With_valid_signature.t Fheap.t
    ; set: User_command.With_valid_signature.Set.t }

  type t =
    { mutable pool: pool
    ; log: Logger.t
    ; mutable diff_reader: unit Deferred.t Option.t }

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

  let handle_diff t _frontier
      ({new_user_commands; removed_user_commands} :
        Transition_frontier.Extensions.Best_tip_diff.view) =
    Logger.trace t.log
      !"Diff: removed: %{sexp:User_command.t list} added: \
        %{sexp:User_command.t list} from best tip"
      removed_user_commands new_user_commands ;
    List.iter removed_user_commands ~f:(fun tx ->
        add t
          (Option.value_exn
             ~message:
               "Somehow a user command from the frontier has an invalid \
                signature"
             (User_command.check tx)) ) ;
    (* TODO We need to recheck validity here. Transactions from the old best
       chain may not be valid on the new chain. *)
    List.iter new_user_commands ~f:(fun tx -> remove_tx t tx) ;
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
      ; diff_reader= None }
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
                   Deferred.any_unit
                     [ (let%map () = hdl in
                        t.diff_reader <- None)
                     ; (let%map () = Async.after (Time.Span.of_sec 5.) in
                        Logger.fatal t.log
                          "Transition frontier closed without first closing \
                           best tip view pipe" ;
                        assert false) ] )
           | Some frontier ->
               Logger.debug t.log "Got frontier!\n" ;
               (* TODO check current pool contents are valid against best tip here *)
               t.diff_reader
               <- Some
                    (Broadcast_pipe.Reader.iter
                       (Transition_frontier.best_tip_diff_pipe frontier)
                       ~f:(handle_diff t frontier)) ;
               Deferred.unit )) ;
    t

  let transactions t = Sequence.unfold ~init:t.pool.heap ~f:Fheap.pop

  module Diff = struct
    type t = User_command.t list [@@deriving bin_io, sexp]

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
                  !"Transaction doesn't check %{sexp: Network_peer.Peer.t}"
                  (Envelope.Incoming.sender env) ;
                (pool, acc)
            | Some txn ->
                if Set.mem pool.set txn then (
                  Logger.debug t.log
                    !"Skipping txn %{sexp: \
                      User_command.With_valid_signature.t} because I've \
                      already seen it"
                    txn ;
                  (pool, acc) )
                else (
                  Logger.debug t.log
                    !"Adding %{sexp: User_command.With_valid_signature.t} to \
                      my pool locally, and scheduling for rebroadcast"
                    txn ;
                  (add' pool txn, (txn :> User_command.t) :: acc) ) )
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

let%test_module _ =
  ( module struct
    module Mock_transition_frontier = struct
      module Breadcrumb = struct
        type t = int list [@@deriving sexp]

        let to_user_commands = Fn.id
      end

      type t = int Best_tip_diff_view.t Broadcast_pipe.Reader.t

      module Extensions = struct
        module Best_tip_diff = struct
          type view = int Best_tip_diff_view.t
        end
      end

      let best_tip_diff_pipe = Fn.id

      let create () : t * int Best_tip_diff_view.t Broadcast_pipe.Writer.t =
        Broadcast_pipe.create
          ( {new_user_commands= []; removed_user_commands= []}
            : int Best_tip_diff_view.t )
    end

    module Test =
      Make (struct
          include Int
          module With_valid_signature = Int

          let check = Option.some

          let forget_check = Fn.id
        end)
        (Mock_transition_frontier)

    (* We only test the best tip change logic here, since this whole module
       needs rewriting, it doesn't make sense to test it all. *)
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
      , best_tip_diff_w )

    let%test _ =
      Thread_safe.block_on_async_exn (fun () ->
          let assert_pool_txs, pool, best_tip_diff_w = setup_test () in
          assert_pool_txs [] ;
          let txs = [0; 1; 2; 3] in
          List.iter ~f:(Test.add pool) txs ;
          assert_pool_txs txs ;
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              {new_user_commands= [2]; removed_user_commands= []}
          in
          assert_pool_txs [0; 1; 3] ;
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              {new_user_commands= [0; 3]; removed_user_commands= []}
          in
          assert_pool_txs [1] ;
          Deferred.return true )

    let%test _ =
      Thread_safe.block_on_async_exn (fun () ->
          let assert_pool_txs, pool, best_tip_diff_w = setup_test () in
          assert_pool_txs [] ;
          let txs = [0; 1; 2; 3; 4] in
          List.iter ~f:(Test.add pool) txs ;
          let%bind () =
            Broadcast_pipe.Writer.write best_tip_diff_w
              {new_user_commands= [0; 3]; removed_user_commands= [5; 6]}
          in
          assert_pool_txs [1; 2; 4; 5; 6] ;
          Deferred.return true )
  end )
