open Core_kernel

(* a signature *)
module type Some_intf = sig
  type t = Quux | Zzz [@@deriving bin_io, version]
end

module M0 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int [@@deriving yojson]

      let to_latest = Fn.id
    end
  end]
end

module M1 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* refers to versioned type *)
      type t = M0.Stable.V1.t [@@deriving yojson]

      let to_latest = Fn.id
    end
  end]
end

module M3 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* tuple of versioned types *)
      type t = M0.Stable.V1.t * M1.Stable.V1.t

      let to_latest = Fn.id [@@deriving yojson]
    end
  end]
end

module M4 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* record of versioned types *)
      type t = { one : M0.Stable.V1.t; two : M1.Stable.V1.t }
      [@@deriving yojson]

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = int [@@deriving yojson, bin_io, version, sexp]

    let to_latest = Fn.id
  end
end]

(* type constructors *)
module M5 = struct
  [%%versioned
  module Stable = struct
    module V5 = struct
      type t = (Stable.V1.t array array[@sexp.opaque]) [@@deriving sexp]

      let to_latest = Fn.id
    end

    module V4 = struct
      type t = (Stable.V1.t option[@sexp.opaque]) [@@deriving sexp]

      let to_latest _ = [||]
    end

    module V3 = struct
      type t = Stable.V1.t ref [@@deriving yojson]

      let to_latest _ = [||]
    end

    module V2 = struct
      type t = Stable.V1.t list [@@deriving yojson]

      let to_latest _ = [||]
    end

    module V1 = struct
      type t = Stable.V1.t option [@@deriving yojson]

      let to_latest _ = [||]
    end
  end]
end

module type Intf = sig
  type t = Int.t [@@deriving version]
end

(* recursive type *)
module M6 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Leaf | Node of t * t [@@deriving yojson]

      let to_latest = Fn.id
    end
  end]
end

(* type with parameters *)
module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('a, 'b) t = Poly of 'a * 'b [@@deriving yojson]
    end
  end]
end

module M7 = struct
  module M = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = (string, int) Poly.Stable.V1.t [@@deriving yojson]

        let to_latest = Fn.id
      end
    end]
  end
end

(* assert versionedness *)
module M8 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = ((Int.t[@version_asserted]) List.t[@version_asserted])

      let to_latest = Fn.id
    end
  end]
end

(* int32 *)
module M9 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int32

      let to_latest = Fn.id
    end
  end]
end

(* int64 *)
module M10 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int64

      let to_latest = Fn.id
    end
  end]
end

(* bytes *)
module M11 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = bytes

      let to_latest = Fn.id
    end
  end]
end

(* Jane Street trustlisting *)
module M12 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int Core_kernel.Queue.Stable.V1.t

      let to_latest = Fn.id
    end
  end]
end

(* Jane Street special case *)
module M13 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Core_kernel.Time.Stable.Span.V1.t [@@deriving bin_io, version]

      let to_latest = Fn.id
    end
  end]
end
