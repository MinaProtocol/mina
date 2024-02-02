open Intf

type nonrec uint64 = uint64

type nonrec uint32 = uint32

module type S = S

module Extend : F

module UInt64 : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      [@@@with_all_version_tags]

      type t = Unsigned.UInt64.t
      [@@deriving bin_io, sexp, hash, compare, equal, yojson, version]
    end
  end]

  include S with type t = Stable.Latest.t

  val dhall_type : Ppx_dhall_type.Dhall_type.t

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t
end

module UInt32 : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      [@@@with_all_version_tags]

      type t = Unsigned.UInt32.t
      [@@deriving bin_io, sexp, hash, compare, equal, yojson, version]
    end
  end]

  include S with type t = Stable.Latest.t

  val to_uint32 : t -> uint32

  val of_uint32 : uint32 -> t
end
