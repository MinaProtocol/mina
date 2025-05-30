open Core_kernel
module Snark_worker_shared = Snark_worker_shared
module Work = Snark_work_lib
module Zkapp_command_job_pool =
  Job_pool.Make (Work.ID.Single) (Pending_zkapp_command)
module Sent_zkapp_job_pool =
  Job_pool.Make (Work.ID.Sub_zkapp) (Work.Spec.Sub_zkapp.Stable.Latest)
module Sent_single_job_pool =
  Job_pool.Make (Work.ID.Single) (Work.Spec.Single.Stable.Latest)

let proof_cache_db = Proof_cache_tag.create_identity_db ()

type t =
  { logger : Logger.t
  ; transaction_snark : (module Transaction_snark.S)
        (* WARN: we're mixing ID for `pairing_pool` and `zkapp_command_jobs.
           Should be fine *)
  ; id_generator : Id_generator.t (* NOTE: Fields for pooling *)
  ; pairing_pool : (int64, Pending_combined_result.t) Hashtbl.t
        (* if one single work from underlying Work_selector is completed but
           not the other. throw it here. *)
  ; zkapp_command_jobs : Zkapp_command_job_pool.t
        (* NOTE: Fields for reissue pooling*)
  ; reassignment_timeout : Time.Span.t
  ; zkapp_jobs_sent_by_partitioner : Sent_zkapp_job_pool.t
  ; single_jobs_sent_by_partitioner : Sent_single_job_pool.t
        (* NOTE: we're assuming everything in this queue is sorted in time from old to new.
           So queue head is the oldest task.
        *)
  ; mutable tmp_slot :
      (Work.Spec.Single.t * Work.ID.Single.t * Mina_base.Sok_message.t) option
        (* When receving a `Two works from the underlying Work_selector, store one of them here,
           so we could issue them to another worker.
        *)
  }

let create ~(reassignment_timeout : Time.Span.t) ~(logger : Logger.t) : t =
  let module M = Transaction_snark.Make (struct
    let constraint_constants = Genesis_constants.Compiled.constraint_constants

    let proof_level = Genesis_constants.Compiled.proof_level
  end) in
  { logger
  ; transaction_snark = (module M)
  ; id_generator = Id_generator.create ~logger
  ; pairing_pool = Hashtbl.create (module Int64)
  ; zkapp_command_jobs = Zkapp_command_job_pool.create ()
  ; reassignment_timeout
  ; zkapp_jobs_sent_by_partitioner = Sent_zkapp_job_pool.create ()
  ; single_jobs_sent_by_partitioner = Sent_single_job_pool.create ()
  ; tmp_slot = None
  }

let epoch_now () = Time.(now () |> to_span_since_epoch)

(* Logics for work requesting *)
let reissue_old_zkapp_job ~(partitioner : t) () :
    Work.Spec.Partitioned.Stable.Latest.t option =
  let%map.Option job =
    Sent_zkapp_job_pool.reissue_if_old
      partitioner.zkapp_jobs_sent_by_partitioner
      ~reassignment_timeout:partitioner.reassignment_timeout
  in
  Work.Spec.Partitioned.Poly.Sub_zkapp_command { job; data = () }

let reissue_old_single_job ~(partitioner : t) () :
    Work.Spec.Partitioned.Stable.Latest.t option =
  let%map.Option job =
    Sent_single_job_pool.reissue_if_old
      partitioner.single_jobs_sent_by_partitioner
      ~reassignment_timeout:partitioner.reassignment_timeout
  in
  Work.Spec.Partitioned.Poly.Single { job; data = () }

let issue_from_zkapp_command_work_pool ~(partitioner : t) () :
    Work.Spec.Partitioned.Stable.Latest.t option =
  let open Option.Let_syntax in
  let attempt_issue_from_pending
      ({ spec = pending; job_id = zkapp_id; sok_message; _ } :
        Zkapp_command_job_pool.job ) =
    let%map spec = Pending_zkapp_command.generate_job_spec pending in
    let job_id =
      Work.ID.Sub_zkapp.of_single
        ~job_id:(Id_generator.next_id partitioner.id_generator ())
        zkapp_id
    in
    let job =
      Work.With_status.
        { spec; job_id; issued_since_unix_epoch = epoch_now (); sok_message }
    in
    Sent_zkapp_job_pool.replace ~id:job_id ~job
      partitioner.zkapp_jobs_sent_by_partitioner ;

    Work.Spec.Partitioned.Poly.Sub_zkapp_command { job; data = () }
  in

  Zkapp_command_job_pool.fold_until ~init:None
    ~f:(fun _ job ->
      match attempt_issue_from_pending job with
      | None ->
          { slashed = false; action = `Continue None }
      | Some spec ->
          { slashed = false; action = `Stop (Some spec) } )
    ~finish:Fn.id partitioner.zkapp_command_jobs

let rec issue_from_tmp_slot ~(partitioner : t) () =
  match partitioner.tmp_slot with
  | Some spec ->
      partitioner.tmp_slot <- None ;
      let single_spec, pairing, sok_message = spec in
      Some
        (convert_single_work_from_selector ~partitioner ~single_spec ~pairing
           ~sok_message )
  | None ->
      None

(* try to issue a single work received from the underlying Work_selector
   `one_or_two` tracks which task is it inside a `One_or_two`*)
and convert_single_work_from_selector ~(partitioner : t) ~single_spec
    ~sok_message ~pairing : Work.Spec.Partitioned.Stable.Latest.t =
  let job =
    Work.With_status.
      { spec = single_spec
      ; job_id = pairing
      ; issued_since_unix_epoch = epoch_now ()
      ; sok_message
      }
  in
  match single_spec with
  | Transition (input, witness) -> (
      match witness.transaction with
      | Command (Zkapp_command zkapp_command) -> (
          match
            Async.Thread_safe.block_on_async (fun () ->
                let witness =
                  Transaction_witness.read_all_proofs_from_disk witness
                in
                Snark_worker_shared.extract_zkapp_segment_works
                  ~m:partitioner.transaction_snark ~input ~witness
                  ~zkapp_command )
          with
          | Ok (Ok (_ :: _ as all)) ->
              let unscheduled_segments =
                all
                |> List.map ~f:(fun (witness, spec, statement) ->
                       Work.Spec.Sub_zkapp.Segment { statement; witness; spec }
                       |> Work.Spec.Sub_zkapp.read_all_proofs_from_disk )
                |> Queue.of_list
              in
              let pending_mergable_proofs = Deque.create () in
              let merge_remaining = Queue.length unscheduled_segments - 1 in
              let pending_zkapp_command =
                Pending_zkapp_command.
                  { unscheduled_segments
                  ; pending_mergable_proofs
                  ; merge_remaining
                  ; job
                  ; elapsed = Time.Span.zero
                  }
              in
              let pending_zkapp_command_job =
                Work.With_status.
                  { spec = pending_zkapp_command
                  ; job_id = pairing
                  ; issued_since_unix_epoch = epoch_now ()
                  ; sok_message
                  }
              in
              assert (
                phys_equal `Ok
                  (Zkapp_command_job_pool.attempt_add ~key:pairing
                     ~job:pending_zkapp_command_job
                     partitioner.zkapp_command_jobs ) ) ;
              issue_job_from_partitioner ~partitioner ()
              |> Option.value_exn
                   ~message:
                     "FATAL: we already inserted work into partitioner so this \
                      shouldn't happen"
          | Ok (Ok []) ->
              failwith "No witness generated"
          | Ok (Error e) ->
              failwith (Error.to_string_hum e)
          | Error e ->
              failwith (Exn.to_string e) )
      | Command (Signed_command _) | Fee_transfer _ | Coinbase _ ->
          let job =
            Work.With_status.map
              ~f_spec:Work.Spec.Single.read_all_proofs_from_disk job
          in
          Single { job; data = () } )
  | Merge _ ->
      let job =
        Work.With_status.map ~f_spec:Work.Spec.Single.read_all_proofs_from_disk
          job
      in
      Single { job; data = () }

