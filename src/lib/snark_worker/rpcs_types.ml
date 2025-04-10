open Core_kernel
open Signature_lib
module Work = Snark_work_lib.Work
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

module Regular_work = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { work_spec : Concrete_work.Spec.Stable.V1.t
        ; public_key : Public_key.Compressed.Stable.V1.t
        }

      let to_latest = Fn.id
    end
  end]
end

module Zkapp_command_segment_work = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { id : int
        ; statement : Transaction_snark.Statement.With_sok.Stable.V2.t
        ; witness : Zkapp_command_segment.Witness.Stable.V1.t
        ; spec : Zkapp_command_segment.Basic.Stable.V1.t
        }

      let to_latest = Fn.id
    end
  end]
end

module Failed_work = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Regular of Regular_work.Stable.V1.t
        | Zkapp_command_segment of Zkapp_command_segment_work.Stable.V1.t

      let to_latest = Fn.id
    end
  end]
end
