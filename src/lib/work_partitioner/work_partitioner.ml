module Snark_worker_shared = Snark_worker_shared
module Work = Snark_work_lib
module Zkapp_command_job_with_status =
  With_job_status.Make (Work.Partitioned.Zkapp_command_job)
module Zkapp_command_job_pool =
  Job_pool.Make (Work.Partitioned.Pairing) (Pending_zkapp_command)
module Sent_job_pool =
  Job_pool.Make
    (Work.Partitioned.Zkapp_command_job.ID)
    (Zkapp_command_job_with_status)
