open Core_kernel

let coordinator_url =
  Sys.getenv_opt "MINA_SNARK_COORDINATOR_URL"
  |> Option.value ~default:"http://localhost:8080"

let query_coordinator identifier =
  let url =
    String.concat ~sep:"/" [ coordinator_url; "lock-job"; identifier ]
  in
  match Ezcurl.put ~url ~content:(`String "") () with
  | Ok response ->
      Stdlib.Printf.printf "+++ querying coordinator: %s -> %d \n%!" url
        response.Ezcurl.code ;
      response.Ezcurl.code = 201
  | Error (_curl_code, msg) ->
      Stdlib.Printf.printf "+++ querying coordinator: %s -> failed: %s \n%!" url
        msg ;
      false

module Make
    (Inputs : Intf.Inputs_intf)
    (Lib : Intf.Lib_intf with module Inputs := Inputs) =
struct
  let spec_hashes spec =
    let statement = Snark_work_lib.Work.Single.Spec.statement spec in
    (* TODO: take into account all pass hashes here  *)
    let source =
      Mina_base.Frozen_ledger_hash.to_base58_check
        statement.source.first_pass_ledger
    in
    let target =
      Mina_base.Frozen_ledger_hash.to_base58_check
        statement.target.second_pass_ledger
    in
    source ^ ":" ^ target

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

  let rec get_next_coordinated_job = function
    | [] ->
        None
    | work :: rest ->
        if
          query_coordinator
            ( work_identifier
            @@ Inputs.Transaction_snark_work.With_hash.data work )
        then Some work
        else get_next_coordinated_job rest

  let work ~snark_pool ~fee ~logger (state : Lib.State.t) =
    Lib.State.remove_old_assignments state ~logger ;
    let unseen_jobs = Lib.State.all_unseen_works state ~logger in
    match Lib.get_expensive_work ~snark_pool ~fee unseen_jobs with
    | [] ->
        None
    | expensive_work ->
        Option.map (get_next_coordinated_job expensive_work) ~f:(fun x ->
            Lib.State.set state x ; x )

  let remove = Lib.State.remove

  let pending_work_statements = Lib.pending_work_statements
end
