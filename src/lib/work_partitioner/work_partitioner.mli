open Core_kernel

module Snark_worker_shared : module type of Snark_worker_shared

type t

val create : reassignment_timeout:Time.Span.t -> logger:Logger.t -> t

type work_from_selector =
  unit -> Snark_work_lib.Spec.Single.t One_or_two.t option

val request_partitioned_work :
     sok_message:Mina_base.Sok_message.t
  -> work_from_selector:work_from_selector
  -> partitioner:t
  -> Snark_work_lib.Spec.Partitioned.t option

val submit_partitioned_work :
     result:Snark_work_lib.Result.Partitioned.t
  -> callback:(Snark_work_lib.Result.Combined.t -> unit)
  -> partitioner:t
  -> [> `Ok | `SchemeUnmatched | `Slashed ]
