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
    | identifier :: _, job :: _ when String.equal identifier wanted_identifier
      ->
        Some job
    | _ :: identifiers, _ :: jobs ->
        find_matching_job ~logger wanted_identifier identifiers jobs
    | _, _ ->
        [%log error] "Could not find job for $identifier"
          ~metadata:[ ("identifier", `String wanted_identifier) ] ;
        None

  let work ~snark_pool ~fee ~logger (state : Lib.State.t) =
    Lib.State.remove_old_assignments state ~logger ;
    let unseen_jobs = Lib.State.all_unseen_works state in
    match Lib.get_expensive_work ~snark_pool ~fee unseen_jobs with
    | [] ->
        None
    | expensive_work ->
        let identifiers = List.map ~f:work_identifier expensive_work in
        query_coordinator identifiers
        |> Option.bind ~f:(fun identifier ->
               find_matching_job ~logger identifier identifiers expensive_work )
        |> Option.map ~f:(fun x -> Lib.State.set state x ; x)

  let remove = Lib.State.remove

  let pending_work_statements = Lib.pending_work_statements
end
