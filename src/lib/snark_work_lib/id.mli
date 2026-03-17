(** Job identifiers for tracking SNARK work.

    Jobs are paired (one or two per work unit). Each job has a pairing_id
    and a position indicator ([`First], [`Second], or [`One] if unpaired).
*)

open Core_kernel

(** Identifies one part of a One_or_two work unit. *)
module Single : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      (** Case `One` indicate no need to pair. ID is still needed because zkapp command
         might be left in pool of half completion. *)
      type t = { which_one : [ `First | `Second | `One ]; pairing_id : int64 }
      [@@deriving compare, hash, sexp, yojson, equal]

      val to_latest : t -> t
    end
  end]
end

module Range : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = { first : int; last : int }
      [@@deriving compare, hash, sexp, equal, yojson]

      val is_consecutive : t -> t -> bool

      val to_latest : t -> t
    end
  end]
end

(** Identifies a sub-zkApp level work unit with a range of account updates. *)
module Sub_zkapp : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      (** Case `One` indicate no need to pair. ID is still needed because zkapp command
         might be left in pool of half completion. *)
      type t =
        { which_one : [ `First | `Second | `One ]
        ; pairing_id : int64
        ; range : Range.Stable.V1.t
        }
      [@@deriving compare, hash, sexp, yojson, equal]

      val to_latest : t -> t
    end
  end]

  (** Create a Sub_zkapp ID from a Single ID with a range. *)
  val of_single : range:Range.t -> Single.t -> t

  (** Extract the Single ID portion, discarding the range. *)
  val to_single : t -> Single.t
end

module Any : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        | Single of Single.Stable.V1.t
        | Sub_zkapp of Sub_zkapp.Stable.V1.t
      [@@deriving compare, hash, sexp, yojson, equal]

      val to_latest : t -> t
    end
  end]
end
