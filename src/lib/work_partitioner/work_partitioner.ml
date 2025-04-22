open Core_kernel
open Async
module Shared = Shared
module Partitioned_work = Snark_work_lib.Partitioned
module Selector_work = Snark_work_lib.Selector
module Zkapp_command_job_with_status =
  With_job_status.Make (Partitioned_work.Zkapp_command_job)

(* NOTE: this module is where the real optimization happen. One assumption we
   have is the order of merging is irrelvant to the correctness of the final
   proof. Hence we're only using a counter `merge_remaining` to track have we
   reach the final proof
*)
module Pending_Zkapp_command = struct
  type t =
    { spec : Selector_work.Single_spec.t
          (* the original work being splitted, should be identical to Work_selector.work *)
    ; unscheduled_segments : Partitioned_work.Zkapp_command_job.Spec.t Queue.t
          (* we may need to insert proofs to merge back to the queue, hence a Deque *)
    ; pending_mergable_proofs : Ledger_proof.Cached.t Deque.t
    ; mutable elapsed : Time.Stable.Span.V1.t
    ; mutable merge_remaining : int
    }

  let generate_merge ~(t : t) () =
    let try_take2 (q : 'a Deque.t) : ('a * 'a) option =
      match Deque.dequeue_front q with
      | None ->
          None
      | Some fst -> (
          match Deque.dequeue_front q with
          | Some snd ->
              Some (fst, snd)
          | None ->
              Deque.enqueue_front q fst ; None )
    in
    let open Option.Let_syntax in
    let%map proof1, proof2 = try_take2 t.pending_mergable_proofs in
    Partitioned_work.Zkapp_command_job.Spec.Merge { proof1; proof2 }

  let generate_segment ~(t : t) () =
    let open Option.Let_syntax in
    let%map segment = Queue.dequeue t.unscheduled_segments in
    segment

  let generate_job_spec (t : t) :
      Partitioned_work.Zkapp_command_job.Spec.t option =
    List.find_map ~f:(fun f -> f ()) [ generate_merge ~t; generate_segment ~t ]

  let submit_proof (t : t) ~(proof : Ledger_proof.Cached.t)
      ~(elapsed : Time.Stable.Span.V1.t) =
    Deque.enqueue_back t.pending_mergable_proofs proof ;
    t.merge_remaining <- t.merge_remaining - 1 ;
    t.elapsed <- Time.Span.(t.elapsed + elapsed)
end

module Zkapp_command_job_pool =
  Job_pool.Make (Partitioned_work.Pairing) (Pending_Zkapp_command)
module Sent_job_pool =
  Job_pool.Make
    (Partitioned_work.Zkapp_command_job.UUID)
    (Zkapp_command_job_with_status)

type t =
  { logger : Logger.t
  ; transaction_snark : (module Transaction_snark.S)
        (* WARN: we're mixing UUID for `pairing_pool` and `zkapp_command_jobs.
           Should be fine *)
  ; uuid_generator : Uuid_generator.t (* NOTE: Fields for pooling *)
  ; pairing_pool : (Partitioned_work.Pairing.UUID.t, Single_work.t) Hashtbl.t
        (* if one single work from underlying Work_selector is completed but
           not the other. throw it here. *)
  ; zkapp_command_jobs : Zkapp_command_job_pool.t
        (* NOTE: Fields for reissue pooling*)
  ; reassignment_timeout : Time.Span.t
  ; jobs_sent_by_partitioner : Sent_job_pool.t
        (* we only track tasks created by a Work_partitioner here. For reissue
           of regular jobs, we still turn to the underlying Work_selector *)
        (* WARN: we're assuming everything in this queue is sorted in time from old to new.
           So queue head is the oldest task.
        *)
  ; mutable first_in_pair : Selector_work.Single_spec.t option
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
  ; uuid_generator = Uuid_generator.create ()
  ; pairing_pool = Hashtbl.create (module Partitioned_work.Pairing.UUID)
  ; zkapp_command_jobs = Zkapp_command_job_pool.create ()
  ; reassignment_timeout
  ; jobs_sent_by_partitioner = Sent_job_pool.create ()
  ; first_in_pair = None
  }

(* Logics for work requesting *)
let reissue_old_task ~(partitioner : t) () :
    Partitioned_work.Single.Spec.t option =
  let job_is_old (job : Zkapp_command_job_with_status.t) : bool =
    Zkapp_command_job_with_status.is_old ~now:(Time.now ())
      ~limit:partitioner.reassignment_timeout job
  in
  match
    Sent_job_pool.take_first_ready ~pred:job_is_old
      partitioner.jobs_sent_by_partitioner
  with
  | None ->
      None
  | Some (id, job_with_status) ->
      let reissued = { job_with_status with assigned = Time.now () } in
      Sent_job_pool.replace ~id ~job:reissued
        partitioner.jobs_sent_by_partitioner ;
      Some (Sub_zkapp_command job_with_status.job)

let issue_from_zkapp_command_work_pool ~(partitioner : t) () :
    Partitioned_work.Single.Spec.t option =
  let open Option.Let_syntax in
  let%bind pairing_id, pending_zkapp_command =
    Zkapp_command_job_pool.peek partitioner.zkapp_command_jobs
  in
  let%map spec =
    Pending_Zkapp_command.generate_job_spec pending_zkapp_command
  in
  let job_uuid =
    Partitioned_work.Zkapp_command_job.UUID.Job_UUID
      (Uuid_generator.next_uuid partitioner.uuid_generator)
  in
  let job_with_status =
    Partitioned_work.Zkapp_command_job.{ spec; pairing_id; job_uuid }
    |> Zkapp_command_job_with_status.issue_now
  in
  Sent_job_pool.replace ~id:job_uuid ~job:job_with_status
    partitioner.jobs_sent_by_partitioner ;

  Partitioned_work.Single.Spec.Sub_zkapp_command job_with_status.job

let rec issue_from_first_in_pair ~(partitioner : t) () =
  match partitioner.first_in_pair with
  | Some work ->
      partitioner.first_in_pair <- None ;
      Some
        (convert_single_work_from_selector ~partitioner ~one_or_two:`First ~work)
  | None ->
      None

(* try to issue a single work received from the underlying Work_selector
   `one_or_two` tracks which task is it inside a `One_or_two`*)
and convert_single_work_from_selector ~(partitioner : t)
    ~(one_or_two : [ `First | `Second | `One ])
    ~(work : Selector_work.Single_spec.t) : Partitioned_work.Single.Spec.t =
  match work with
  | Transition (input, witness) as work -> (
      (* WARN: a smilar copy of this exists in `Snark_worker.Worker_impl_prod` *)
      match witness.transaction with
      | Command (Zkapp_command zkapp_command) -> (
          match
            Async.Thread_safe.block_on_async (fun () ->
                Shared.extract_zkapp_segment_works
                  ~m:partitioner.transaction_snark ~input ~witness
                  ~zkapp_command )
          with
          | Ok (Ok (_ :: _ as all)) ->
              let pairing_id =
                Partitioned_work.Pairing.
                  { one_or_two
                  ; pair_uuid =
                      Some
                        (Pairing_UUID
                           (Uuid_generator.next_uuid partitioner.uuid_generator)
                        )
                  }
              in
              let unscheduled_segments =
                all
                |> List.map ~f:(fun (witness, spec, statement) ->
                       Partitioned_work.Zkapp_command_job.Spec.Segment
                         { statement; witness; spec } )
                |> Queue.of_list
              in
              let pending_mergable_proofs = Deque.create () in
              let merge_remaining = Queue.length unscheduled_segments - 1 in
              let pending_zkapp_command =
                Pending_Zkapp_command.
                  { unscheduled_segments
                  ; pending_mergable_proofs
                  ; merge_remaining
                  ; spec = work
                  ; elapsed = Time.Span.zero
                  }
              in
              assert (
                phys_equal `Ok
                  (Zkapp_command_job_pool.attempt_add ~key:pairing_id
                     ~job:pending_zkapp_command partitioner.zkapp_command_jobs ) ) ;
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
          Regular (work, { one_or_two; pair_uuid = None }) )
  | Merge _ ->
      Regular (work, { one_or_two; pair_uuid = None })

and issue_job_from_partitioner ~(partitioner : t) () :
    Partitioned_work.Single.Spec.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ reissue_old_task ~partitioner
    ; issue_from_first_in_pair ~partitioner
    ; issue_from_zkapp_command_work_pool ~partitioner
    ]

(* WARN: this should only be called if partitioner.first_in_pair is None *)
let consume_job_from_selector ~(partitioner : t)
    ~(work : Selector_work.Single_spec.t One_or_two.t) () :
    Partitioned_work.Single.Spec.t =
  match work with
  | `One work ->
      convert_single_work_from_selector ~partitioner ~one_or_two:`One ~work
  | `Two (work_fst, work_snd) ->
      assert (phys_equal None partitioner.first_in_pair) ;
      partitioner.first_in_pair <- Some work_fst ;
      convert_single_work_from_selector ~partitioner ~one_or_two:`Second
        ~work:work_snd

let request_from_selector_and_consume_by_partitioner ~(partitioner : t)
    ~(selection_method : (module Work_selector.Selection_method_intf))
    ~(selector : Work_selector.State.t) ~(logger : Logger.t)
    ~(fee : Currency.Fee.t) ~snark_pool () =
  let (module Work_selection_method) = selection_method in
  let open Core_kernel in
  let open Option.Let_syntax in
  let%map work = Work_selection_method.work ~logger ~fee ~snark_pool selector in

  consume_job_from_selector ~partitioner ~work ()

let request_partitioned_work
    ~(selection_method : (module Work_selector.Selection_method_intf))
    ~(logger : Logger.t) ~(fee : Currency.Fee.t)
    ~(snark_pool : Work_selector.snark_pool) ~(selector : Work_selector.State.t)
    ~(partitioner : t) : Partitioned_work.Single.Spec.t option =
  List.find_map
    ~f:(fun f -> f ())
    [ issue_job_from_partitioner ~partitioner
    ; request_from_selector_and_consume_by_partitioner ~partitioner
        ~selection_method ~selector ~logger ~fee ~snark_pool
    ]

(* Logics for work submitting *)

type submit_result =
  | SchemeUnmatched
  | Processed of (Selector_work.Result.t option * [ `Ok | `Slashed ])
(* If the first `option` in Processed is present, it indicates we need to submit to the underlying selector *)

let submit_directly_to_work_selector ~(result : Partitioned_work.Result.t) () =
  match Partitioned_work.Result.to_selector_result result with
  | Some result ->
      Processed (Some result, `Ok)
  | None ->
      SchemeUnmatched

let submit_single ~partitioner ~this_single ~uuid =
  let Single_work.{ which_half; _ } = this_single in
  let result = ref None in
  Hashtbl.change partitioner.pairing_pool uuid ~f:(function
    | Some other_single ->
        let work =
          match which_half with
          | `First ->
              Single_work.merge_to_one_result_exn this_single other_single
          | `Second ->
              Single_work.merge_to_one_result_exn other_single this_single
        in

        (* For the same reason with another commented recycling, we can't.
           let (Pairing_UUID uuid) = uuid in
           UUID_generator.recycle_uuid partitioner.uuid_generator uuid ;
        *)
        result := Some work ;
        None
    | None ->
        Some this_single ) ;
  match !result with
  | Some result ->
      Processed (Some result, `Ok)
  | None ->
      SchemeUnmatched

let submit_one_in_pair_to_work_partitioner ~partitioner
    ~(result : Partitioned_work.Result.t) () =
  match result with
  (* NOTE: This is terrible, why are we designing the RPC like this?
     `proofs`, `spec.instances` and `metrics` should be merged together.
  *)
  | { proofs = `One proof
    ; spec =
        { instances =
            `One
              (Regular
                ( spec
                , { one_or_two = (`First | `Second) as which_half
                  ; pair_uuid = Some uuid
                  } ) )
        ; fee
        }
    ; metrics = `One ((_, (`Merge | `Transition)) as metric)
    ; prover
    } ->
      let this_single =
        Single_work.{ which_half; proof; metric; spec; prover; fee }
      in

      submit_single ~partitioner ~this_single ~uuid
  | _ ->
      SchemeUnmatched

let submit_into_pending_zkapp_command ~partitioner
    ~(result : Partitioned_work.Result.t) () =
  match result with
  (* NOTE: This is terrible, why are we designing the RPC like this?
     `proofs`, `spec.instances` and `metrics` should be merged together.
  *)
  | { proofs = `One proof
    ; spec =
        { instances = `One (Sub_zkapp_command { pairing_id; job_uuid; _ })
        ; fee
        }
    ; metrics = `One (elapsed, `Sub_zkapp_command _)
    ; prover
    } -> (
      match
        Sent_job_pool.slash partitioner.jobs_sent_by_partitioner job_uuid
      with
      | Some _ -> (
          (* NOTE: Only submit the proof is never seen before. *)
          (* NOTE:
             We can't recycle the UUID, however, imagine a really old job that's
             already completed by some worker A, and acknowledged by the
             coordinator. Now a really slow worker B try to that with an already
             recycled UUID, which happens to be issued for another pending work
             job the same UUID. Now our logic will misuse the proof.
             let (Job_UUID to_recycle) = job_uuid in
             UUID_generator.recycle_uuid partitioner.uuid_generator to_recycle ;
          *)
          match
            Zkapp_command_job_pool.find partitioner.zkapp_command_jobs
              pairing_id
          with
          | None ->
              printf
                "Worker submit a work that's already slashed from pending \
                 zkapp command pool, ignoring " ;
              Processed (None, `Slashed)
          | Some pending ->
              Pending_Zkapp_command.submit_proof ~proof ~elapsed pending ;
              if 0 = pending.merge_remaining then
                let final_proof =
                  Deque.dequeue_front_exn pending.pending_mergable_proofs
                in
                let Partitioned_work.Pairing.{ one_or_two; pair_uuid } =
                  pairing_id
                in
                let uuid =
                  Option.value_exn pair_uuid
                    ~message:
                      "When putting pending zkapp command into pool, we didn't \
                       assign an uuid"
                in
                let metric = (pending.elapsed, `Transition) in

                match one_or_two with
                | `One ->
                    let result : Partitioned_work.Result.t =
                      { proofs = `One final_proof
                      ; metrics = `One metric
                      ; spec =
                          { instances = `One pending.spec; fee }
                          |> Partitioned_work.Spec.of_selector_spec
                      ; prover
                      }
                    in
                    submit_directly_to_work_selector ~result ()
                | (`First | `Second) as which_half ->
                    let this_single =
                      Single_work.
                        { which_half
                        ; proof
                        ; metric
                        ; spec = pending.spec
                        ; prover
                        ; fee
                        }
                    in
                    submit_single ~partitioner ~this_single ~uuid
              else Processed (None, `Ok) )
      | None ->
          printf
            "Worker submit a work that's already slashed from sent job pool, \
             ignoring" ;
          Processed (None, `Slashed) )
  | _ ->
      SchemeUnmatched

type rpc_result = [ `SchemeUnmatched | `Ok | `Slashed ]

let submit_result_to_rpc_result : [ `Ok | `Slashed ] -> rpc_result = function
  | `Ok ->
      `Ok
  | `Slashed ->
      `Slashed

let submit_partitioned_work ~(result : Partitioned_work.Result.t) ~callback
    ~(partitioner : t) =
  (* NOTE: there's some space for optimization as the pattern matching logic is essentially repeated inside these different branches*)
  let unwrap_processed f =
    match f () with
    | Processed (to_submit, rpc_result) ->
        Some (to_submit, rpc_result |> submit_result_to_rpc_result)
    | SchemeUnmatched ->
        None
  in

  let select_work_result, rpc_result =
    List.find_map ~f:unwrap_processed
      [ submit_directly_to_work_selector ~result
      ; submit_one_in_pair_to_work_partitioner ~partitioner ~result
      ; submit_into_pending_zkapp_command ~partitioner ~result
      ]
    |> Option.value ~default:(None, `SchemeUnmatched)
  in
  ( match select_work_result with
  | Some to_submit ->
      callback to_submit
  | None ->
      () ) ;
  rpc_result
