module ID = ID

module Spec = struct
  module Sub_zkapp = Zkapp_command_job
  module Single = Single_spec
  include Work_spec
end

module Result = struct
  module Partitioned = Partitioned_result
  module Single = Single_result
  module Combined = Combined_result
end

module Metrics = Metrics
