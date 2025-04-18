open Async
open Signature_lib
module Wire_work = Snark_work_lib.Wire
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
      type query = [ `V2 | `V3 ]

      type response = (Wire_work.Spec.t * Public_key.Compressed.t) option
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
      type query = Wire_work.Result.t

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
      type query =
        Bounded_types.Wrapped_error.t
        * Wire_work.Spec.t
        * Public_key.Compressed.t

      type response = unit
    end

    module Caller = T
    module Callee = T
  end

  include Master.T
  include Versioned_rpc.Both_convert.Plain.Make (Master)
end
