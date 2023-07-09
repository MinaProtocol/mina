open Async
open Core
open Otp_lib
open Mina_base
open Mina_block
open Frontier_base

type input = Diff.Lite.E.t list

type create_args =
  { db : Database.t
  ; logger : Logger.t
  ; persistent_root_instance : Persistent_root.Instance.t
  }

module Worker = struct
  (* when this is transitioned to an RPC worker, the db argument
   * should just be a directory, but while this is still in process,
   * the full instance is needed to share with other threads
   *)
  type nonrec input = input

  type t =
    { db : Database.t
    ; logger : Logger.t
    ; persistent_root_instance : Persistent_root.Instance.t
    }

  type nonrec create_args = create_args

  type output = unit

  (* worker assumes database has already been checked and initialized *)
  let create ({ db; logger; persistent_root_instance } : create_args) : t =
    { db; logger; persistent_root_instance }

  (* nothing to close *)
  let close _ = Deferred.unit

  type apply_diff_error =
    [ `Apply_diff of [ `New_node | `Root_transitioned | `Best_tip_changed ] ]

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
          (State_hash.to_base58_check hash)
    | `Not_found `Best_tip ->
        "best tip not found"
    | `Not_found (`Arcs hash) ->
        Printf.sprintf "arcs not found for %s" (State_hash.to_base58_check hash)

  let apply_diff (type mutant) ~arcs_cache (t : t) (diff : mutant Diff.Lite.t) :
      (Database.batch_t -> unit, apply_diff_error) Result.t =
    let map_error result ~diff_type ~diff_type_name =
      Result.map_error result ~f:(fun err ->
          [%log' error t.logger] "error applying %s diff: %s" diff_type_name
            (apply_diff_error_internal_to_string err) ;
          `Apply_diff diff_type )
    in
    match diff with
    | New_node (Lite transition) -> (
        let r =
          ( Database.add ~arcs_cache t.db ~transition
            :> (Database.batch_t -> unit, apply_diff_error_internal) Result.t )
        in
        match r with
        | Ok x ->
            Ok x
        | Error (`Not_found (`Parent_transition h | `Arcs h)) ->
            [%log' trace t.logger]
              "Did not add node $hash to DB. Its $parent has already been \
               thrown away"
              ~metadata:
                [ ( "hash"
                  , `String
                      (State_hash.to_base58_check
                         (Mina_block.Validated.state_hash transition) ) )
                ; ("parent", `String (State_hash.to_base58_check h))
                ] ;
            Ok ignore
        | _ ->
            map_error ~diff_type:`New_node ~diff_type_name:"New_node" r )
    | Root_transitioned
        { new_root; garbage = Lite garbage; just_emitted_a_proof } ->
        if just_emitted_a_proof then (
          [%log' info t.logger] "Dequeued a snarked ledger" ;
          Persistent_root.Instance.dequeue_snarked_ledger
            t.persistent_root_instance ) ;
        map_error ~diff_type:`Root_transitioned
          ~diff_type_name:"Root_transitioned"
          ( Database.move_root t.db ~new_root ~garbage
            :> (Database.batch_t -> unit, apply_diff_error_internal) Result.t )
    | Best_tip_changed best_tip_hash ->
        Result.return (Database.set_best_tip t.db best_tip_hash)

  (* result equivalent of Deferred.Or_error.List.fold *)
  let rec deferred_result_list_fold ls ~init ~f =
    let open Deferred.Result.Let_syntax in
    match ls with
    | [] ->
        return init
    | h :: t ->
        let%bind init = f init h in
        deferred_result_list_fold t ~init ~f

  let perform t input =
    let arcs_cache = State_hash.Table.create () in
    O1trace.thread "persistent_frontier_write_to_disk" (fun () ->
        [%log' trace t.logger] "Applying %d diffs to the persistent frontier"
          (List.length input) ;
        let best_tip_cnt, root_cnt =
          List.fold input ~init:(0, 0) ~f:(fun (b, r) -> function
            | Diff.Lite.E.E (Root_transitioned _) ->
                (b, r + 1)
            | E (Best_tip_changed _) ->
                (b + 1, r)
            | _ ->
                (b, r) )
        in
        let best_tip_cnt = ref best_tip_cnt in
        let root_cnt = ref root_cnt in
        let garbage_prev = ref [] in
        let input =
          List.filter_map input ~f:(function
            | Diff.Lite.E.E (Best_tip_changed _) as diff ->
                best_tip_cnt := !best_tip_cnt - 1 ;
                Option.some_if (!best_tip_cnt = 0) diff
            | E
                (Root_transitioned
                  ({ new_root; garbage = Lite garbage_this; _ } as r) ) ->
                root_cnt := !root_cnt - 1 ;
                if !root_cnt = 0 then
                  Some
                    (E
                       (Root_transitioned
                          { r with
                            garbage = Lite (!garbage_prev @ garbage_this)
                          } ) )
                else (
                  garbage_prev :=
                    (Root_data.Limited.hashes new_root).state_hash
                    :: garbage_this
                    @ !garbage_prev ;
                  None )
            | diff ->
                Some diff )
        in
        let fs_res =
          List.map
            ~f:(fun (Diff.Lite.E.E diff) -> apply_diff ~arcs_cache t diff)
            input
          |> Result.all
        in
        let%map () = Scheduler.yield () in
        match fs_res with
        | Ok fs ->
            Database.with_batch t.db ~f:(fun batch ->
                List.iter fs ~f:(fun f -> f batch) )
        (* TODO: log the diff that failed *)
        | Error (`Apply_diff _) ->
            failwith
              "Failed to apply a diff to the persistent transition frontier" )
end

include Worker_supervisor.Make (Worker)
