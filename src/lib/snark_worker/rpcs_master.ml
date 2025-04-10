open Async
open Core_kernel
open Signature_lib
open Snark_work_lib
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
        | Regular of
            { work_spec :
                (* TODO: in RPC master specs we shouldn't use versioned types *)
                ( Transaction_witness.Stable.Latest.t
                , Ledger_proof.t )
                Work.Single.Spec.t
                Work.Spec.t
            ; public_key : Public_key.Compressed.t
            }
        | Zkapp_command_segment of
            { id : int
            ; statement : Transaction_snark.Statement.With_sok.t
            ; witness : Zkapp_command_segment.Witness.t
            ; spec : Zkapp_command_segment.Basic.t
            }
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

    module T = struct
      type query =
        ( ( Transaction_witness.Stable.Latest.t
          , Ledger_proof.t )
          Work.Single.Spec.t
          Work.Spec.t
        , Ledger_proof.t )
        Work.Result.t

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
        Error.t
        * ( Transaction_witness.Stable.Latest.t
          , Ledger_proof.t )
          Work.Single.Spec.t
          Work.Spec.t
        * Public_key.Compressed.t

      type response = unit
    end

    module Caller = T
    module Callee = T
  end

  include Master.T
  include Versioned_rpc.Both_convert.Plain.Make (Master)
end
