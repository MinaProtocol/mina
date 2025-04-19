open Core_kernel

type t =
  { which_half : [ `First | `Second ]
  ; proof : Ledger_proof.Cached.t
        (* We have to use a stable type here o.w. there's type mismatch, somehow *)
  ; metric :
      Core.Time.Span.t
      * [ `Merge | `Transition | `Sub_zkapp_command of [ `Segment | `Merge ] ]
  ; spec : Work_types.Compact.Single.Spec.t
  ; prover : Signature_lib.Public_key.Compressed.t
  ; fee : Currency.Fee.t
  }

let merge_to_one_result_exn (left : t) (right : t) : Work_types.Compact.Result.t
    =
  assert (
    List.for_all ~f:Fn.id
      [ phys_equal left.which_half `First
      ; phys_equal right.which_half `Second
      ; Signature_lib.Public_key.Compressed.equal left.prover right.prover
      ; Currency.Fee.equal left.fee right.fee
      ] ) ;
  let unwrap_metric_as_old (metric_time, metric_ty) =
    match metric_ty with
    | `Merge ->
        (metric_time, `Merge)
    | `Transition ->
        (metric_time, `Transition)
    | _ ->
        failwith "Trying to merge 2 `Sub_zkapp_command into single work result"
  in
  let metrics =
    `Two (left.metric, right.metric) |> One_or_two.map ~f:unwrap_metric_as_old
  in
  { proofs = `Two (left.proof, right.proof)
  ; metrics
  ; spec = { instances = `Two (left.spec, right.spec); fee = left.fee }
  ; prover = left.prover
  }
