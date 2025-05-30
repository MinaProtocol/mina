(* WARN:
   This file would be rewritten finally
*)
module Work = struct
  include Work
  module Result_without_metrics = Result_without_metrics
end

module Selector = Selector
module With_job_meta = With_job_meta

module Spec = struct
  module Single = Single_spec
end
