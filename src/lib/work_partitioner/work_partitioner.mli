open Core_kernel
module Snark_worker_shared = Snark_worker_shared

(** [t] is type of a instance of a Work Partitioner, sitting between a Work
    Selector and the RPC endpoints. It has 2 main responsibility:
      - Partition works received from Work Selector, so SNARK workers could
        process them under the new RPC protocl;
      - Combine partitoned works so Work Selector could accept them;

    [t] holds several pools:
      - [single_jobs_sent_by_partitioner] holds already scheduled single jobs,
        where a single job is a [Snark_work_lib.Spec.Single.t] with some
        metadata;
      - [zkapp_jobs_sent_by_partitioner] holds already scheduled subzkapp jobs,
        where a subzkapp job is a [Snark_work_lib.Spec.Sub_zkapp.t] with some
        metadata;
      - [pending_zkapp_commands] holds [Pending_zkapp_command.t], where each of them
        could generate several [Snark_work_lib.Spec.Sub_zkapp.t];
      - [tmp_slot] holds a single spec received from Work Selector that is
        unprocessed yet. It's here so we could simplify the implementation;
      *)

type t

val create : reassignment_timeout:Time.Span.t -> logger:Logger.t -> t

type work_from_selector =
  Snark_work_lib.Spec.Single.t One_or_two.t option Lazy.t

(** [request_partitioned_work ~sok_message ~work_from_selector ~partitioner]
    returns a partitioned job from [partitioner], if we there exist one.

    [sok_message] is a pair of (prover, fee). These are the metadatas needed for
    SNARK worker to generate a proof. In additional, the fee would be used to
    filter out expensive works.

    [work_from_selector] is a lazy that is only forced if the partitioner can't
    schedule a job from its internal state. More generally, work partitioner
    schedule jobs in the following priority order:
      - reschedule of old subzkapp-level jobs
      - reschedule of old single jobs
      - schedule subzkapp-level spec from a pending zkapp command
      - schedule from tmp slot

    This function would throw an error, when trying to splitting a zkapp command
    with [Snark_worker_shared.extract_zkapp_segment_works]. That function throws
    error when the underlying [Transaction_snark.zkapp_command_witnesses_exn]
    throws.
*)
val request_partitioned_work :
     sok_message:Mina_base.Sok_message.t
  -> work_from_selector:work_from_selector
  -> partitioner:t
  -> Snark_work_lib.Spec.Partitioned.Stable.V1.t Or_error.t option
