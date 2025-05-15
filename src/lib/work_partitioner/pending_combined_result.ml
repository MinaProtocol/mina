(* This is half work to be merged into a Two of type _ One_or_two.t *)

open Core_kernel
module Work = Snark_work_lib

type half = [ `First | `Second ] [@@deriving equal]

type submitted_half = [ `First | `Second | `One ] [@@deriving equal]

type t =
  { single_result : (Work.Result.Single.t * half) option
  ; fee_of_full : Currency.Fee.t
  }

type merge_outcome =
  | Pending of t
  | Done of Work.Result.Combined.t
  | HalfMismatch of { submitted : submitted_half; in_pool : half }

let merge_single_result (in_pool : t) ~(submitted_result : Work.Result.Single.t)
    ~(submitted_half : submitted_half) : merge_outcome =
  let { single_result; fee_of_full } = in_pool in
  match single_result with
  | None -> (
      match submitted_half with
      | `One ->
          Done { data = `One submitted_result; fee = fee_of_full }
      | (`First | `Second) as submitted_half ->
          Pending
            { in_pool with
              single_result = Some (submitted_result, submitted_half)
            } )
  | Some (in_pool_result, in_pool_half) -> (
      match submitted_half with
      | `One ->
          HalfMismatch { submitted = submitted_half; in_pool = in_pool_half }
      | (`First | `Second) as submitted_half ->
          assert (not (equal_half in_pool_half submitted_half)) ;
          let results =
            match submitted_half with
            | `First ->
                (submitted_result, in_pool_result)
            | `Second ->
                (in_pool_result, submitted_result)
          in
          Done { data = `Two results; fee = fee_of_full } )
