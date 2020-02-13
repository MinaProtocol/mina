open Core
open Import
module Payload = User_command_payload

module Poly : sig
  type ('payload, 'pk, 'signature) t =
    {payload: 'payload; sender: 'pk; signature: 'signature}
  [@@deriving sexp, hash, yojson, eq, compare]

  module Stable :
    sig
      module V1 : sig
        type ('payload, 'pk, 'signature) t =
          {payload: 'payload; sender: 'pk; signature: 'signature}
        [@@deriving bin_io, sexp, hash, yojson, eq, compare]
      end

      module Latest = V1
    end
    with type ('payload, 'pk, 'signature) V1.t = ('payload, 'pk, 'signature) t
end

module Stable : sig
  module V2 : sig
    type t =
      ( Payload.Stable.V2.t
      , Public_key.Stable.V1.t
      , Signature.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving bin_io, sexp, hash, yojson, version]

    val version_byte : char (* for base58_check *)

    include Comparable.S with type t := t

    include Hashable.S with type t := t

    val accounts_accessed : t -> Account_id.t list
  end

  module V1 : sig
    type t =
      ( Payload.Stable.V1.t
      , Public_key.Stable.V1.t
      , Signature.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving bin_io, sexp, hash, yojson, version]

    val to_latest : t -> V2.t

    val version_byte : char (* for base58_check *)

    include Comparable.S with type t := t

    include Hashable.S with type t := t
  end

  module Latest = V2
end

include User_command_intf.S with type t = Stable.Latest.t
