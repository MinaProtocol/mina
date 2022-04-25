[%%import "/src/config.mlh"]

open Core_kernel
open Mina_base_import

module Digest : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]

  val of_field : Snark_params.Tick.Field.t -> t

  include Stringable.S with type t := t

  include Comparable_binable with type t := t

  include Hashable_binable with type t := t

  val to_input : t -> Snark_params.Tick.Field.t Random_oracle.Input.Chunked.t

  val default : t

  val gen : t Quickcheck.Generator.t

  val gen_non_default : t Quickcheck.Generator.t

  [%%ifdef consensus_mechanism]

  module Checked : sig
    open Pickles.Impls.Step

    type t

    val to_input : t -> Field.t Random_oracle.Input.Chunked.t

    val constant : Stable.Latest.t -> t

    val equal : t -> t -> Boolean.var

    val if_ : Boolean.var -> then_:t -> else_:t -> t

    val of_field : Pickles.Impls.Step.Field.t -> t

    module Assert : sig
      val equal : t -> t -> unit
    end
  end

  val typ : (Checked.t, t) Snark_params.Tick.Typ.t

  [%%endif]
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type t [@@deriving sexp, equal, compare, hash, yojson]
  end
end]

val create : Public_key.Compressed.t -> Digest.t -> t

val derive_token_id : owner:t -> Digest.t

val empty : t

val public_key : t -> Public_key.Compressed.t

val token_id : t -> Digest.t

val to_input : t -> Snark_params.Tick.Field.t Random_oracle.Input.Chunked.t

val gen : t Quickcheck.Generator.t

include Comparable.S with type t := t

include Hashable.S_binable with type t := t

[%%ifdef consensus_mechanism]

type var

val typ : (var, t) Snark_params.Tick.Typ.t

val var_of_t : t -> var

module Checked : sig
  open Snark_params
  open Tick

  val create : Public_key.Compressed.var -> Digest.Checked.t -> var

  val public_key : var -> Public_key.Compressed.var

  val token_id : var -> Digest.Checked.t

  val to_input :
    var -> Snark_params.Tick.Field.Var.t Random_oracle.Input.Chunked.t

  val equal : var -> var -> Boolean.var Checked.t

  val if_ : Boolean.var -> then_:var -> else_:var -> var Checked.t
end

[%%endif]
