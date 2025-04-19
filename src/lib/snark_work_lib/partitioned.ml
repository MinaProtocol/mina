open Core_kernel

(* A `Pairing.t` identifies a single work in Work_selector's perspective *)
module Pairing = struct
  module UUID = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        (* this identifies a One_or_two work from Work_selector's perspective *)
        type t = Pairing_UUID of int
        [@@deriving compare, hash, sexp, yojson, equal]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      (* Case `One` indicate no need to pair. This is needed because zkapp command
         might be left in pool of half completion. *)
      type t =
        { one_or_two : [ `First | `Second | `One ]
        ; pair_uuid : UUID.Stable.V1.t option
        }
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

module Zkapp_command_job = struct
  (* This identifies a single `Zkapp_command_job.t` *)
  module UUID = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Job_UUID of int [@@deriving compare, hash, sexp, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Spec = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type t =
          | Segment of
              { statement : Transaction_snark.Statement.With_sok.Stable.V2.t
              ; witness :
                  Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t
              ; spec : Transaction_snark.Zkapp_command_segment.Basic.Stable.V1.t
              }
          | Merge of
              { proof1 : Ledger_proof.Stable.V2.t
              ; proof2 : Ledger_proof.Stable.V2.t
              }
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { spec : Spec.Stable.V1.t
        ; pairing_id : Pairing.Stable.V1.t
        ; job_uuid : UUID.Stable.V1.t
        }
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]
end
