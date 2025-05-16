open Core_kernel

module Single = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = { which_one : [ `First | `Second | `One ]; pairing_id : int64 }
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

module Sub_zkapp = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { which_one : [ `First | `Second | `One ]
        ; pairing_id : int64
        ; job_id : int64
        }
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]

  let of_single ~(job_id : int64) Single.{ which_one; pairing_id } =
    { which_one; pairing_id; job_id }

  let to_single ({ which_one; pairing_id; _ } : t) : Single.t =
    { which_one; pairing_id }
end
