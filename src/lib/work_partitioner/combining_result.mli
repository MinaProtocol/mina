(* This is partial work to be combined into a Snark_work_lib.Result.Combined.t *)

open Core_kernel

type half = [ `First | `Second ] [@@deriving equal]

type submitted_half = [ `First | `Second | `One ]

type t =
  | Spec_only of
      { spec : Snark_work_lib.Selector.Single.Spec.t One_or_two.t
      ; sok_message : Mina_base.Sok_message.t
      }
  | One_of_two of
      { other_spec : Snark_work_lib.Selector.Single.Spec.t
      ; sok_message : Mina_base.Sok_message.t
      ; in_pool_half : half
      ; in_pool_result : Snark_work_lib.Result.Single.t
      }

type merge_outcome =
  | Pending of t
  | Done of Snark_work_lib.Result.Combined.t
  | HalfMismatch of { submitted_half : submitted_half; in_pool : half }
  | NoSuchHalf of
      { submitted_half : submitted_half
      ; spec : Snark_work_lib.Selector.Single.Spec.t One_or_two.t
      }

val merge_single_result :
     t
  -> submitted_result:
       (unit, Ledger_proof.Cached.t) Snark_work_lib.Result.Single.Poly.t
  -> submitted_half:submitted_half
  -> merge_outcome
