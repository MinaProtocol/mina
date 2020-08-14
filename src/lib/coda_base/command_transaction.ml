open Core_kernel

module Valid = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | User_command of User_command.With_valid_signature.Stable.V1.t
        | Snapp_command of Snapp_command.Valid.Stable.V1.t
      [@@deriving sexp, compare, eq, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, eq, hash, yojson]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      | User_command of User_command.Stable.V1.t
      | Snapp_command of Snapp_command.Stable.V1.t
    [@@deriving sexp, compare, eq, hash, yojson]

    let to_latest = Fn.id
  end
end]

type t = User_command of User_command.t | Snapp_command of Snapp_command.t
[@@deriving sexp, compare, eq, hash, yojson]
