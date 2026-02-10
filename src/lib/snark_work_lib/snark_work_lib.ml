(** snark_work_lib - Types for SNARK work distribution

    This library defines the contract between the coordinator (block producer)
    and SNARK workers. It specifies what work needs to be done and what results
    are returned.

    Main components:
    - [Work]: Polymorphic spec and result types with fee and batching info
    - [Spec]: Job specifications sent to workers
    - [Result]: Proofs and metadata returned by workers
    - [Id]: Job identifiers for tracking
    - [Selector]: Concretized types for RPC communication
*)

module Work = struct
  include Work
  module Result_without_metrics = Result_without_metrics
end

module Selector = Selector
module Id = Id
module With_job_meta = With_job_meta

module Result = struct
  module Single = Single_result
  module Combined = Combined_result
  module Partitioned = Partitioned_result
end

module Spec = struct
  module Single = Single_spec
  module Sub_zkapp = Sub_zkapp_spec
  module Partitioned = Partitioned_spec
end

module Metrics = Metrics
