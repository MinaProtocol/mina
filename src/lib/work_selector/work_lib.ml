open Core_kernel
open Currency
open Async
open Mina_base

module Make (Inputs : Intf.Inputs_intf) = struct
  module Work_spec = Snark_work_lib.Work.Single.Spec

  module Job_status = struct
    type t = Assigned of Time.t

    let is_old (Assigned at_time) ~now ~reassignment_wait =
      let max_age = Time.Span.of_ms (Float.of_int reassignment_wait) in
      let delta = Time.diff now at_time in
      Time.Span.( > ) delta max_age
  end

  module State = struct
    module Seen_key = struct
      module T = struct
        type t = Transaction_snark.Statement.t One_or_two.t
        [@@deriving compare, sexp, to_yojson, hash]
      end

      include T
      include Comparable.Make (T)
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

      let find_vk_by_account_id_hash (t : t) account_id vk_hash =
        match Hashtbl.find t.account_id_to_vks account_id with
        | None ->
            None
        | Some vks ->
            Map.keys vks
            |> List.filter_map ~f:(fun vk_hash' ->
                   if Zkapp_basic.F.equal vk_hash vk_hash' then
                     find_vk t vk_hash
                   else None )
            |> List.hd |> Option.map ~f:snd

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

      let lift (t : t) table_modify (cmd : Inputs.Transaction.t) =
        Inputs.Transaction.extract_vks cmd
        |> List.iter ~f:(fun (account_id, vk) -> table_modify t ~account_id ~vk)

      (*let lift (t : t) table_modify (cmd : Inputs.Transaction.t) =
          With_status.data cmd |> User_command.forget_check
          |> lift_common t table_modify

        let lift_hashed (t : t) table_modify cmd =
          Transaction_hash.User_command_with_valid_signature.forget_check cmd
          |> With_hash.data |> lift_common t table_modify*)
    end

    type t =
      { mutable available_jobs :
          ( Inputs.Transaction_witness_with_vk_map.t
          , Inputs.Ledger_proof.t )
          Work_spec.t
          One_or_two.t
          list
      ; mutable jobs_seen : Job_status.t Seen_key.Map.t
      ; reassignment_wait : int
      ; verification_key_table : Vk_refcount_table.t
      }

    let add_verification_keys_from_work_pairs t
        (work_pairs :
          (Inputs.Transaction_witness.t, Inputs.Ledger_proof.t) Work_spec.t
          One_or_two.t
          list ) =
      List.iter work_pairs ~f:(fun work_pair ->
          One_or_two.iter work_pair ~f:(fun work ->
              match work with
              | Merge _ ->
                  ()
              | Transition (_stmt, witness) ->
                  Vk_refcount_table.lift t.verification_key_table
                    Vk_refcount_table.inc
                    (Inputs.Transaction_witness.transaction witness) ) ) ;
      List.map work_pairs ~f:(fun work_pair ->
          One_or_two.map work_pair ~f:(fun work ->
              match work with
              | Transition (stmt, witness) ->
                  let proof_vk_hashes =
                    Inputs.Transaction_witness.transaction witness
                    |> Inputs.Transaction.extract_proof_vk_hashes
                  in
                  let aid_vk_map = Account_id.Map.empty in
                  let aid_vk_map =
                    List.fold ~init:aid_vk_map proof_vk_hashes
                      ~f:(fun acc (aid, vk_hash) ->
                        match
                          ( Vk_refcount_table.find_vk_by_account_id_hash
                              t.verification_key_table aid vk_hash
                          , Account_id.Map.find acc aid )
                        with
                        | Some vk, Some vks ->
                            let vks' =
                              Zkapp_basic.F_map.Map.update vks vk_hash
                                ~f:(fun _ -> vk)
                            in
                            Account_id.Map.set acc ~key:aid ~data:vks'
                        | Some vk, None ->
                            Account_id.Map.set acc ~key:aid
                              ~data:
                                (Zkapp_basic.F_map.Map.of_alist_exn
                                   [ (vk_hash, vk) ] )
                        | _ ->
                            acc )
                  in
                  Work_spec.Transition
                    ( stmt
                    , Inputs.Transaction_witness_with_vk_map.
                        { witness
                        ; vk_map =
                            Account_id.Map.fold ~init:[]
                              ~f:(fun ~key:aid ~data:vk_map acc ->
                                (aid, Zkapp_basic.F_map.Map.data vk_map) :: acc
                                )
                              aid_vk_map
                        } )
              | Merge _ as a ->
                  a ) )

    (*TODO: dec ref count and remove entries*)
    let init :
           reassignment_wait:int
        -> frontier_broadcast_pipe:
             Inputs.Transition_frontier.t option
             Pipe_lib.Broadcast_pipe.Reader.t
        -> logger:Logger.t
        -> t =
     fun ~reassignment_wait ~frontier_broadcast_pipe ~logger ->
      let t =
        { available_jobs = []
        ; jobs_seen = Seen_key.Map.empty
        ; reassignment_wait
        ; verification_key_table = Vk_refcount_table.create ()
        }
      in
      Pipe_lib.Broadcast_pipe.Reader.iter frontier_broadcast_pipe
        ~f:(fun frontier_opt ->
          ( match frontier_opt with
          | None ->
              [%log debug] "No frontier, setting available work to be empty" ;
              t.available_jobs <- []
          | Some frontier ->
              Pipe_lib.Broadcast_pipe.Reader.iter
                (Inputs.Transition_frontier.best_tip_pipe frontier) ~f:(fun _ ->
                  let best_tip_staged_ledger =
                    Inputs.Transition_frontier.best_tip_staged_ledger frontier
                  in
                  let start_time = Time.now () in
                  ( match
                      Inputs.Staged_ledger.all_work_pairs best_tip_staged_ledger
                        ~get_state:
                          (Inputs.Transition_frontier.get_protocol_state
                             frontier )
                    with
                  | Error e ->
                      [%log fatal]
                        "Error occured when updating available work: $error"
                        ~metadata:[ ("error", Error_json.error_to_yojson e) ]
                  | Ok new_available_jobs ->
                      let end_time = Time.now () in
                      [%log info] "Updating new available work took $time ms"
                        ~metadata:
                          [ ( "time"
                            , `Float
                                ( Time.diff end_time start_time
                                |> Time.Span.to_ms ) )
                          ] ;
                      let new_available_jobs =
                        add_verification_keys_from_work_pairs t
                          new_available_jobs
                      in
                      t.available_jobs <- new_available_jobs ) ;
                  Deferred.unit )
              |> Deferred.don't_wait_for ) ;
          Deferred.unit )
      |> Deferred.don't_wait_for ;
      t

    let all_unseen_works t =
      O1trace.sync_thread "work_lib_all_unseen_works" (fun () ->
          List.filter t.available_jobs ~f:(fun js ->
              not
              @@ Map.mem t.jobs_seen (One_or_two.map ~f:Work_spec.statement js) ) )

    let remove_old_assignments t ~logger =
      O1trace.sync_thread "work_lib_remove_old_assignments" (fun () ->
          let now = Time.now () in
          t.jobs_seen <-
            Map.filteri t.jobs_seen ~f:(fun ~key:work ~data:status ->
                if
                  Job_status.is_old status ~now
                    ~reassignment_wait:t.reassignment_wait
                then (
                  [%log info]
                    ~metadata:[ ("work", Seen_key.to_yojson work) ]
                    "Waited too long to get work for $work. Ready to be \
                     reassigned" ;
                  Mina_metrics.(
                    Counter.inc_one Snark_work.snark_work_timed_out_rpc) ;
                  false )
                else true ) )

    let remove t x =
      t.jobs_seen <-
        Map.remove t.jobs_seen (One_or_two.map ~f:Work_spec.statement x)

    let set t x =
      t.jobs_seen <-
        Map.set t.jobs_seen
          ~key:(One_or_two.map ~f:Work_spec.statement x)
          ~data:(Job_status.Assigned (Time.now ()))
  end

  let does_not_have_better_fee ~snark_pool ~fee
      (statements : Inputs.Transaction_snark_work.Statement.t) : bool =
    Option.value_map ~default:true
      (Inputs.Snark_pool.get_completed_work snark_pool statements)
      ~f:(fun priced_proof ->
        let competing_fee = Inputs.Transaction_snark_work.fee priced_proof in
        Fee.compare fee competing_fee < 0 )

  module For_tests = struct
    let does_not_have_better_fee = does_not_have_better_fee
  end

  let get_expensive_work ~snark_pool ~fee
      (jobs : ('a, 'b) Work_spec.t One_or_two.t list) :
      ('a, 'b) Work_spec.t One_or_two.t list =
    O1trace.sync_thread "work_lib_get_expensive_work" (fun () ->
        List.filter jobs ~f:(fun job ->
            does_not_have_better_fee ~snark_pool ~fee
              (One_or_two.map job ~f:Work_spec.statement) ) )

  let all_pending_work ~snark_pool statements =
    List.filter statements ~f:(fun st ->
        Option.is_none (Inputs.Snark_pool.get_completed_work snark_pool st) )

  (*Seen/Unseen jobs that are not in the snark pool yet*)
  let pending_work_statements ~snark_pool ~fee_opt (state : State.t) =
    let all_todo_statements =
      List.map state.available_jobs ~f:(One_or_two.map ~f:Work_spec.statement)
    in
    let expensive_work statements ~fee =
      List.filter statements ~f:(does_not_have_better_fee ~snark_pool ~fee)
    in
    match fee_opt with
    | None ->
        all_pending_work ~snark_pool all_todo_statements
    | Some fee ->
        expensive_work all_todo_statements ~fee
end
