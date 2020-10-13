open Async
open Core
open Otp_lib
open Coda_base
open Frontier_base

type input =
  { diffs: Diff.Lite.E.t list
  ; target_hash: Frontier_hash.t
  ; garbage: State_hash.Hash_set.t }

module Worker = struct
  (* when this is transitioned to an RPC worker, the db argument
   * should just be a directory, but while this is still in process,
   * the full instance is needed to share with other threads
   *)
  type t = {db: Database.t; logger: Logger.t}

  type nonrec input = input

  type create_args = t

  type output = unit

  (* worker assumes database has already been checked and initialized *)
  let create = Fn.id

  (* nothing to close *)
  let close _ = Deferred.unit

  type apply_diff_error =
    [`Apply_diff of [`New_node | `Root_transitioned | `Best_tip_changed]]

  type apply_diff_error_internal =
    [ `Not_found of
      [ `New_root_transition
      | `Old_root_transition
      | `Parent_transition of State_hash.t
      | `Arcs of State_hash.t
      | `Best_tip ] ]

  let apply_diff_error_internal_to_string = function
    | `Not_found `New_root_transition ->
        "new root transition not found"
    | `Not_found `Old_root_transition ->
        "old root transition not found"
    | `Not_found (`Parent_transition hash) ->
        Printf.sprintf "parent transition %s not found"
          (State_hash.to_string hash)
    | `Not_found `Best_tip ->
        "best tip not found"
    | `Not_found (`Arcs hash) ->
        Printf.sprintf "arcs not found for %s" (State_hash.to_string hash)

  let apply_diff (type mutant) (t : t) ~garbage (diff : mutant Diff.Lite.t) :
      [`Normal of (mutant, apply_diff_error) Result.t | `Irrelevant_diff] =
    let map_error result ~diff_type ~diff_type_name =
      `Normal
        (Result.map_error result ~f:(fun err ->
             [%log' error t.logger] "error applying %s diff: %s" diff_type_name
               (apply_diff_error_internal_to_string err) ;
             `Apply_diff diff_type ))
    in
    match diff with
    | New_node (Lite transition) -> (
        let r =
          ( Database.add t.db ~transition
            :> (mutant, apply_diff_error_internal) Result.t )
        in
        match r with
        | Ok x ->
            `Normal (Ok x)
        | Error (`Not_found (`Parent_transition h | `Arcs h))
          when Hash_set.mem garbage h ->
            `Irrelevant_diff
        | _ ->
            map_error ~diff_type:`New_node ~diff_type_name:"New_node" r )
    | Root_transitioned {new_root; garbage= Lite garbage} ->
        map_error ~diff_type:`Root_transitioned
          ~diff_type_name:"Root_transitioned"
          ( Database.move_root t.db ~new_root ~garbage
            :> (mutant, apply_diff_error_internal) Result.t )
    | Best_tip_changed best_tip_hash ->
        map_error ~diff_type:`Best_tip_changed
          ~diff_type_name:"Best_tip_changed"
          ( Database.set_best_tip t.db best_tip_hash
            :> (mutant, apply_diff_error_internal) Result.t )
    (* HACK: the ocaml compiler will not allow refutation
     * of this case despite the fact that it also won't
     * let you pass in a full node representation
     *)
    | Root_transitioned {garbage= Full _; _} ->
        failwith "impossible"
    | New_node (Full _) ->
        failwith "impossible"

  let handle_diff t hash ~garbage (Diff.Lite.E.E diff) =
    let open Result.Let_syntax in
    match apply_diff t ~garbage diff with
    | `Normal m ->
        let%map mutant = m in
        Frontier_hash.merge_diff hash diff mutant
    | `Irrelevant_diff ->
        Ok hash

  (* result equivalent of Deferred.Or_error.List.fold *)
  let rec deferred_result_list_fold ls ~init ~f =
    let open Deferred.Result.Let_syntax in
    match ls with
    | [] ->
        return init
    | h :: t ->
        let%bind init = f init h in
        deferred_result_list_fold t ~init ~f

  type perform_error =
    [ apply_diff_error
    | [`Not_found of [`Frontier_hash]]
    | [`Invalid_resulting_frontier_hash of Frontier_hash.t] ]

  (* TODO: rewrite with open polymorphic variants to avoid type coercion *)
  let perform t {diffs; target_hash; garbage} =
    let open Deferred.Let_syntax in
    match%map
      let open Deferred.Result.Let_syntax in
      let%bind base_hash =
        Deferred.return
          ( Database.get_frontier_hash t.db
            :> (Frontier_hash.t, perform_error) Result.t )
      in
      [%log' trace t.logger]
        "Applying %d diffs to the persistent frontier (%s --> %s)"
        (List.length diffs)
        (Frontier_hash.to_string base_hash)
        (Frontier_hash.to_string target_hash) ;
      let%bind result_hash =
        (* Iterating over the diff application in this way
         * effectively allows the scheduler to scheduler
         * other tasks in between diff applications.
         * If implemented otherwise, all diffs would be
         * applied during the same scheduler cycle.
         *)
        deferred_result_list_fold diffs ~init:base_hash
          ~f:(fun acc_hash diff ->
            Deferred.return
              ( handle_diff ~garbage t acc_hash diff
                :> (Frontier_hash.t, perform_error) Result.t ) )
      in
      let%map () =
        Deferred.return
          ( Result.ok_if_true
              (Frontier_hash.equal target_hash result_hash)
              ~error:(`Invalid_resulting_frontier_hash result_hash)
            :> (unit, perform_error) Result.t )
      in
      Database.set_frontier_hash t.db result_hash
    with
    | Ok () ->
        ()
    (* TODO: log the diff that failed *)
    | Error (`Apply_diff _) ->
        failwith "Failed to apply a diff to the persistent transition frontier"
    | Error (`Not_found `Frontier_hash) ->
        failwith
          "Failed to find frontier hash in persistent transition frontier"
    | Error (`Invalid_resulting_frontier_hash result_hash) ->
        failwithf
          "Failed to apply transiton frontier diffs to persistent database \
           correctly: target hash was %s, resulting hash was %s"
          (Frontier_hash.to_string target_hash)
          (Frontier_hash.to_string result_hash)
          ()
end

type create_args = Worker.t = {db: Database.t; logger: Logger.t}

include Worker_supervisor.Make (Worker)
