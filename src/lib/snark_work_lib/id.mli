open Core_kernel

(* A Single.t identifies one part of a One_or_two work *)
module Single : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      (* Case `One` indicate no need to pair. ID is still needed because zkapp command
         might be left in pool of half completion. *)
      type t = { which_one : [ `First | `Second | `One ]; pairing_id : int64 }
      [@@deriving compare, hash, sexp, yojson, equal]

      val to_latest : t -> t
    end
  end]
end

(* A Sub_zkapp.t identifies a sub-zkapp level work *)
module Sub_zkapp : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      (* Case `One` indicate no need to pair. ID is still needed because zkapp command
         might be left in pool of half completion. *)
      type t =
        { which_one : [ `First | `Second | `One ]
        ; pairing_id : int64
        ; job_id : int64
        }
      [@@deriving compare, hash, sexp, yojson, equal]

      val to_latest : t -> t
    end
  end]

  val of_single : job_id:int64 -> Single.t -> t

  val to_single : t -> Single.t
end
