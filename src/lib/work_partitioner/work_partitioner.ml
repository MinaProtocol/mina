module Shared = Shared
module Partitioned_work = Snark_work_lib.Partitioned
module Zkapp_command_job_with_status =
  With_job_status.Make (Partitioned_work.Zkapp_command_job)
