(* This is half work to be merged into a Two of type _ One_or_two.t *)

open Core_kernel
module Work = Snark_work_lib

type t =
  { which_half : [ `First | `Second ]
  ; proof : Ledger_proof.Cached.t
  ; metric : Core.Time.Span.t * [ `Merge | `Transition ]
  ; spec : Work.Selector.Single.Spec.t
  ; prover : Signature_lib.Public_key.Compressed.t
  ; common : Work.Partitioned.Spec_common.t
  }

let merge_to_one_result_exn (left : t) (right : t) : Work.Selector.Result.t =
  assert (
    List.for_all ~f:Fn.id
      [ phys_equal left.which_half `First
      ; phys_equal right.which_half `Second
      ; Signature_lib.Public_key.Compressed.equal left.prover right.prover
      ; Currency.Fee.equal left.common.fee_of_full right.common.fee_of_full
      ] ) ;
  let metrics = `Two (left.metric, right.metric) in
  { proofs = `Two (left.proof, right.proof)
  ; metrics
  ; spec =
      { instances = `Two (left.spec, right.spec)
      ; fee = left.common.fee_of_full
      }
  ; prover = left.prover
  }
