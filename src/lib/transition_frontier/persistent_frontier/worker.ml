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

  let apply_diff (type mutant) ~old_root ~arcs_cache (t : t)
      (diff : mutant Diff.Lite.t) : Database.batch_t -> unit =
    match diff with
    | New_node (Lite transition) ->
        Database.add ~arcs_cache ~transition
    | Root_transitioned
        { new_root; garbage = Lite garbage; just_emitted_a_proof } ->
        if just_emitted_a_proof then (
          [%log' info t.logger] "Dequeued a snarked ledger" ;
          Persistent_root.Instance.dequeue_snarked_ledger
            t.persistent_root_instance ) ;
        Database.move_root ~old_root ~new_root ~garbage
    | Best_tip_changed best_tip_hash ->
        Database.set_best_tip best_tip_hash

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
        let all_root_transitioned =
          List.rev_filter_map input ~f:(function
            | Diff.Lite.E.E (Root_transitioned _ as r) ->
                Some r
            | _ ->
                None )
        in
        (* We merge all Root_transitioned events into the last one *)
        let last_root_transitioned =
          match all_root_transitioned with
          | Root_transitioned ({ garbage = Lite garbage; _ } as r) :: rest ->
              (* Order of garbage is not fuilly preserved, but this doesn't matter for persistent frontier handling *)
              let more_garbage =
                List.concat_map rest ~f:(function
                  | Root_transitioned { new_root; garbage = Lite garbage; _ } ->
                      (Root_data.Limited.hashes new_root).state_hash :: garbage
                  | _ ->
                      [] )
              in
              Some
                (Diff.Lite.E.E
                   (Root_transitioned
                      { r with garbage = Lite (more_garbage @ garbage) } ) )
          | _ ->
              None
        in
        let append_best_tip diff = function
          | acc, `Best_tip false, root ->
              (diff :: acc, `Best_tip true, root)
          | x ->
              x
        in
        let append_root = function
          | acc, bt, `Root false ->
              ( Option.value_map ~default:ident ~f:List.cons
                  last_root_transitioned acc
              , bt
              , `Root true )
          | x ->
              x
        in
        let append diff (acc, bt, root) = (diff :: acc, bt, root) in
        let input, _, _ =
          List.fold_right
            ~init:([], `Best_tip false, `Root false)
            input
            ~f:(function
              | E (Best_tip_changed _) as diff ->
                  append_best_tip diff
              | E (Root_transitioned _) ->
                  append_root
              | diff ->
                  append diff )
        in
        let parent_hashes =
          List.filter_map input ~f:(function
            | E (New_node (Lite transition)) ->
                Mina_block.Validated.header transition
                |> Header.protocol_state
                |> Mina_state.Protocol_state.previous_state_hash |> Option.some
            | _ ->
                None )
        in
        let fs_res =
          let%map.Result old_root =
            Database.find_arcs_and_root t.db ~arcs_cache ~parent_hashes
          in
          List.map
            ~f:(fun (Diff.Lite.E.E diff) ->
              apply_diff ~old_root ~arcs_cache t diff )
            input
        in
        match fs_res with
        | Error (`Not_found (`Arcs h)) ->
            [%log' warn t.logger]
              "Did not add node to DB. Its $parent has already been thrown away"
              ~metadata:[ ("parent", `String (State_hash.to_base58_check h)) ] ;
            Deferred.unit
        | Error (`Not_found `Old_root_transition) ->
            failwith
              "Failed to apply a diff to the persistent transition frontier"
        | Ok fs ->
            let%map () = Scheduler.yield () in
            Database.with_batch t.db ~f:(fun batch ->
                List.iter fs ~f:(fun f -> f batch) ) )
end

include Worker_supervisor.Make (Worker)
