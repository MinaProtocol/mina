(* WARN:
   This file would be rewritten finally
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
