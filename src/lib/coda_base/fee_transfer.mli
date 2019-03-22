open Core_kernel
open Import

module Single : sig
  module Stable : sig
    module V1 : sig
      type t = Public_key.Compressed.t * Currency.Fee.t
      [@@deriving bin_io, sexp, compare, eq, yojson]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, compare, eq, yojson]
end

module Stable : sig
  module V1 : sig
    type t =
      | One of Single.Stable.V1.t
      | Two of Single.Stable.V1.t * Single.Stable.V1.t
    [@@deriving bin_io, sexp, compare, eq, yojson]
  end

  module Latest = V1
end

type t = Stable.Latest.t =
  | One of Single.Stable.V1.t
  | Two of Single.Stable.V1.t * Single.Stable.V1.t
[@@deriving sexp, compare, eq, yojson]

val to_list : t -> Single.t list

val of_single : Single.t -> t

val of_single_list : Single.t list -> t list

val fee_excess : t -> Currency.Fee.Signed.t Or_error.t

val receivers : t -> Public_key.Compressed.t list
