open Core_kernel

(** A Single.t identifies one part of a One_or_two work *)
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

(** A Sub_zkapp.t identifies a sub-zkapp level work *)
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

  val of_single : range:Range.t -> Single.t -> t

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
