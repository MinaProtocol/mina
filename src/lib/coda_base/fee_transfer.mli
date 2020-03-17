open Core_kernel
open Import

module Single : sig
  module Stable : sig
    module V1 : sig
      type t = Public_key.Compressed.Stable.V1.t * Currency.Fee.Stable.V1.t
      [@@deriving bin_io, sexp, compare, eq, yojson, version, hash]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, compare, yojson, hash]

  include Comparable.S with type t := t

  include Codable.Base58_check_intf with type t := t
end

module Stable : sig
  module V1 : sig
    type t = Single.Stable.V1.t One_or_two.Stable.V1.t
    [@@deriving bin_io, sexp, compare, eq, yojson, version, hash]
  end

  module Latest = V1
end

type t = Single.Stable.Latest.t One_or_two.Stable.Latest.t
[@@deriving sexp, compare, yojson, hash]

include Comparable.S with type t := t

val fee_excess : t -> Currency.Fee.Signed.t Or_error.t

val receivers : t -> Public_key.Compressed.t One_or_two.t

val receiver_ids : t -> Account_id.t One_or_two.t
