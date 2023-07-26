open Core_kernel
open Mina_base_import

module Poly : sig
  type ('public_key, 'amount) t =
        ( 'public_key
        , 'amount )
        Mina_wire_types.Mina_base.Payment_payload.Poly.V2.t =
    { receiver_pk : 'public_key; amount : 'amount }
  [@@deriving equal, sexp, hash, yojson]

  module Stable : sig
    module V2 : sig
      type ('pk, 'amount) t
      [@@deriving bin_io, equal, sexp, hash, yojson, version]
    end

    module V1 : sig
      type ('pk, 'token_id, 'amount) t =
        { source_pk : 'pk
        ; receiver_pk : 'pk
        ; token_id : 'token_id
        ; amount : 'amount
        }
      [@@deriving bin_io, equal, sexp, hash, yojson, version]
    end

    module Latest = V2
  end
  with type ('pk, 'amount) V2.t = ('pk, 'amount) t
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Currency.Amount.Stable.V1.t )
      Poly.Stable.V2.t
    [@@deriving compare, equal, sexp, hash, compare, yojson]
  end

  module V1 : sig
    [@@@with_all_version_tags]

    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Token_id.Stable.V1.t
      , Currency.Amount.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving compare, equal, sexp, hash, compare, yojson]

    val to_latest : t -> Latest.t
  end
end]

val dummy : t

(** [gen ?source_pk max_amount] *)
val gen : Currency.Amount.t -> t Quickcheck.Generator.t

(** [gen_default_token ?source_pk max_amount] *)
val gen_default_token : Currency.Amount.t -> t Quickcheck.Generator.t

type var = (Public_key.Compressed.var, Currency.Amount.var) Poly.t

val var_of_t : t -> var
