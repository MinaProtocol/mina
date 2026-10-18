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

module Range = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = { first : int; last : int }
      [@@deriving hash, sexp, equal, yojson]

      let compare { first = first_left; _ } { first = first_right; _ } =
        compare first_left first_right

      let is_consecutive { last = last_left; _ } { first = first_right; _ } =
        succ last_left = first_right

      let to_latest = Fn.id
    end
  end]

  let compare = Stable.Latest.compare
end

module Sub_zkapp = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { which_one : [ `First | `Second | `One ]
        ; pairing_id : int64
        ; range : Range.Stable.V1.t
        }
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]

  let of_single ~(range : Range.t) Single.{ which_one; pairing_id } =
    { which_one; pairing_id; range }

  let to_single ({ which_one; pairing_id; _ } : t) : Single.t =
    { which_one; pairing_id }
end

module Any = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Single of Single.Stable.V1.t
        | Sub_zkapp of Sub_zkapp.Stable.V1.t
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end
