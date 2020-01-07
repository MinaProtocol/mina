open Core
open Coda_base
open Snark_params
open Tick

module Block_data : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = State_body_hash.Stable.V1.t option [@@deriving sexp]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp]

  type var

  val typ : (var, t) Typ.t

  module Checked : sig
    val push_state : var -> Boolean.var

    val state_body_hash : var -> State_body_hash.var
  end
end

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'a t = {transaction: 'a; block_data: Block_data.Stable.V1.t}
      [@@deriving sexp]
    end
  end]

  type 'a t = 'a Stable.Latest.t = {transaction: 'a; block_data: Block_data.t}
  [@@deriving sexp]
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type 'a t = 'a Poly.Stable.V1.t [@@deriving sexp]
  end
end]

type 'a t = 'a Stable.Latest.t [@@deriving sexp]

val transaction : 'a t -> 'a

val block_data : _ t -> Block_data.t
