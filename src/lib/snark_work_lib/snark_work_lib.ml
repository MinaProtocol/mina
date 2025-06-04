(* WARN:
   This file would be rewritten finally
*)
module Work = struct
  include Work
  module Result_without_metrics = Result_without_metrics
end

module Selector = Selector

module Result = struct
  module Single = Single_result
  module Combined = Combined_result
end

module With_job_meta = With_job_meta

module Spec = struct
  module Single = Single_spec
  module Sub_zkapp = Sub_zkapp_spec
end

module Id = struct
  module Single = Id.Single
end