and issue_job_from_partitioner ~(partitioner : t) () :
    Work.Spec.Partitioned.Stable.Latest.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ reissue_old_zkapp_job ~partitioner
    ; reissue_old_single_job ~partitioner
    ; issue_from_zkapp_command_work_pool ~partitioner
    ; issue_from_tmp_slot ~partitioner
    ]

(* WARN: this should only be called if partitioner.first_in_pair is None *)
let consume_job_from_selector ~(partitioner : t)
    ~(sok_message : Mina_base.Sok_message.t)
    ~(instances : Work.Spec.Single.t One_or_two.t) () :
    Work.Spec.Partitioned.Stable.Latest.t =
  let pairing_id = Id_generator.next_id partitioner.id_generator () in
  Hashtbl.add_exn partitioner.pairing_pool ~key:pairing_id
    ~data:(Spec_only { spec = instances; sok_message }) ;

  match instances with
  | `One single_spec ->
      let pairing : Work.ID.Single.t = { which_one = `One; pairing_id } in
      convert_single_work_from_selector ~partitioner ~single_spec ~pairing
        ~sok_message
  | `Two (spec1, spec2) ->
      assert (phys_equal None partitioner.tmp_slot) ;
      let pairing1 : Work.ID.Single.t = { which_one = `First; pairing_id } in
      let pairing2 : Work.ID.Single.t = { which_one = `Second; pairing_id } in
      partitioner.tmp_slot <- Some (spec1, pairing1, sok_message) ;
      convert_single_work_from_selector ~partitioner ~single_spec:spec2
        ~sok_message ~pairing:pairing2

type work_from_selector = unit -> Work.Spec.Single.t One_or_two.t option

let request_from_selector_and_consume_by_partitioner ~(partitioner : t)
    ~(work_from_selector : work_from_selector)
    ~(sok_message : Mina_base.Sok_message.t) () =
  let open Core_kernel in
  let open Option.Let_syntax in
  let%map instances = work_from_selector () in

  consume_job_from_selector ~partitioner ~instances ~sok_message ()

let request_partitioned_work ~(sok_message : Mina_base.Sok_message.t)
    ~(work_from_selector : work_from_selector) ~(partitioner : t) :
    Work.Spec.Partitioned.Stable.Latest.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ issue_job_from_partitioner ~partitioner
    ; request_from_selector_and_consume_by_partitioner ~partitioner
        ~work_from_selector ~sok_message
    ]

(* Logics for work submitting *)

type submit_result =
  | SchemeUnmatched
  | Slashed
  | Processed of Work.Result.Combined.t option
(* If the `option` in Processed is present, it indicates we need to submit to the underlying selector *)

let submit_single ~partitioner
    ~(submitted_result : (unit, Ledger_proof.t) Work.Result.Single.Poly.t)
    ~(submitted_half : [ `One | `First | `Second ]) ~id =
  let result = ref SchemeUnmatched in
  Hashtbl.change partitioner.pairing_pool id ~f:(function
    | Some pending_combined_result -> (
        let submitted_result =
          Snark_work_lib.Result.Single.Poly.map ~f_spec:Fn.id
            ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db)
            submitted_result
        in
        match
          Pending_combined_result.merge_single_result pending_combined_result
            ~submitted_result ~submitted_half
        with
        | Pending pending ->
            result := Processed None ;
            Some pending
        | Done combined ->
            result := Processed (Some combined) ;
            None
        | HalfMismatch _ | NoSuchHalf _ ->
            result := SchemeUnmatched ;
            Some pending_combined_result )
    | None ->
        (* We should always at least having a OnlyMeta, this would be SchemeUnmatched indeed *)
        None ) ;
  !result

