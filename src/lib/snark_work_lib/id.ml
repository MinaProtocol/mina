open Core_kernel

(* A Pairing.Single.t identifies one part of a One_or_two work *)
module Single = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* Case `One` indicate no need to pair. ID is still needed because zkapp command
         might be left in pool of half completion. *)
      type t = { which_one : [ `First | `Second | `One ]; pairing_id : int64 }
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

(* A Pairing.Sub_zkapp.t identifies a sub-zkapp level work *)
module Sub_zkapp = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* Case `One` indicate no need to pair. ID is still needed because zkapp command
         might be left in pool of half completion. *)
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
end
