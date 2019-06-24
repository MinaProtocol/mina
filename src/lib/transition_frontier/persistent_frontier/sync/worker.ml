open Async
open Core
open Otp_lib

module Make (Inputs : Intf.Inputs_with_db_intf) :
  Intf.Worker_intf
    with type db := Inputs.Db.t
     and type frontier_hash := Inputs.Frontier.Hash.t
     and type e_lite_diff := Inputs.Frontier.Diff.Lite.E.t = struct
  open Inputs

  module Worker = struct
    (* when this is transitioned to an RPC worker, the db argument
     * should just be a directory, but while this is still in process,candidate.curr_epoch_data.length
     * the full instance is needed to share with other threads
     *)
    type t = {db: Db.t; logger: Logger.t}
    type create_args = t

    type input = Frontier.Diff.Lite.E.t list * Frontier.Hash.t
    type output = unit Or_error.t

    (* worker assumes database has already been checked and initialized *)
    let create = Fn.id

    (* nothing to close *)
    let close _ = Deferred.unit

    let apply_diff (type mutant) (t : t) (diff : mutant Frontier.Diff.Lite.t) : mutant Or_error.t =
      match diff with
      | New_node (Lite transition) -> Db.add t.db ~transition
      | Root_transitioned {new_root; garbage} -> Db.move_root t.db ~new_root ~garbage
      | Best_tip_changed best_tip_hash -> Ok (Db.set_best_tip t.db best_tip_hash)
      (* HACK: the ocaml compiler will not allow refutation
       * of this case despite the fact that it also won't
       * let you pass in a full node representation
       *)
      | New_node (Full _) -> failwith "impossible"

    let handle_diff t hash (Frontier.Diff.Lite.E.E diff) =
      let open Or_error.Let_syntax in
      let%map mutant = apply_diff t diff in
      Frontier.Hash.merge_diff hash diff mutant

    let perform t (diffs, target_hash) =
      let open Deferred.Or_error.Let_syntax in
      let base_hash = Db.get_frontier_hash t.db in
      let%map result_hash =
        (* Iterating over the diff application in this way
         * effectively allows the scheduler to scheduler
         * other tasks in between diff applications.
         * If implemented otherwise, all diffs would be
         * applied during the same scheduler cycle.
         *)
        Deferred.Or_error.List.fold diffs
          ~init:base_hash
          ~f:(fun acc_hash diff ->
            Deferred.return (handle_diff t acc_hash diff))
      in
      (if not (Frontier.Hash.equal target_hash result_hash) then
        failwithf !"Failed to apply transiton frontier diffs to persistent database correctly: target hash was %s, resulting hash was %s"
          (Frontier.Hash.to_string target_hash)
          (Frontier.Hash.to_string result_hash)
          ())
  end

  type create_args = Worker.t = {db: Db.t; logger: Logger.t}

  include Worker_supervisor.Make(Worker)
end