let submit_into_pending_zkapp_command ~partitioner
    ~(job_id : Work.ID.Sub_zkapp.t)
    ~data:
      ({ proof; data = elapsed } :
        (Core.Time.Span.t, Ledger_proof.t) Proof_carrying_data.t ) =
  let returns = ref SchemeUnmatched in
  let process (pending : Pending_zkapp_command.t) =
    Pending_zkapp_command.submit_proof ~proof ~elapsed pending ;

    if 0 = pending.merge_remaining then
      let final_proof =
        Deque.dequeue_front_exn pending.pending_mergable_proofs
      in
      let submitted_result : (unit, Ledger_proof.t) Work.Result.Single.Poly.t =
        Work.Result.Single.Poly.{ spec = (); proof = final_proof; elapsed }
      in

      let Work.ID.Single.{ which_one; pairing_id } = pending.job.job_id in

      returns :=
        submit_single ~partitioner ~submitted_result ~submitted_half:which_one
          ~id:pairing_id
    else returns := Processed None
  in
  let slash_or_process :
      Sent_zkapp_job_pool.job option -> Sent_zkapp_job_pool.job option =
    function
    | None ->
        printf
          "Worker submit a work that's already slashed from sent job pool, \
           meaning it's completed, ignoring" ;
        returns := Slashed ;
        None
    | Some _ -> (
        let single_id = Work.ID.Sub_zkapp.to_single job_id in
        match
          Zkapp_command_job_pool.find partitioner.zkapp_command_jobs single_id
        with
        | None ->
            printf
              "Worker submit a work that's already slashed from pending zkapp \
               command pool, meaning it's completed, ignoring " ;
            returns := Slashed ;
            None
        | Some pending ->
            process pending.spec ; None )
  in

  Sent_zkapp_job_pool.change ~id:job_id ~f:slash_or_process
    partitioner.zkapp_jobs_sent_by_partitioner ;
  !returns

let submit_partitioned_work ~(result : Work.Result.Partitioned.Stable.Latest.t)
    ~(callback : Work.Result.Combined.t -> unit) ~(partitioner : t) =
  let rpc_result =
    match result with
    | Work.Spec.Partitioned.Poly.Single
        { job = Work.With_status.{ job_id; spec; _ }
        ; data = { proof; data = elapsed }
        } ->
        let Work.ID.Single.{ which_one = submitted_half; pairing_id = id } =
          job_id
        in
        let submitted_result =
          Work.Result.Single.Poly.{ spec; proof; elapsed }
        in
        submit_single ~partitioner ~submitted_result ~submitted_half ~id
    | Work.Spec.Partitioned.Poly.Sub_zkapp_command
        { job = Work.With_status.{ job_id; _ }; data } ->
        submit_into_pending_zkapp_command ~partitioner ~job_id ~data
  in
  match rpc_result with
  | SchemeUnmatched ->
      `SchemeUnmatched
  | Slashed ->
      `Slashed
  | Processed (Some result) ->
      callback result ; `Ok
  | Processed None ->
      `Ok
