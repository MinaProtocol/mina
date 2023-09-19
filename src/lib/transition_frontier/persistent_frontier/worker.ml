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
    | Root_transitioned { new_root; garbage = Lite garbage; _ } ->
        Database.move_root ~old_root ~new_root ~garbage
    | Best_tip_changed best_tip_hash ->
        Database.set_best_tip best_tip_hash

  let perform t input =
    let arcs_cache = State_hash.Table.create () in
    O1trace.sync_thread "persistent_frontier_write_to_disk" (fun () ->
        [%log' trace t.logger] "Applying %d diffs to the persistent frontier"
          (List.length input) ;
        (* OPTIMIZATION: Compress the best tip diffs and root transition diffs in order avoid unnecessary intermediate writes. *)
        let best_tip_diffs, root_transition_diffs, other_diffs =
          List.partition3_map input ~f:(function
            | Diff.Lite.E.E (Best_tip_changed diff) ->
                `Fst diff
            | E (Root_transitioned diff) ->
                `Snd diff
            | diff ->
                `Trd diff )
        in
        (* We only care about the final best tip diff in the sequence, as all other best tip diffs get overwritten *)
        let final_best_tip_diff = List.last best_tip_diffs in
        (* We only care about the final root transition diff in the sequence, but we do want to retain garbage that is removed from prior root transitions. We do this by compressing all garbage into the final root transition. *)
        let final_root_transition_diff = List.last root_transition_diffs in
        let extra_garbage =
          List.drop_last root_transition_diffs
          |> Option.value ~default:[]
          |> List.bind ~f:(fun { new_root; garbage = Lite garbage; _ } ->
                 (Root_data.Limited.hashes new_root).state_hash :: garbage )
        in
        let total_root_transition_diff =
          Option.map final_root_transition_diff
            ~f:(fun ({ garbage = Lite garbage; _ } as r) ->
              { r with garbage = Lite (extra_garbage @ garbage) } )
        in
        let diffs_to_apply =
          List.concat
            [ other_diffs
            ; Option.value_map total_root_transition_diff ~default:[]
                ~f:(fun diff -> [ Diff.Lite.E.E (Root_transitioned diff) ])
            ; Option.value_map final_best_tip_diff ~default:[] ~f:(fun diff ->
                  [ Diff.Lite.E.E (Best_tip_changed diff) ] )
            ]
        in
        let apply_funcs =
          let parent_hashes =
            List.filter_map input ~f:(function
              | E (New_node (Lite transition)) ->
                  Mina_block.Validated.header transition
                  |> Header.protocol_state
                  |> Mina_state.Protocol_state.previous_state_hash
                  |> Option.some
              | _ ->
                  None )
          in
          let%map.Result old_root =
            Database.find_arcs_and_root t.db ~arcs_cache ~parent_hashes
          in
          List.map diffs_to_apply ~f:(fun (Diff.Lite.E.E diff) ->
              apply_diff ~old_root ~arcs_cache t diff )
        in
        List.iter root_transition_diffs ~f:(fun { just_emitted_a_proof; _ } ->
            if just_emitted_a_proof then (
              [%log' info t.logger] "Dequeued a snarked ledger" ;
              Persistent_root.Instance.dequeue_snarked_ledger
                t.persistent_root_instance ) ) ;
        match apply_funcs with
        | Ok fs ->
            let%map () = Scheduler.yield () in
            Database.with_batch t.db ~f:(fun batch ->
                List.iter fs ~f:(fun f -> f batch) )
        | Error (`Not_found (`Arcs h)) ->
            Deferred.return
            @@ [%log' warn t.logger]
                 "Did not add node to DB. Its $parent has already been thrown \
                  away"
                 ~metadata:
                   [ ("parent", `String (State_hash.to_base58_check h)) ]
        | Error (`Not_found `Old_root_transition) ->
            failwith "Old root transition not found"
        | Error (`Apply_diff _) ->
            failwith
              "Failed to apply a diff to the persistent transition frontier" )
end

include Worker_supervisor.Make (Worker)
