(* NOTE: Assumption: order of merging segments satisfy associativity. *)

open Core_kernel
open Mina_stdlib
open Snark_work_lib
module Range = Id.Range.Stable.Latest
module RangeMap = Map.Make (Range)

type segment_input = Spec.Sub_zkapp.SegmentSpec.Stable.Latest.t

type parent_ptr = { node : pending_node ref; index : int }

and pending_node =
  { parent_ptr : parent_ptr option
  ; range : Range.t
  ; merge_inputs : Ledger_proof.t option Array.t
  }

type ready_node =
  { parent_ptr : parent_ptr option
        (** None is for corner case where a pending zkApp command contains only a segment *)
  ; range : Range.t
  ; spec : Spec.Sub_zkapp.Stable.Latest.t
  }

type t =
  { job : (Spec.Single.t, Id.Single.t) With_job_meta.t
        (** the original work being split, contains `Work_selector.work` with
            some metadata. *)
  ; ready_spec_queue : ready_node Queue.t
        (** Specs that are ready to be sent to SNARK worker, we keep this buffer
            so the logic of submitting proofs and consuming specs could be 
            decoupled. *)
  ; mutable ready_specs_sent : ready_node RangeMap.t
        (** Specs that are sent to the worker, we keep this map so on receiving 
            a proof, we know which parent node to query, filling in proof and 
            potentially generating new specs. *)
  ; mutable elapsed : Time.Stable.Span.V1.t
        (** The total work time for all SNARK workers combined to prove this
            specific zkapp command. I.e. the time it would take a single SNARK
            worker to generate the final proof of this command. *)
  ; mutable final_proof : Ledger_proof.t option
  }

(* build a tree of sub-zkApp level jobs *)
let rec divide_spec_to_subzkapp_level parent_ptr first_id
    (segments : segment_input Nonempty_list.t) work_queue =
  let range =
    Range.
      { first = first_id; last = first_id + Nonempty_list.length segments - 1 }
  in
  match Nonempty_list.uncons segments with
  | seg, [] ->
      Queue.enqueue work_queue
        { parent_ptr; range; spec = Spec.Sub_zkapp.Stable.Latest.Segment seg }
  | seg_first, seg_rest -> (
      let half_len = (List.length seg_rest + 1) / 2 in
      let seg_rest_left, seg_rest_right =
        List.split_n seg_rest (half_len - 1)
      in
      match Nonempty_list.of_list_opt seg_rest_right with
      | None ->
          let this = { parent_ptr; range; merge_inputs = [| None |] } in
          divide_spec_to_subzkapp_level
            (Some { node = ref this; index = 0 })
            first_id
            (Nonempty_list.init seg_first seg_rest_left)
            work_queue
      | Some seg_rest_right ->
          let this = { parent_ptr; range; merge_inputs = [| None; None |] } in
          divide_spec_to_subzkapp_level
            (Some { node = ref this; index = 0 })
            first_id
            (Nonempty_list.init seg_first seg_rest_left)
            work_queue ;
          divide_spec_to_subzkapp_level
            (Some { node = ref this; index = 1 })
            (first_id + List.length seg_rest_left)
            seg_rest_right work_queue )

let create_and_yield_segment ~job
    ~(unscheduled_segments : segment_input Nonempty_list.t) =
  let ready_spec_queue = Queue.create () in
  divide_spec_to_subzkapp_level None 1 unscheduled_segments ready_spec_queue ;
  let ({ range = first_range; spec = first_spec; _ } as ready_node) =
    Queue.dequeue ready_spec_queue
    |> Option.value_exn
         ~message:"Reaching unreachable code, input has at least 1 segment!"
  in
  assert (Range.(equal first_range { first = 1; last = 1 })) ;
  let t =
    { job
    ; ready_spec_queue
    ; ready_specs_sent = RangeMap.singleton first_range ready_node
    ; elapsed = Time.Span.zero
    ; final_proof = None
    }
  in
  (t, first_spec, first_range)

let zkapp_job t = t.job

let next_subzkapp_job_spec (t : t) :
    (Spec.Sub_zkapp.Stable.Latest.t * Range.t) option =
  let%map.Option ({ range; spec; _ } as ready_node) =
    Queue.dequeue t.ready_spec_queue
  in
  t.ready_specs_sent <-
    RangeMap.add_exn ~key:range ~data:ready_node t.ready_specs_sent ;
  (spec, range)

let submit_proof ~(proof : Ledger_proof.t) ~(elapsed : Time.Stable.Span.V1.t)
    ~range (t : t) =
  match RangeMap.find t.ready_specs_sent range with
  | None ->
      Error (`No_such_range range)
  | Some pending -> (
      t.elapsed <- Time.Span.(t.elapsed + elapsed) ;
      t.ready_specs_sent <- RangeMap.remove t.ready_specs_sent range ;
      match pending.parent_ptr with
      | None ->
          t.final_proof <- Some proof ;
          Ok ()
      | Some { node = parent; index } ->
          let { parent_ptr; range; merge_inputs } = !parent in
          merge_inputs.(index) <- Some proof ;
          let proof_inputs = Queue.create () in
          if
            merge_inputs
            |> Array.fold_until ~init:true
                 ~f:(fun _ this_proof ->
                   match this_proof with
                   | None ->
                       Stop false
                   | Some proof ->
                       Queue.enqueue proof_inputs proof ;
                       Continue true )
                 ~finish:Fn.id
          then
            match proof_inputs |> Queue.to_list with
            | [ proof1; proof2 ] ->
                Queue.enqueue t.ready_spec_queue
                  { parent_ptr
                  ; range
                  ; spec = Spec.Sub_zkapp.Stable.Latest.Merge { proof1; proof2 }
                  } ;
                Ok ()
            | _ ->
                failwith
                  "Incorrect number of input proofs provided to a subzkapp \
                   proof, this is means the implementation of \
                   Pending_zkapp_command is buggy"
          else Ok () )

let try_finalize (t : t) =
  let%map.Option proof = t.final_proof in
  (t.job, proof, t.elapsed)
