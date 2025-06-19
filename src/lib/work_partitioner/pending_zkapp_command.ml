(* NOTE: Assumption: order of merging segments satisfy associativity. *)

open Core_kernel
open Snark_work_lib

open struct
  module Range = Spec.Sub_zkapp.Range
  module RangeMap = Map.Make (Range)
end

type t =
  { job : (Spec.Single.t, Id.Single.t) With_job_meta.t
        (** the original work being split, contains `Work_selector.work` with
            some metadata. *)
  ; unscheduled_segments : Spec.Sub_zkapp.Stable.Latest.t Queue.t
  ; mutable pending_mergeable_proofs : Ledger_proof.t RangeMap.t
        (* we may need to insert proofs to merge back to the queue, hence a Deque
         *)
  ; mutable elapsed : Time.Stable.Span.V1.t
        (** The total work time for all SNARK workers combined to prove this
            specific zkapp command. I.e. the time it would take a single SNARK
            worker to generate the final proof of this command. *)
  ; mutable proofs_in_flight : int
        (** The number of proofs we need to wait for before being sure we could
            continue with the only proof contained in [pending_mergeable_proofs]
            as the final proof, provided [unscheduled_segments] being empty. *)
  }

let create_and_yield_segment ~job
    ~(unscheduled_segments :
       Spec.Sub_zkapp.Stable.Latest.t Mina_stdlib.Nonempty_list.t ) =
  let first_segment, unscheduled_segments =
    Mina_stdlib.Nonempty_list.uncons unscheduled_segments
  in
  ( { job
    ; unscheduled_segments = Queue.of_list unscheduled_segments
    ; pending_mergeable_proofs = RangeMap.empty
    ; elapsed = Time.Span.zero
    ; proofs_in_flight = 1
    }
  , first_segment )

let zkapp_job t = t.job

(** [next_merge t] attempts dequeuing 2 proofs from [t.pending_mergeable_proofs]
    corresponding to consecutive states and generate a sub-zkapp level spec
    merging them together. *)
let next_merge (t : t) =
  let last_element = ref None in
  RangeMap.to_sequence ~order:`Increasing_key t.pending_mergeable_proofs
  |> Sequence.fold_until ~init:None ~finish:Fn.id
       ~f:(fun
            _
            ((Range.{ last = last_segment_of_proof2; _ } as this_range), proof2)
          ->
         match !last_element with
         | Some
             ( (Range.{ first = first_segment_of_proof1; _ } as last_range)
             , proof1 )
           when Range.is_consecutive last_range this_range ->
             t.proofs_in_flight <- t.proofs_in_flight + 1 ;
             t.pending_mergeable_proofs <-
               RangeMap.remove
                 (RangeMap.remove t.pending_mergeable_proofs last_range)
                 this_range ;
             Stop
               (Some
                  (Spec.Sub_zkapp.Stable.Latest.Merge
                     { proof1
                     ; proof2
                     ; first_segment_of_proof1
                     ; last_segment_of_proof2
                     } ) )
         | _ ->
             last_element := Some (this_range, proof2) ;
             Continue None )

(** [next_segment t] dequeus a segment from [t.unscheduled_segments] and generate a
   sub-zkapp level spec proving that segment. *)
let next_segment (t : t) =
  let open Option.Let_syntax in
  let%map segment = Queue.dequeue t.unscheduled_segments in
  t.proofs_in_flight <- t.proofs_in_flight + 1 ;
  segment

let next_subzkapp_job_spec (t : t) : Spec.Sub_zkapp.Stable.Latest.t option =
  match next_merge t with Some _ as ret -> ret | None -> next_segment t

let submit_proof (t : t) ~(proof : Ledger_proof.t)
    ~(elapsed : Time.Stable.Span.V1.t) ~range:(Range.{ first; last } as range) =
  let should_accept =
    first <= last
    && RangeMap.closest_key t.pending_mergeable_proofs `Greater_or_equal_to
         Range.{ first = last; last }
       |> Option.map ~f:(fun (Range.{ first = next_first; _ }, _) ->
              last < next_first )
       |> Option.value ~default:true
    && RangeMap.closest_key t.pending_mergeable_proofs `Less_or_equal_to
         Range.{ first; last = first }
       |> Option.map ~f:(fun (Range.{ last = previous_last; _ }, _) ->
              previous_last < first )
       |> Option.value ~default:true
  in
  if should_accept then (
    t.pending_mergeable_proofs <-
      RangeMap.add_exn ~key:range ~data:proof t.pending_mergeable_proofs ;
    t.proofs_in_flight <- t.proofs_in_flight - 1 ;
    t.elapsed <- Time.Span.(t.elapsed + elapsed) ;
    Ok () )
  else
    let msg =
      Printf.sprintf
        "Pending zkapp command has a submission of range [%d, %d], that \
         doesn't fit"
        first last
    in
    Error (Error.of_string msg)

let try_finalize (t : t) =
  if
    t.proofs_in_flight = 0
    && Queue.is_empty t.unscheduled_segments
    && RangeMap.length t.pending_mergeable_proofs = 1
  then
    Some
      ( t.job
      , RangeMap.min_elt_exn t.pending_mergeable_proofs |> Tuple2.get2
      , t.elapsed )
  else None
