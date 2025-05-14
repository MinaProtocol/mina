(* This is half work to be merged into a Two of type _ One_or_two.t *)

open Core_kernel
module Work = Snark_work_lib

type half = [ `First | `Second ] [@@deriving equal]

type t =
  { which_half : half
  ; single_result : Work.Result.Single.t
  ; prover : Signature_lib.Public_key.Compressed.t
  ; fee_of_full : Currency.Fee.t
  }

let merge_to_one_result_exn (in_pool : t) (submitted : Work.Result.Single.t)
    (submitted_half : half) : Work.Result.Combined.t =
  let { which_half = in_pool_half
      ; single_result = in_pool_result
      ; prover
      ; fee_of_full
      } =
    in_pool
  in
  assert (not (equal_half in_pool_half submitted_half)) ;

  let results =
    match submitted_half with
    | `First ->
        (submitted, in_pool_result)
    | `Second ->
        (in_pool_result, submitted)
  in
  { data = `Two results; fee = fee_of_full; prover }
