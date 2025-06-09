open Core_kernel
module Snark_worker_shared = Snark_worker_shared

type t

val create : reassignment_timeout:Time.Span.t -> logger:Logger.t -> t

type work_from_selector =
  Snark_work_lib.Spec.Single.t One_or_two.t option Lazy.t

val request_partitioned_work :
     sok_message:Mina_base.Sok_message.t
  -> work_from_selector:work_from_selector
  -> partitioner:t
  -> Snark_work_lib.Spec.Partitioned.Stable.V1.t Or_error.t option
