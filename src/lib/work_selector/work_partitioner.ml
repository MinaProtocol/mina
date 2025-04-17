(* work partitioner split the work produced by a Work_selector into smaller tasks,
   and issue them to the actual worker. It's also in charge of aggregating
   the response from worker. We have this layer because we don't want to
   touch the Work_selector and break the GraphQL API.

   Ideally, we should refactor so this integrates into Work_selector
*)

open Core_kernel
open Transaction_snark

module Job_UUID = struct
  (* this identifies a single `zkapp_command_work` *)
  type t = Job_UUID of int [@@deriving compare, hash, sexp]
end

module Pair_UUID = struct
  (* this identifies a One_or_two work from Work_selector's perspective *)
  type t = Pair_UUID of int [@@deriving compare, hash, sexp]
end

module Zkapp_command_work_spec = struct
  type t =
    | Zkapp_command_segment of
        { statement : Transaction_snark.Statement.With_sok.t
        ; witness : Zkapp_command_segment.Witness.t
        ; spec : Zkapp_command_segment.Basic.t
        }
    | Zkapp_command_merge of
        { proof1 : Ledger_proof.t; proof2 : Ledger_proof.t }
end

(* This ID identifies a single work in Work_selector's perspective *)
module Pairing_id = struct
  (* Case `One` indicate no need to pair. This is needed because zkapp command
     might be left in pool of half completion. *)
  type t = { direction : [ `First | `Second | `One ]; pair_uuid : Pair_UUID.t }
  [@@deriving compare, hash, sexp]
end

module Zkapp_command_work = struct
  type t =
    { spec : Zkapp_command_work_spec.t
    ; pairing_uuid : Pairing_id.t
    ; job_uuid : Job_UUID.t
    }
end

(* result from Work_partitioner *)
module Partitioned_work = struct
  type t =
    | Regular of
        ( Transaction_witness.t
        , Ledger_proof.t )
        Snark_work_lib.Work.Single.Spec.t
    | Zkapp_command of Zkapp_command_work.t
end

(* A single work in Work_selector's perspective *)
module Single_work_with_data = struct
  type t =
    { which_half : [ `First | `Second ]
    ; proof : Ledger_proof.t
    ; metric : Core.Time.Span.t
    ; spec :
        ( Transaction_witness.t
        , Ledger_proof.t )
        Snark_work_lib.Work.Single.Spec.t
    ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
    }
end

module Zkapp_command_work_in_queue = struct
  type t =
    { work : Zkapp_command_work.t
    ; status : Work_lib.Job_status.t
    ; is_done : bool ref
    }

  let wrap_as_partitioned_work : t -> Partitioned_work.t =
   fun _ -> failwith "TODO"
end

module Pending_Zkapp_command = struct
  type t =
    { unscheduled : Zkapp_command_work.t Queue.t
    ; pending_mergable_proofs : Ledger_proof.t Queue.t
    }
end

module State = struct
  type t =
    { reassignment_wait : int
    ; logger : Logger.t
    ; transaction_snark : (module Transaction_snark.S)
          (* if one single work from underlying Work_selector is completed but
             not the other. throw it here. *)
    ; pairing_pool : (Pair_UUID.t, Single_work_with_data.t) Hashtbl.t
    ; zkapp_command_work_pool :
        (Pairing_id.t, Pending_Zkapp_command.t) Hashtbl.t
          (* we only track tasks created by a Work_partitioner here. For reissue
             of regular jobs, we still turn to the underlying Work_selector *)
          (* WARN: we're assuming everything in this queue is sorted in time from old to new.
             So queue head is the oldest task.
          *)
    ; sent_jobs_partitioner : Zkapp_command_work_in_queue.t Queue.t
          (* we mark completed tasks in this hash table instead of crossing off
             the queue `sent_jobs_partitioner`. Hence no need to iterate through
             it. *)
    ; completion_markers : (Job_UUID.t, bool ref) Hashtbl.t
          (* When receving a `Two works from the underlying Work_selector, store one of them here,
             so we could issue them to another worker.
          *)
    ; mutable pair_left : Work_lib.work option
          (* WARN: we're mixing UUID for segments and pairs. Should be fine *)
    ; reusable_uuids : int Queue.t
    ; mutable uuid_generator : int
    }

  let init (reassignment_wait : int) (logger : Logger.t) : t =
    let module M = Transaction_snark.Make (struct
      let constraint_constants = Genesis_constants.Compiled.constraint_constants

      let proof_level = Genesis_constants.Compiled.proof_level
    end) in
    { pairing_pool = Hashtbl.create (module Pair_UUID)
    ; zkapp_command_work_pool = Hashtbl.create (module Pairing_id)
    ; reassignment_wait
    ; logger
    ; sent_jobs_partitioner = Queue.create ()
    ; completion_markers = Hashtbl.create (module Job_UUID)
    ; pair_left = None
    ; reusable_uuids = Queue.create ()
    ; uuid_generator = 0
    ; transaction_snark = (module M)
    }
end

let next_uuid (s : State.t) : int =
  match Queue.dequeue s.reusable_uuids with
  | Some uuid ->
      uuid
  | None ->
      s.uuid_generator <- s.uuid_generator + 1 ;
      s.uuid_generator

(* Try to issue a work from states tracked inside the partitioner, this
   won't query the already issued work and attempt to reissue them.
   Because we'll do that in `reissue_old_task` instead
*)
let rec issue_work_from_partitioner ~(partitioner : State.t) :
    Partitioned_work.t option =
  match partitioner.pair_left with
  | Some work ->
      partitioner.pair_left <- None ;
      Some
        (issue_work_from_selector ~partitioner ~sok_digest ~direction:`First
           ~work )

(* try to issue a work by consulting the underlying Work_selector
   direction tracks which task is this inside a `One_or_two`*)
and issue_work_from_selector ~(partitioner : State.t) ~sok_digest
    ~(direction : [ `First | `Second | `One ]) ~(work : Work_lib.work) :
    Partitioned_work.t =
  match work with
  | Snark_work_lib.Work.Single.Spec.Transition (input, witness) as work -> (
      (* WARN: a smilar copy of this exists in `Snark_worker.Worker_impl_prod` *)
      match
        Mina_transaction.Transaction.read_all_proofs_from_disk
          witness.transaction
      with
      (* let sok_digest = Mina_base.Sok_message.digest message in *)

      (* ~message:(Mina_base.Sok_message.create ~fee ~prover:public_key) *)
      | Command (Zkapp_command zkapp_command) -> (
          match
            Async.Thread_safe.block_on_async (fun () ->
                Shared.extract_zkapp_segment_works partitioner.transaction_snark
                  input witness zkapp_command )
          with
          | Ok (Ok (_ :: _ as all)) ->
              let pairing_uuid =
                Pairing_id.
                  { direction; pair_uuid = Pair_UUID (next_uuid partitioner) }
              in
              let unscheduled =
                all
                |> List.map ~f:(fun (witness, spec, stmt) ->
                       Zkapp_command_work.
                         { pairing_uuid
                         ; job_uuid = Job_UUID (next_uuid partitioner)
                         ; spec =
                             Zkapp_command_segment
                               { statement = { stmt with sok_digest }
                               ; witness
                               ; spec
                               }
                         } )
                |> Queue.of_list
              in
              let pending_mergable_proofs = Queue.create () in
              let pending_zkapp_command =
                Pending_Zkapp_command.{ unscheduled; pending_mergable_proofs }
              in
              assert (
                phys_equal
                  (Hashtbl.add ~key:pairing_uuid ~data:pending_zkapp_command
                     partitioner.zkapp_command_work_pool )
                  `Ok ) ;
              issue_work_from_partitioner ~partitioner
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
          Regular work )
  | Merge _ ->
      Regular work

let reissue_old_task (s : State.t) : Partitioned_work.t option =
  let slashing_finished_task = ref true in
  let result = ref None in
  while !slashing_finished_task do
    match Queue.peek s.sent_jobs_partitioner with
    | Some { is_done; work = { job_uuid = Job_UUID uuid; _ }; _ } when !is_done
      ->
        Queue.enqueue s.reusable_uuids uuid ;
        (* clearing jobs done *)
        ignore
          ( Queue.dequeue_exn s.sent_jobs_partitioner
            : Zkapp_command_work_in_queue.t )
    | Some { is_done; status; _ }
      when (not !is_done)
           && Work_lib.Job_status.is_old ~now:(Time.now ())
                ~reassignment_wait:s.reassignment_wait status ->
        (* figured out task to reissue *)
        result := Queue.dequeue s.sent_jobs_partitioner ;
        slashing_finished_task := false
    | Some _ | None ->
        (* nothing has timeout so don't reissue *)
        slashing_finished_task := false
  done ;

  let open Option.Let_syntax in
  let%map ({ work; _ } as job) = !result in
  let reissued = { job with status = Assigned (Time.now ()) } in
  Queue.enqueue s.sent_jobs_partitioner reissued ;
  Partitioned_work.Zkapp_command work
