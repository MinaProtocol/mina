open Core_kernel

(* a signature *)
module type Some_intf = sig
  type t = Quux | Zzz [@@deriving bin_io, version]
end

module M0 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving yojson, bin_io, version]
      end

      include T
    end
  end
end

module M1 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        (* refers to versioned type *)
        type t = M0.Stable.V1.t [@@deriving yojson, bin_io, version]
      end

      include T
    end
  end
end

module M3 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        (* tuple of versioned types *)
        type t = M0.Stable.V1.t * M1.Stable.V1.t
        [@@deriving yojson, bin_io, version]
      end

      include T
    end
  end
end

module M4 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        (* record of versioned types *)
        type t = {one: M0.Stable.V1.t; two: M1.Stable.V1.t}
        [@@deriving yojson, bin_io, version]
      end

      include T
    end
  end
end

module M5 (M : sig
  type t [@@deriving version {numbered}]
end) =
struct
  module Stable = struct
    module V5 = struct
      module T = struct
        type t = M.t
      end

      include T

      (* use version in functor argument *)
      let version = M.version
    end
  end
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t = int [@@deriving yojson, bin_io, version, sexp]
    end

    include T
  end
end

(* type constructors *)
module M6 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Stable.V1.t option [@@deriving yojson, bin_io, version]
      end

      include T
    end

    module V2 = struct
      module T = struct
        type t = Stable.V1.t list [@@deriving yojson, bin_io, version]
      end

      include T
    end

    module V3 = struct
      module T = struct
        type t = Stable.V1.t ref [@@deriving yojson, bin_io, version]
      end

      include T
    end

    module V4 = struct
      module T = struct
        type t = Stable.V1.t option sexp_opaque
        [@@deriving sexp, bin_io, version]
      end

      include T
    end

    module V5 = struct
      module T = struct
        type t = Stable.V1.t array array sexp_opaque
        [@@deriving sexp, bin_io, version]
      end

      include T
    end
  end
end

(* unnumbered option *)
module M7 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving yojson, bin_io, version {unnumbered}]
      end

      include T
    end
  end
end

module type Intf = sig
  type t = Int.t [@@deriving version]
end

(* recursive type *)
module M8 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Leaf | Node of t * t [@@deriving yojson, bin_io, version]
      end

      include T
    end
  end
end

(* type with parameters *)
module Poly = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('a, 'b) t = Poly of 'a * 'b
        [@@deriving bin_io, yojson, version]
      end

      include T
    end
  end
end

module M9 = struct
  module M = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = (string, int) Poly.Stable.V1.t
          [@@deriving yojson, bin_io, version]
        end

        include T
      end
    end
  end
end

(* wrapped option *)
module M10 = struct
  module Wrapped = struct
    module Stable = struct
      module V1 = struct
        type t = string [@@deriving version {wrapped}]
      end
    end
  end
end

(* assert versionedness *)
module M11 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Int.t List.t [@@deriving bin_io, version {asserted}]
      end

      include T
    end
  end
end

(* int32 *)
module M12 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int32 [@@deriving bin_io, version]
      end

      include T
    end
  end
end

(* int64 *)
module M13 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int64 [@@deriving bin_io, version]
      end

      include T
    end
  end
end

(* bytes *)
module M14 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = bytes [@@deriving bin_io, version]
      end

      include T
    end
  end
end

(* Jane Street trustlisting *)
module M15 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int Core_kernel.Queue.Stable.V1.t [@@deriving bin_io, version]
      end

      include T
    end
  end
end

(* Jane Street special case *)
module M16 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Core_kernel.Time.Stable.Span.V1.t [@@deriving bin_io, version]
      end

      include T
    end
  end
end

(* a GADT type *)
module M17 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('a, 'b) t =
          | Foo : int * string -> (int, string) t
          | Bar : string * int -> (string, int) t
        [@@deriving version]
      end
    end
  end
end

(* a GADT type with type parameters in result *)
module M18 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('instantiated, 'unbound) t =
          | Foo : int * 'unbound list -> (int, 'unbound) t
          | Bar : string * 'unbound array -> (string, 'unbound) t
        [@@deriving version]
      end
    end
  end
end
