(* This is partial work to be combined into a Snark_work_lib.Result.Combined.t *)

(** In pairing pool, which half is this item corresponding to? *)
type half = [ `First | `Second ]

(** Which half is the work we're submitting corresponding to? Noted that it
    doesn't make sense to track a `One in the pool as that's a completed work,
    hence 2 definitions diverge. *)
type submitted_half = [ `First | `Second | `One ]

type t

val of_spec :
     sok_message:Mina_base.Sok_message.t
  -> Snark_work_lib.Spec.Single.t One_or_two.t
  -> t

(** The result of calling [merge_single_result] *)
type merge_outcome =
  | Pending of t  (** The result is not completed *)
  | Done of Snark_work_lib.Result.Combined.t
      (** [Done r] indicates that the result [r] is completed, and we should
          submit it to the work selector. *)
  | HalfAlreadyInPool
      (** submitted work doesn't match what we have in pool. It happens when the
          submitting half is the same as the half in pool *)
  | StructureMismatch of
      { spec : Snark_work_lib.Selector.Single.Spec.t One_or_two.t }
      (** submitted work is doesn't match the spec, it happens when submitting a
          `One to a `Two spec, or `First/`Second to a `On spec *)

(** [merge_single_result ~submitted_result ~submitted_half t] attempts 
    to combine what we have in pool, [t], with the incoming single result 
    [submitted_result] corresponding to incoming half [submitted_half] *)
val merge_single_result :
     submitted_result:(unit, Ledger_proof.t) Snark_work_lib.Result.Single.Poly.t
  -> submitted_half:submitted_half
  -> t
  -> merge_outcome
