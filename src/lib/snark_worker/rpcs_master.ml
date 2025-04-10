open Async
open Core_kernel
open Rpcs_types
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

module Get_work = struct
  module Master = struct
    let name = "get_work"

    module T = struct
      (* NOTE: we have to let server to know the version, so we don't issue a
         `Zkapp_command_segment` to the client if it's old; On the other hand,
         if the server old and client being new, we can just preserve the old
         logic dealing with whole zkapp command in the client.
         We could imagine this query being telling the server what capability the client snark worker have
      *)
      type query = V2 | V3

      type response =
        | Regular of Regular_work.t
        | Zkapp_command_segment of Zkapp_command_segment_work.t
        | Nothing
    end

    module Caller = T
    module Callee = T
  end

  include Master.T
  include Versioned_rpc.Both_convert.Plain.Make (Master)
end

module Submit_work = struct
  module Master = struct
    let name = "submit_work"

    (* NOTE: Here if the submitted work is a completed zkapp command segment, it
       means the coordinator must have capablity to handle them, since the
       coordinator issues the task.
    *)
    module T = struct
      type query =
        | Regular of Concrete_work.Result.t
        | Zkapp_command_segment of
            Ledger_proof.t Work.Result_zkapp_command_segment.t

      type response = unit
    end

    module Caller = T
    module Callee = T
  end

  include Master.T
  include Versioned_rpc.Both_convert.Plain.Make (Master)
end

module Failed_to_generate_snark = struct
  module Master = struct
    let name = "failed_to_generate_snark"

    module T = struct
      type query = { error : Error.t; failed_work : Failed_work.t }

      type response = unit
    end

    module Caller = T
    module Callee = T
  end

  include Master.T
  include Versioned_rpc.Both_convert.Plain.Make (Master)
end
