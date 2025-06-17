(* This is partial work to be combined into a Snark_work_lib.Result.Combined.t *)

(** In pairing pool, which half is this item corresponding to? *)
type half = [ `First | `Second ]

(** Which half is the work we're submitting corresponding to? Noted that it
    doesn't make sense to track a `One in the pool as that's a completed work,
    hence 2 definitions diverge. *)
type submitted_half = [ `First | `Second | `One ]

(** Items inside the pairing pool. *)
type t =
  | Spec_only of
      { spec : Snark_work_lib.Selector.Single.Spec.t One_or_two.t
      ; sok_message : Mina_base.Sok_message.t
      }
      (** We only have a spec, we need to track spec here because SNARK worker
          will not submit spec -- IDs are enough to identify them. [sok_message]
          is just a tuple of [prover] and [fee], which are shared meta for the
          one/two works *)
  | One_of_two of
      { other_spec : Snark_work_lib.Selector.Single.Spec.t
      ; sok_message : Mina_base.Sok_message.t
      ; in_pool_half : half
      ; in_pool_result : Snark_work_lib.Result.Single.t
      }
      (** In additional to spec, we have one result [in_pool_result]
      corresponding to [in_pool_half], waiting for the other half. *)

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

(** [merge_single_result t ~logger ~submitted_result ~submitted_half] attempts to combine
    what we have in pool, [t], with the incoming single result [submitted_result]
    corresponding to incoming half [submitted_half] *)
val merge_single_result :
     t
  -> logger:Logger.t
  -> submitted_result:
       (unit, Ledger_proof.Cached.t) Snark_work_lib.Result.Single.Poly.t
  -> submitted_half:submitted_half
  -> merge_outcome
