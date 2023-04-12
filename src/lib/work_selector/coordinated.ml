open Core_kernel

let coordinator_url =
  Sys.getenv_opt "MINA_SNARK_COORDINATOR_URL"
  |> Option.value ~default:"http://localhost:8080"

let query_coordinator identifiers =
  let url = String.concat ~sep:"/" [ coordinator_url; "get-job" ] in
  match
    Ezcurl.put ~url ~content:(`String (String.concat ~sep:"\n" identifiers)) ()
  with
  | Ok response ->
      Stdlib.Printf.printf "+++ querying coordinator: %s -> %d \n%!" url
        response.Ezcurl.code ;
      if response.Ezcurl.code = 201 then Some response.Ezcurl.body else None
  | Error (_curl_code, msg) ->
      Stdlib.Printf.printf "+++ querying coordinator: %s -> failed: %s \n%!" url
        msg ;
      None

module Make
    (Inputs : Intf.Inputs_intf)
    (Lib : Intf.Lib_intf with module Inputs := Inputs) =
struct
  let spec_hashes spec =
    let statement = Snark_work_lib.Work.Single.Spec.statement spec in
    let source_first =
      Mina_base.Frozen_ledger_hash.to_base58_check
        statement.source.first_pass_ledger
    in
    let source_second =
      Mina_base.Frozen_ledger_hash.to_base58_check
        statement.source.second_pass_ledger
    in
    let target_first =
      Mina_base.Frozen_ledger_hash.to_base58_check
        statement.target.first_pass_ledger
    in
    let target_second =
      Mina_base.Frozen_ledger_hash.to_base58_check
        statement.target.second_pass_ledger
    in
    source_first ^ "->" ^ target_first ^ ":" ^ source_second ^ "->"
    ^ target_second

  let work_identifier
      (work :
        ( Inputs.Transaction_witness.t
        , Inputs.Ledger_proof.t )
        Snark_work_lib.Work.Single.Spec.t
        One_or_two.t ) =
    match One_or_two.to_list work with
    | [ single ] ->
        spec_hashes single
    | [ first; second ] ->
        spec_hashes first ^ "::" ^ spec_hashes second
    | _ ->
        assert false

  let rec find_matching_job ~logger wanted_identifier identifiers jobs =
    match (identifiers, jobs) with
    | identifier :: remaining_identifiers, job :: remaining_jobs
      when String.equal identifier wanted_identifier ->
        Some (job, remaining_identifiers, remaining_jobs)
    | _ :: identifiers, _ :: jobs ->
        find_matching_job ~logger wanted_identifier identifiers jobs
    | _, _ ->
        [%log error] "Could not find job for $identifier"
          ~metadata:[ ("identifier", `String wanted_identifier) ] ;
        None

  let get_work_from_coordinator ~logger identifiers expensive_work
      (state : Lib.State.t) =
    query_coordinator identifiers
    |> Option.bind ~f:(fun identifier ->
           find_matching_job ~logger identifier identifiers expensive_work )
    |> Option.map ~f:(fun (x, remaining_identifiers, remaining_jobs) ->
           Lib.State.set state x ;
           (Some x, remaining_jobs, remaining_identifiers) )
    |> Option.value ~default:(None, [], [])

  let work_uncached ~snark_pool ~fee ~logger (state : Lib.State.t) =
    Lib.State.remove_old_assignments state ~logger ;
    let unseen_jobs = Lib.State.all_unseen_works state in
    match Lib.get_expensive_work ~snark_pool ~fee unseen_jobs with
    | [] ->
        (None, [], [])
    | expensive_work ->
        let identifiers = List.map ~f:work_identifier expensive_work in
        get_work_from_coordinator ~logger identifiers expensive_work state

  let work =
    let result_cache = ref ([], []) in
    let cached_at = ref 0.0 in
    fun ~snark_pool ~fee ~logger (state : Lib.State.t) ->
      let now = Core.Unix.gettimeofday () in
      (* only recompute list every few seconds to avoid stalling the scheduler *)
      if Float.(now - !cached_at > 6.0) then (
        cached_at := now ;
        let work_opt, expensive_work, identifiers =
          work_uncached ~snark_pool ~fee ~logger state
        in
        result_cache := (expensive_work, identifiers) ;
        work_opt )
      else
        let expensive_work, identifiers = !result_cache in
        let work_opt, expensive_work, identifiers =
          get_work_from_coordinator ~logger identifiers expensive_work state
        in
        result_cache := (expensive_work, identifiers) ;
        work_opt

  let remove = Lib.State.remove

  let pending_work_statements = Lib.pending_work_statements
end
